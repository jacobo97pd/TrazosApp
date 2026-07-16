const { onCall, HttpsError }  = require("firebase-functions/v2/https");
const { onDocumentWritten }   = require("firebase-functions/v2/firestore");
const { onSchedule }          = require("firebase-functions/v2/scheduler");
const { defineSecret }        = require("firebase-functions/params");
const { initializeApp }       = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging }        = require("firebase-admin/messaging");
const { getAuth }             = require("firebase-admin/auth");
const turf                    = require("@turf/turf");

initializeApp();
const db   = getFirestore();
const fcm  = getMessaging();
const auth = getAuth();

// Región EU — ajustar a europe-west3 (Frankfurt) si prefieres
const REGION = "europe-west1";

const ZONE_EXPIRATION_DAYS = 7;
const MIN_POLYGON_POINTS   = 4;
const MIN_PERIMETER_M      = 500;
const MIN_AREA_M2          = 1000; // territorio mínimo válido (~un bloque)
// Anti-trampas por velocidad media (debe coincidir con AppConstants en el cliente).
const MAX_AVG_SPEED_KMH    = 20;  // por encima ≈ bici/coche
const MIN_AVG_SPEED_KMH    = 2;   // por debajo ≈ parado/deriva GPS

// Secretos de Strava — definir con:
//   firebase functions:secrets:set STRAVA_CLIENT_ID
//   firebase functions:secrets:set STRAVA_CLIENT_SECRET
const STRAVA_CLIENT_ID     = defineSecret("STRAVA_CLIENT_ID");
const STRAVA_CLIENT_SECRET = defineSecret("STRAVA_CLIENT_SECRET");

const STRAVA_TOKEN_URL = "https://www.strava.com/oauth/token";

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Convierte [{lat, lng}] a coordenadas GeoJSON [lng, lat] cerradas.
 * Lanza si el array tiene < 3 puntos únicos.
 */
function toClosedRing(points) {
  const coords = points.map((p) => [p.lng, p.lat]);
  const first  = coords[0];
  const last   = coords[coords.length - 1];
  if (first[0] !== last[0] || first[1] !== last[1]) {
    coords.push([first[0], first[1]]);
  }
  return coords;
}

/**
 * Devuelve la geometría turf (Feature<Polygon|MultiPolygon>) de una zona.
 * Soporta el formato nuevo (geometryJson GeoJSON) y el viejo (polygon [{lat,lng}]).
 * Devuelve null si no se puede parsear.
 */
function zoneFeature(zone) {
  try {
    if (typeof zone.geometryJson === "string" && zone.geometryJson.length > 0) {
      return turf.feature(JSON.parse(zone.geometryJson));
    }
    if (Array.isArray(zone.polygon) && zone.polygon.length >= 3) {
      return turf.polygon([toClosedRing(zone.polygon)]);
    }
  } catch {
    /* geometría corrupta */
  }
  return null;
}

/** ¿Se solapan dos bboxes [minX,minY,maxX,maxY]? (rechazo rápido). */
function bboxOverlap(a, b) {
  return a[0] <= b[2] && a[2] >= b[0] && a[1] <= b[3] && a[3] >= b[1];
}

/** Envía FCM sin lanzar si falla (token inválido, app desinstalada…). */
async function sendFcm(token, title, body, data = {}) {
  if (!token) return;
  try {
    await fcm.send({
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
    });
  } catch (err) {
    console.warn(`FCM send failed (token …${token.slice(-6)}):`, err.code ?? err.message);
  }
}

// ── 1. validateCapture (callable) — "reclamar territorio" ────────────────────
//
// Modelo "territorio libre" (estilo paper.io): cierras un cerco donde quieras y
// ese polígono pasa a ser TU territorio. Si pisa territorio de otros, se lo
// recortas (turf.difference). Puntúas por área total controlada (totalAreaM2).
// (Se mantiene el nombre validateCapture para reutilizar el servicio Cloud Run
//  que ya tiene el permiso de invocación.)
//
// Recibe: { polygonCoords: [{lat,lng}], distanceMeters, durationSeconds }
// Retorna: { success: bool, areaM2?: number, reason?: string }
//
// Validaciones en servidor: auth, >=4 puntos, polígono válido, distancia
// >=500 m, velocidad de correr [2,20] km/h y área mínima.

exports.validateCapture = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes estar autenticado.");
  }
  const uid = request.auth.uid;
  const { polygonCoords, distanceMeters, durationSeconds } = request.data ?? {};

  if (!Array.isArray(polygonCoords) ||
      polygonCoords.length < MIN_POLYGON_POINTS) {
    return { success: false, reason: "min_points" };
  }

  let claim;
  try {
    claim = turf.polygon([toClosedRing(polygonCoords)]);
  } catch {
    return { success: false, reason: "invalid_polygon" };
  }

  // Distancia mínima: usa la real de la carrera si llega; si no, el perímetro.
  const perimeterM = turf.length(
    turf.lineString(claim.geometry.coordinates[0]), { units: "kilometers" }
  ) * 1000;
  const runDist = Number.isFinite(Number(distanceMeters))
    ? Number(distanceMeters) : perimeterM;
  if (runDist < MIN_PERIMETER_M) {
    return { success: false, reason: "insufficient_distance" };
  }

  // Anti-trampas por velocidad media.
  const durS = Number(durationSeconds);
  if (Number.isFinite(runDist) && Number.isFinite(durS) && durS > 0) {
    const avgKmh = (runDist / 1000) / (durS / 3600);
    if (avgKmh > MAX_AVG_SPEED_KMH || avgKmh < MIN_AVG_SPEED_KMH) {
      return { success: false, reason: "invalid_speed" };
    }
  }

  const claimArea = turf.area(claim);
  if (claimArea < MIN_AREA_M2) {
    return { success: false, reason: "area_too_small" };
  }

  const claimBbox = turf.bbox(claim);

  // Con pocos usuarios basta traer todas las zonas y filtrar por bbox.
  const [zonesSnap, userSnap] = await Promise.all([
    db.collection("zones").get(),
    db.collection("users").doc(uid).get(),
  ]);
  const user = userSnap.data() ?? {};
  const isClub = Boolean(user.clubId);
  const ownerName = user.displayName ?? uid;

  const batch = db.batch();
  const areaDelta = {};       // ownerId -> variación de m² (para totalAreaM2)
  const victims = new Set();  // ownerIds a los que se recorta (para FCM)

  for (const doc of zonesSnap.docs) {
    const z = doc.data();
    const zGeom = zoneFeature(z);
    if (!zGeom) continue;
    if (!bboxOverlap(claimBbox, turf.bbox(zGeom))) continue;

    let intersects = false;
    try { intersects = turf.booleanIntersects(zGeom, claim); } catch { /* */ }
    if (!intersects) continue;

    const beforeArea = Number.isFinite(z.areaM2) ? z.areaM2 : turf.area(zGeom);

    let diff;
    try {
      diff = turf.difference(turf.featureCollection([zGeom, claim]));
    } catch {
      continue; // si el recorte falla, no tocamos esa zona
    }

    if (!diff) {
      // Territorio totalmente cubierto → se elimina.
      batch.delete(doc.ref);
      areaDelta[z.ownerId] = (areaDelta[z.ownerId] || 0) - beforeArea;
      if (z.ownerId && z.ownerId !== uid) victims.add(z.ownerId);
    } else {
      const afterArea = turf.area(diff);
      if (afterArea >= beforeArea - 1) continue; // sin cambio apreciable
      batch.update(doc.ref, {
        geometryJson: JSON.stringify(diff.geometry),
        areaM2: afterArea,
      });
      areaDelta[z.ownerId] =
        (areaDelta[z.ownerId] || 0) - (beforeArea - afterArea);
      if (z.ownerId && z.ownerId !== uid) victims.add(z.ownerId);
    }
  }

  // Crear el territorio nuevo del usuario.
  const newRef = db.collection("zones").doc();
  const expiresAt = Timestamp.fromDate(
    new Date(Date.now() + ZONE_EXPIRATION_DAYS * 24 * 60 * 60 * 1000)
  );
  batch.set(newRef, {
    ownerId:      uid,
    ownerName,
    ownerPhotoUrl: user.photoUrl ?? null,
    ownerType:    isClub ? "club" : "solo",
    color:        "#FF4D6D",
    geometryJson: JSON.stringify(claim.geometry),
    areaM2:       claimArea,
    city:         user.city ?? "",
    capturedAt:   Timestamp.now(),
    expiresAt,
  });
  areaDelta[uid] = (areaDelta[uid] || 0) + claimArea;

  // Actualizar el área total de cada afectado (ranking por km²).
  for (const [ownerId, delta] of Object.entries(areaDelta)) {
    if (!ownerId) continue;
    batch.set(
      db.collection("users").doc(ownerId),
      { totalAreaM2: FieldValue.increment(delta),
        lastActive: FieldValue.serverTimestamp() },
      { merge: true }
    );
  }

  await batch.commit();

  // FCM a los que han perdido territorio (fuera del batch).
  for (const ownerId of victims) {
    const vDoc = await db.collection("users").doc(ownerId).get();
    await sendFcm(
      vDoc.data()?.fcmToken,
      "¡Te han robado territorio!",
      `${ownerName} ha conquistado parte de tu terreno. ¡Recupéralo!`,
      { type: "territory_taken" }
    );
  }

  return { success: true, areaM2: Math.round(claimArea) };
});

// ── 2. checkExpiredZones (scheduled, 03:00 UTC cada noche) ───────────────────
//
// Libera zonas cuyo expiresAt < now() y notifica a cada ex-dueño.
// Procesa en batches de 400 para no superar el límite de 500 ops/batch.

exports.checkExpiredZones = onSchedule(
  { schedule: "every day 03:00", region: REGION },
  async () => {
    const now  = Timestamp.now();
    const snap = await db
      .collection("zones")
      .where("expiresAt", "<=", now)
      .get();

    if (snap.empty) {
      console.log("checkExpiredZones: no hay zonas expiradas.");
      return;
    }

    // Área a restar por dueño y a quién avisar.
    const areaByOwner = {};
    const fcmTasks = [];

    // Borrar zonas caducadas en batches (límite Firestore: 500 ops/batch).
    const BATCH_SIZE = 400;
    for (let i = 0; i < snap.docs.length; i += BATCH_SIZE) {
      const batch = db.batch();
      snap.docs.slice(i, i + BATCH_SIZE).forEach((doc) => {
        const zone = doc.data();
        batch.delete(doc.ref);
        if (zone.ownerId) {
          areaByOwner[zone.ownerId] =
            (areaByOwner[zone.ownerId] || 0) + (Number(zone.areaM2) || 0);
        }
      });
      await batch.commit();
    }

    // Restar el área caducada del total de cada dueño y avisarle.
    const ownerBatch = db.batch();
    for (const [ownerId, area] of Object.entries(areaByOwner)) {
      ownerBatch.set(
        db.collection("users").doc(ownerId),
        { totalAreaM2: FieldValue.increment(-area) },
        { merge: true }
      );
      fcmTasks.push((async () => {
        const ownerDoc = await db.collection("users").doc(ownerId).get();
        return sendFcm(
          ownerDoc.data()?.fcmToken,
          "Territorio expirado",
          "Parte de tu territorio ha caducado. ¡Vuelve a correr para recuperarlo!",
          { type: "zone_expired" }
        );
      })());
    }
    await ownerBatch.commit();
    await Promise.allSettled(fcmTasks);

    console.log(`checkExpiredZones: ${snap.size} zona(s) caducada(s) borrada(s).`);
  }
);

// ── 3. onClubMemberJoin (onWrite en clubs/{clubId}) ──────────────────────────
//
// Recalcula totalZones y totalKm del club sumando los de todos los miembros.
// Solo actúa cuando el array members[] cambia para evitar bucle infinito
// (la propia actualización de totalZones/totalKm disparará este trigger,
//  pero la comparación de members lo cortocircuitará).

async function recalcClubStats(clubId) {
  if (!clubId) return;

  const clubRef = db.collection("clubs").doc(clubId);
  const clubSnap = await clubRef.get();
  if (!clubSnap.exists) return;

  const members = clubSnap.data()?.members ?? [];
  if (members.length === 0) {
    await clubRef.update({ totalZones: 0, totalKm: 0 });
    return;
  }

  const userRefs = members.map((uid) => db.collection("users").doc(uid));
  const userDocs = await db.getAll(...userRefs);

  const totalZones = userDocs.reduce(
    (sum, d) => sum + (d.data()?.capturedZones?.length ?? 0), 0
  );
  const totalKm = userDocs.reduce(
    (sum, d) => sum + (d.data()?.totalKm ?? 0), 0
  );

  await clubRef.update({ totalZones, totalKm });
}

exports.onUserStatsWritten = onDocumentWritten(
  { document: "users/{uid}", region: REGION },
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();

    const beforeZones = [...(before?.capturedZones ?? [])].sort().join(",");
    const afterZones  = [...(after?.capturedZones  ?? [])].sort().join(",");
    const beforeKm    = before?.totalKm ?? 0;
    const afterKm     = after?.totalKm ?? 0;
    const beforeClub  = before?.clubId ?? null;
    const afterClub   = after?.clubId ?? null;

    if (
      beforeZones === afterZones &&
      beforeKm === afterKm &&
      beforeClub === afterClub
    ) {
      return;
    }

    const affectedClubs = new Set(
      [beforeClub, afterClub].filter((clubId) => Boolean(clubId))
    );
    await Promise.all([...affectedClubs].map(recalcClubStats));
  }
);

exports.onClubMemberJoin = onDocumentWritten(
  { document: "clubs/{clubId}", region: REGION },
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();
    if (!after) return; // doc eliminado

    // Comparar arrays de miembros (orden independiente)
    const beforeKey = [...(before?.members ?? [])].sort().join(",");
    const afterKey  = [...(after.members  ?? [])].sort().join(",");
    if (beforeKey === afterKey) return; // members no cambió → salir

    const members = after.members ?? [];
    if (members.length === 0) return;

    // Leer todos los documentos de usuarios en una sola llamada
    const userRefs  = members.map((uid) => db.collection("users").doc(uid));
    const userDocs  = await db.getAll(...userRefs);

    const totalZones = userDocs.reduce(
      (sum, d) => sum + (d.data()?.capturedZones?.length ?? 0), 0
    );
    const totalKm = userDocs.reduce(
      (sum, d) => sum + (d.data()?.totalKm ?? 0), 0
    );

    await event.data.after.ref.update({ totalZones, totalKm });

    // Notificar a los miembros nuevos (los que no estaban en before)
    const prevMembers = new Set(before?.members ?? []);
    const newMembers  = members.filter((uid) => !prevMembers.has(uid));

    await Promise.allSettled(
      newMembers.map(async (uid) => {
        const userDoc = userDocs.find((d) => d.id === uid);
        const token   = userDoc?.data()?.fcmToken;
        await sendFcm(
          token,
          `Bienvenido a ${after.name}`,
          "Ya eres parte del club. ¡A correr y capturar zonas juntos!",
          { type: "club_joined", clubId: event.params.clubId }
        );
      })
    );

    console.log(
      `onClubMemberJoin [${event.params.clubId}]: ` +
      `totalZones=${totalZones}, totalKm=${totalKm.toFixed(1)}, ` +
      `newMembers=${newMembers.length}`
    );
  }
);

// ── 4. remindExpiring (recordatorio 24 h antes, 10:00 UTC) ───────────────────
//
// Avisa al dueño de zonas que expiran en las próximas 24 h pero aún no han
// expirado (expiresAt > now para no solaparse con checkExpiredZones).

exports.remindExpiring = onSchedule(
  { schedule: "every day 10:00", region: REGION },
  async () => {
    const now   = Timestamp.now();
    const in24h = Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000));

    const snap = await db
      .collection("zones")
      .where("expiresAt", ">",  now)
      .where("expiresAt", "<=", in24h)
      .get();

    // Avisa una sola vez por dueño (aunque tenga varias zonas por expirar).
    const owners = new Set();
    for (const doc of snap.docs) {
      const ownerId = doc.data().ownerId;
      if (ownerId) owners.add(ownerId);
    }

    await Promise.allSettled(
      [...owners].map(async (ownerId) => {
        const userDoc = await db.collection("users").doc(ownerId).get();
        await sendFcm(
          userDoc.data()?.fcmToken,
          "Defiende tu territorio",
          "Parte de tu territorio expira en menos de 24 h. ¡Sal a correr!",
          { type: "zone_expiring" }
        );
      })
    );

    console.log(`remindExpiring: ${snap.size} recordatorio(s) enviado(s).`);
  }
);

// ── 5. exchangeStravaToken (callable) ────────────────────────────────────────
//
// Recibe: { code: string }  (el code del callback OAuth de Strava)
// Retorna: { accessToken, refreshToken, expiresAt, athleteId, athleteName }
//
// El client_secret NUNCA viaja al cliente: el intercambio code→token se hace
// aquí, en el servidor, con los secretos de Strava.

exports.exchangeStravaToken = onCall(
  { region: REGION, secrets: [STRAVA_CLIENT_ID, STRAVA_CLIENT_SECRET] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado.");
    }

    const code = request.data?.code;
    if (typeof code !== "string" || code.length === 0) {
      throw new HttpsError("invalid-argument", "Falta el parámetro 'code'.");
    }

    let res;
    try {
      res = await fetch(STRAVA_TOKEN_URL, {
        method:  "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          client_id:     STRAVA_CLIENT_ID.value(),
          client_secret: STRAVA_CLIENT_SECRET.value(),
          code,
          grant_type:    "authorization_code",
        }),
      });
    } catch (err) {
      throw new HttpsError("unavailable", "No se pudo contactar con Strava.", err.message);
    }

    if (!res.ok) {
      const detail = await res.text();
      console.warn("exchangeStravaToken: Strava respondió", res.status, detail);
      throw new HttpsError("permission-denied", "Strava rechazó el code.");
    }

    const data    = await res.json();
    const athlete = data.athlete ?? {};

    return {
      accessToken:  data.access_token,
      refreshToken: data.refresh_token,
      expiresAt:    data.expires_at, // Unix timestamp en segundos
      athleteId:    String(athlete.id ?? ""),
      athleteName:  [athlete.firstname, athlete.lastname].filter(Boolean).join(" "),
    };
  }
);

// ── 6. refreshStravaToken (callable) ─────────────────────────────────────────
//
// Recibe: { refreshToken: string }
// Retorna: { accessToken, refreshToken, expiresAt }
//
// Strava puede rotar el refresh_token, así que se devuelve también.

exports.refreshStravaToken = onCall(
  { region: REGION, secrets: [STRAVA_CLIENT_ID, STRAVA_CLIENT_SECRET] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado.");
    }

    const refreshToken = request.data?.refreshToken;
    if (typeof refreshToken !== "string" || refreshToken.length === 0) {
      throw new HttpsError("invalid-argument", "Falta el parámetro 'refreshToken'.");
    }

    let res;
    try {
      res = await fetch(STRAVA_TOKEN_URL, {
        method:  "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          client_id:     STRAVA_CLIENT_ID.value(),
          client_secret: STRAVA_CLIENT_SECRET.value(),
          grant_type:    "refresh_token",
          refresh_token: refreshToken,
        }),
      });
    } catch (err) {
      throw new HttpsError("unavailable", "No se pudo contactar con Strava.", err.message);
    }

    if (!res.ok) {
      const detail = await res.text();
      console.warn("refreshStravaToken: Strava respondió", res.status, detail);
      throw new HttpsError("permission-denied", "refresh_token inválido o caducado.");
    }

    const data = await res.json();
    return {
      accessToken:  data.access_token,
      refreshToken: data.refresh_token,
      expiresAt:    data.expires_at,
    };
  }
);

// ── 7. loginWithStrava (callable) — "Iniciar sesión con Strava" ───────────────
//
// Recibe: { code: string }  (el code del OAuth de Strava, móvil o web)
// Retorna: { firebaseToken, accessToken, refreshToken, expiresAt, athleteId, athleteName }
//
// Flujo: intercambia el code por tokens + datos del atleta, crea/actualiza el
// usuario users/{strava:<id>}, y emite un custom token de Firebase para que el
// cliente haga signInWithCustomToken. NO requiere auth previa (es el login).

exports.loginWithStrava = onCall(
  {
    region: REGION,
    secrets: [STRAVA_CLIENT_ID, STRAVA_CLIENT_SECRET],
    // createCustomToken() necesita firmar un JWT (iam.serviceAccounts.signBlob).
    // La SA por defecto de Gen2 (…-compute@) no puede; la firebase-adminsdk sí.
    serviceAccount: "firebase-adminsdk-fbsvc@trazos-database.iam.gserviceaccount.com",
  },
  async (request) => {
    const code = request.data?.code;
    if (typeof code !== "string" || code.length === 0) {
      throw new HttpsError("invalid-argument", "Falta el parámetro 'code'.");
    }

    let res;
    try {
      res = await fetch(STRAVA_TOKEN_URL, {
        method:  "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          client_id:     STRAVA_CLIENT_ID.value(),
          client_secret: STRAVA_CLIENT_SECRET.value(),
          code,
          grant_type:    "authorization_code",
        }),
      });
    } catch (err) {
      throw new HttpsError("unavailable", "No se pudo contactar con Strava.", err.message);
    }

    if (!res.ok) {
      const detail = await res.text();
      console.warn("loginWithStrava: Strava respondió", res.status, detail);
      throw new HttpsError("permission-denied", "Strava rechazó el code.");
    }

    const data    = await res.json();
    const athlete = data.athlete ?? {};
    const athleteId = String(athlete.id ?? "");
    if (!athleteId) {
      throw new HttpsError("internal", "Strava no devolvió el atleta.");
    }

    const uid = `strava:${athleteId}`;
    const displayName =
      [athlete.firstname, athlete.lastname].filter(Boolean).join(" ") ||
      `Atleta ${athleteId}`;

    // Crear o actualizar el documento de usuario
    const userRef = db.collection("users").doc(uid);
    const snap    = await userRef.get();
    if (!snap.exists) {
      await userRef.set({
        displayName,
        email:           "",
        photoUrl:        athlete.profile ?? null,
        stravaId:        athleteId,
        stravaConnected: true,
        level:           1,
        totalKm:         0,
        capturedZones:   [],
        lastActive:      FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.update({
        stravaId:        athleteId,
        stravaConnected: true,
        lastActive:      FieldValue.serverTimestamp(),
      });
    }

    // Custom token de Firebase con el uid del atleta de Strava
    const firebaseToken = await auth.createCustomToken(uid, { provider: "strava" });

    return {
      firebaseToken,
      accessToken:  data.access_token,
      refreshToken: data.refresh_token,
      expiresAt:    data.expires_at,
      athleteId,
      athleteName:  displayName,
    };
  }
);
