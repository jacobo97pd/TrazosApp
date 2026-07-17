const { onCall, HttpsError }  = require("firebase-functions/v2/https");
const { onDocumentWritten }   = require("firebase-functions/v2/firestore");
const { onSchedule }          = require("firebase-functions/v2/scheduler");
const { defineSecret }        = require("firebase-functions/params");
const { initializeApp }       = require("firebase-admin/app");
const {
  getFirestore,
  FieldPath,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
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

// Feed e interacciones de conquistas.
const FEED_DEFAULT_LIMIT = 20;
const FEED_MAX_LIMIT = 30;
const FEED_SCAN_LIMIT = 300;
const FEED_SCAN_BATCH = 75;
const REPORT_REVIEW_THRESHOLD = 3;
const REPORT_HIDE_THRESHOLD = 5;
const REACTION_KINDS = new Set(["like", "applause"]);
const REPORT_REASONS = new Set([
  "spam",
  "harassment",
  "hate_speech",
  "violence",
  "sexual_content",
  "dangerous_activity",
  "privacy",
  "misinformation",
  "other",
]);
const MODERATION_STATUSES = new Set([
  "ok",
  "under_review",
  "hidden",
  "removed",
]);

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

// ---------------------------------------------------------------------------
// Conquest feed, interactions, blocking and moderation
// ---------------------------------------------------------------------------

function requireCallableAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes estar autenticado.");
  }
  return request.auth.uid;
}

function requireId(value, fieldName) {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length > 160 ||
    value.includes("/")
  ) {
    throw new HttpsError(
      "invalid-argument",
      `El campo '${fieldName}' no es valido.`
    );
  }
  return value;
}

function requireCommentId(value) {
  const id = requireId(value, "commentId");
  if (!/^[A-Za-z0-9_-]{8,160}$/.test(id)) {
    throw new HttpsError("invalid-argument", "commentId no es valido.");
  }
  return id;
}

function requireTrimmedText(value, fieldName, maxLength) {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      `El campo '${fieldName}' debe ser texto.`
    );
  }
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `El campo '${fieldName}' debe tener entre 1 y ${maxLength} caracteres.`
    );
  }
  return normalized;
}

function optionalTrimmedText(value, fieldName, maxLength) {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      `El campo '${fieldName}' debe ser texto.`
    );
  }
  const normalized = value.trim();
  if (normalized.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `El campo '${fieldName}' no puede superar ${maxLength} caracteres.`
    );
  }
  return normalized.length === 0 ? null : normalized;
}

function connectionIdFor(a, b) {
  return a <= b ? `${a}_${b}` : `${b}_${a}`;
}

function sortedParticipants(a, b) {
  return a <= b ? [a, b] : [b, a];
}

function timestampMillis(value) {
  return value instanceof Timestamp ? value.toMillis() : null;
}

function numericCount(value) {
  const count = Number(value);
  return Number.isFinite(count) && count > 0 ? Math.floor(count) : 0;
}

function isExpiredPost(post, nowMs = Date.now()) {
  const expiresAtMs = timestampMillis(post.expiresAt);
  return expiresAtMs != null && expiresAtMs <= nowMs;
}

function relationshipBlocks(connection) {
  return connection?.status === "blocked";
}

function blockingUsers(connection) {
  const participants = Array.isArray(connection?.participants)
    ? connection.participants.filter((value) => typeof value === "string")
    : [];
  const blockers = Array.isArray(connection?.blockedByUsers)
    ? connection.blockedByUsers.filter(
        (value) => typeof value === "string" && participants.includes(value)
      )
    : [];
  if (
    blockers.length === 0 &&
    typeof connection?.blockedBy === "string" &&
    participants.includes(connection.blockedBy)
  ) {
    blockers.push(connection.blockedBy);
  }
  return [...new Set(blockers)].sort();
}

function canAccessPost(uid, post, connection, options = {}) {
  const isOwner = post.userId === uid;
  if (isOwner && options.allowOwner !== false) return true;
  if (relationshipBlocks(connection)) return false;
  if (post.isDeleted === true || post.isArchived === true) return false;
  if (isExpiredPost(post)) return false;

  const allowedModeration = options.allowUnderReview
    ? new Set(["ok", "under_review"])
    : new Set(["ok"]);
  if (!allowedModeration.has(post.moderationStatus ?? "ok")) return false;

  if (post.visibility === "public") return true;
  return post.visibility === "connections" && connection?.status === "accepted";
}

async function getConnectionBetween(a, b, transaction = null) {
  if (a === b) return null;
  const ref = db.collection("connections").doc(connectionIdFor(a, b));
  const snap = transaction ? await transaction.get(ref) : await ref.get();
  return snap.exists ? snap.data() : null;
}

function safePostPayload(document) {
  const post = document.data();
  const privacy = typeof post.locationPrivacyMode === "string"
    ? post.locationPrivacyMode
    : "city";
  const showZone = privacy === "fullZone" || privacy === "neighborhood";

  return {
    id: document.id,
    userId: typeof post.userId === "string" ? post.userId : "",
    type: typeof post.type === "string" ? post.type : "text",
    visibility: typeof post.visibility === "string"
      ? post.visibility
      : "onlyMe",
    createdAtMs: timestampMillis(post.createdAt),
    updatedAtMs: timestampMillis(post.updatedAt),
    zoneId: showZone && typeof post.zoneId === "string" ? post.zoneId : null,
    activityId: typeof post.activityId === "string" ? post.activityId : null,
    challengeId: typeof post.challengeId === "string" ? post.challengeId : null,
    achievementId: typeof post.achievementId === "string"
      ? post.achievementId
      : null,
    caption: typeof post.caption === "string" ? post.caption : "",
    mediaUrl: typeof post.mediaUrl === "string" ? post.mediaUrl : null,
    thumbnailUrl: typeof post.thumbnailUrl === "string"
      ? post.thumbnailUrl
      : null,
    expiresAtMs: timestampMillis(post.expiresAt),
    isArchived: post.isArchived === true,
    isDeleted: post.isDeleted === true,
    locationPrivacyMode: privacy,
    zoneNameSnapshot: showZone && typeof post.zoneNameSnapshot === "string"
      ? post.zoneNameSnapshot
      : "",
    distanceSnapshot: Number(post.distanceSnapshot) || 0,
    durationSnapshot: Number(post.durationSnapshot) || 0,
    paceSnapshot: Number(post.paceSnapshot) || 0,
    elevationSnapshot: Number(post.elevationSnapshot) || 0,
    likesCount: numericCount(post.likesCount),
    applauseCount: numericCount(post.applauseCount),
    commentsCount: numericCount(post.commentsCount),
    moderationStatus: typeof post.moderationStatus === "string"
      ? post.moderationStatus
      : "ok",
  };
}

function conquestItemDto(postDocument, authorDocument, reactionDocument) {
  const author = authorDocument?.exists ? authorDocument.data() : {};
  const reaction = reactionDocument?.exists
    ? reactionDocument.data()?.kind
    : null;
  const authorId = postDocument.data().userId;

  return {
    post: safePostPayload(postDocument),
    author: {
      userId: authorId,
      displayName: typeof author?.displayName === "string"
        ? author.displayName
        : "Corredor",
      photoUrl: typeof author?.photoUrl === "string" ? author.photoUrl : null,
    },
    myReaction: REACTION_KINDS.has(reaction) ? reaction : null,
  };
}

async function hydrateConquestItems(postDocuments, uid) {
  if (postDocuments.length === 0) return [];

  const authorIds = [...new Set(postDocuments.map((doc) => doc.data().userId))];
  const authorRefs = authorIds.map((id) => db.collection("users").doc(id));
  const reactionRefs = postDocuments.map((doc) =>
    doc.ref.collection("reactions").doc(uid)
  );

  const [authorDocuments, reactionDocuments] = await Promise.all([
    db.getAll(...authorRefs),
    db.getAll(...reactionRefs),
  ]);
  const authorsById = new Map(authorDocuments.map((doc) => [doc.id, doc]));

  return postDocuments.map((postDocument, index) =>
    conquestItemDto(
      postDocument,
      authorsById.get(postDocument.data().userId),
      reactionDocuments[index]
    )
  );
}

function parseFeedLimit(value) {
  if (value == null) return FEED_DEFAULT_LIMIT;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw new HttpsError("invalid-argument", "limit no es valido.");
  }
  return Math.min(parsed, FEED_MAX_LIMIT);
}

function parseFeedCursor(value) {
  if (value == null) return null;
  if (typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "cursor no es valido.");
  }
  const id = requireId(value.id, "cursor.id");
  const hasExactTimestamp = value.createdAtSeconds != null ||
    value.createdAtNanoseconds != null;
  if (hasExactTimestamp) {
    const seconds = Number(value.createdAtSeconds);
    const nanoseconds = Number(value.createdAtNanoseconds);
    if (
      !Number.isSafeInteger(seconds) ||
      seconds < 0 ||
      !Number.isInteger(nanoseconds) ||
      nanoseconds < 0 ||
      nanoseconds >= 1000000000
    ) {
      throw new HttpsError(
        "invalid-argument",
        "El timestamp exacto del cursor no es valido."
      );
    }
    return { createdAt: new Timestamp(seconds, nanoseconds), id };
  }

  // Compatibilidad con clientes anteriores. Los clientes nuevos deben usar
  // seconds+nanos para no perder precision entre paginas.
  const createdAtMs = Number(value.createdAtMs);
  if (!Number.isFinite(createdAtMs) || createdAtMs < 0) {
    throw new HttpsError("invalid-argument", "cursor.createdAtMs no es valido.");
  }
  return { createdAt: Timestamp.fromMillis(createdAtMs), id };
}

async function loadConquestAudience(uid) {
  const connectionSnapshot = await db
    .collection("connections")
    .where("participants", "array-contains", uid)
    .get();
  const accepted = new Set();
  const blocked = new Set();
  for (const document of connectionSnapshot.docs) {
    const connection = document.data();
    const participants = Array.isArray(connection.participants)
      ? connection.participants
      : [];
    const other = participants.find((participant) => participant !== uid);
    if (typeof other !== "string") continue;
    if (connection.status === "accepted") accepted.add(other);
    if (connection.status === "blocked") blocked.add(other);
  }
  return { accepted, blocked };
}

exports.getConquestFeed = onCall({ region: REGION }, async (request) => {
  const uid = requireCallableAuth(request);
  const limit = parseFeedLimit(request.data?.limit);
  const flatCursor = request.data?.cursorCreatedAtSeconds != null ||
      request.data?.cursorCreatedAtNanoseconds != null ||
      request.data?.cursorCreatedAtMs != null ||
      request.data?.cursorId != null
    ? {
        createdAtSeconds: request.data?.cursorCreatedAtSeconds,
        createdAtNanoseconds: request.data?.cursorCreatedAtNanoseconds,
        createdAtMs: request.data?.cursorCreatedAtMs,
        id: request.data?.cursorId,
      }
    : null;
  let cursor = parseFeedCursor(request.data?.cursor ?? flatCursor);

  const { accepted, blocked } = await loadConquestAudience(uid);

  const baseQuery = db
    .collection("conquest_posts")
    .where("visibility", "in", ["public", "connections"])
    .where("isDeleted", "==", false)
    .where("isArchived", "==", false)
    .where("moderationStatus", "==", "ok")
    .where("expiresAt", "==", null)
    .orderBy("createdAt", "desc")
    .orderBy(FieldPath.documentId(), "desc");

  const selected = [];
  let scanned = 0;
  let lastProcessed = null;
  let reachedEnd = false;
  let stoppedForLimit = false;

  while (selected.length < limit && scanned < FEED_SCAN_LIMIT) {
    let query = baseQuery.limit(FEED_SCAN_BATCH);
    if (cursor) query = query.startAfter(cursor.createdAt, cursor.id);
    const snapshot = await query.get();
    if (snapshot.empty) {
      reachedEnd = true;
      break;
    }

    let processedInBatch = 0;
    for (const document of snapshot.docs) {
      processedInBatch += 1;
      scanned += 1;
      lastProcessed = document;
      const post = document.data();
      const authorId = post.userId;
      const visible = authorId === uid || (
        !blocked.has(authorId) &&
        (post.visibility === "public" || accepted.has(authorId))
      );
      if (visible) selected.push(document);
      if (selected.length === limit || scanned === FEED_SCAN_LIMIT) break;
    }

    if (selected.length === limit) {
      stoppedForLimit = true;
      break;
    }
    if (scanned === FEED_SCAN_LIMIT) break;
    if (snapshot.size < FEED_SCAN_BATCH) {
      reachedEnd = true;
      break;
    }

    const batchCursor = snapshot.docs[processedInBatch - 1];
    cursor = {
      createdAt: batchCursor.data().createdAt,
      id: batchCursor.id,
    };
  }

  const items = await hydrateConquestItems(selected, uid);
  const hasMore = stoppedForLimit || !reachedEnd;
  const cursorTimestamp = lastProcessed?.data().createdAt;
  const nextCursor = hasMore && lastProcessed && cursorTimestamp instanceof Timestamp
    ? {
        createdAtSeconds: cursorTimestamp.seconds,
        createdAtNanoseconds: cursorTimestamp.nanoseconds,
        createdAtMs: cursorTimestamp.toMillis(),
        id: lastProcessed.id,
      }
    : null;

  return { items, nextCursor, hasMore: nextCursor != null };
});

exports.getConquestStories = onCall({ region: REGION }, async (request) => {
  const uid = requireCallableAuth(request);
  const limit = parseFeedLimit(request.data?.limit);
  const { accepted, blocked } = await loadConquestAudience(uid);
  const now = Timestamp.now();

  const snapshot = await db
    .collection("conquest_posts")
    .where("visibility", "in", ["public", "connections"])
    .where("isDeleted", "==", false)
    .where("isArchived", "==", false)
    .where("moderationStatus", "==", "ok")
    .where("expiresAt", ">", now)
    .orderBy("expiresAt", "asc")
    .limit(FEED_SCAN_LIMIT)
    .get();

  const selected = snapshot.docs
    .filter((document) => {
      const post = document.data();
      const authorId = post.userId;
      return !isExpiredPost(post, now.toMillis()) &&
        (authorId === uid || (
          !blocked.has(authorId) &&
          (post.visibility === "public" || accepted.has(authorId))
        ));
    })
    .sort((first, second) => {
      const firstCreatedAt = first.data().createdAt;
      const secondCreatedAt = second.data().createdAt;
      if (firstCreatedAt instanceof Timestamp &&
          secondCreatedAt instanceof Timestamp) {
        const bySeconds = secondCreatedAt.seconds - firstCreatedAt.seconds;
        if (bySeconds !== 0) return bySeconds;
        const byNanoseconds = secondCreatedAt.nanoseconds -
          firstCreatedAt.nanoseconds;
        if (byNanoseconds !== 0) return byNanoseconds;
      }
      return second.id.localeCompare(first.id);
    })
    .slice(0, limit);

  return { items: await hydrateConquestItems(selected, uid) };
});

exports.getConquestDetail = onCall({ region: REGION }, async (request) => {
  const uid = requireCallableAuth(request);
  const postId = requireId(request.data?.postId, "postId");
  const postDocument = await db.collection("conquest_posts").doc(postId).get();
  if (!postDocument.exists) {
    throw new HttpsError("not-found", "La conquista no existe.");
  }

  const post = postDocument.data();
  const connection = await getConnectionBetween(uid, post.userId);
  if (!canAccessPost(uid, post, connection)) {
    throw new HttpsError("permission-denied", "No puedes ver esta conquista.");
  }

  const [authorDocument, reactionDocument] = await Promise.all([
    db.collection("users").doc(post.userId).get(),
    postDocument.ref.collection("reactions").doc(uid).get(),
  ]);
  return {
    item: conquestItemDto(postDocument, authorDocument, reactionDocument),
  };
});

exports.setConquestReaction = onCall({ region: REGION }, async (request) => {
  const uid = requireCallableAuth(request);
  const postId = requireId(request.data?.postId, "postId");
  if (!Object.prototype.hasOwnProperty.call(request.data ?? {}, "kind")) {
    throw new HttpsError("invalid-argument", "Falta el campo 'kind'.");
  }
  const desiredKind = request.data.kind;
  if (desiredKind !== null && !REACTION_KINDS.has(desiredKind)) {
    throw new HttpsError("invalid-argument", "Reaccion no valida.");
  }

  const postRef = db.collection("conquest_posts").doc(postId);
  const reactionRef = postRef.collection("reactions").doc(uid);
  return db.runTransaction(async (transaction) => {
    const postDocument = await transaction.get(postRef);
    if (!postDocument.exists) {
      throw new HttpsError("not-found", "La conquista no existe.");
    }
    const post = postDocument.data();
    if (post.userId === uid) {
      throw new HttpsError(
        "failed-precondition",
        "No puedes reaccionar a tu propia conquista."
      );
    }
    const connection = await getConnectionBetween(uid, post.userId, transaction);
    if (!canAccessPost(uid, post, connection)) {
      throw new HttpsError(
        "permission-denied",
        "No puedes reaccionar a esta conquista."
      );
    }

    const reactionDocument = await transaction.get(reactionRef);
    const currentKind = reactionDocument.exists
      ? reactionDocument.data().kind
      : null;
    let likesCount = numericCount(post.likesCount);
    let applauseCount = numericCount(post.applauseCount);

    if (currentKind === desiredKind) {
      return {
        changed: false,
        reaction: desiredKind,
        likesCount,
        applauseCount,
      };
    }

    if (currentKind === "like") likesCount = Math.max(0, likesCount - 1);
    if (currentKind === "applause") {
      applauseCount = Math.max(0, applauseCount - 1);
    }
    if (desiredKind === "like") likesCount += 1;
    if (desiredKind === "applause") applauseCount += 1;

    if (desiredKind === null) {
      if (reactionDocument.exists) transaction.delete(reactionRef);
    } else if (reactionDocument.exists) {
      transaction.update(reactionRef, {
        kind: desiredKind,
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      transaction.create(reactionRef, {
        userId: uid,
        kind: desiredKind,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    transaction.update(postRef, { likesCount, applauseCount });

    return {
      changed: true,
      reaction: desiredKind,
      likesCount,
      applauseCount,
    };
  });
});

exports.createConquestComment = onCall({ region: REGION }, async (request) => {
  const uid = requireCallableAuth(request);
  const postId = requireId(request.data?.postId, "postId");
  const commentId = requireCommentId(request.data?.commentId);
  const text = requireTrimmedText(request.data?.text, "text", 500);
  const postRef = db.collection("conquest_posts").doc(postId);
  const commentRef = postRef.collection("comments").doc(commentId);
  const authorDocument = await db.collection("users").doc(uid).get();
  const author = authorDocument.exists ? authorDocument.data() : {};
  const authorName = typeof author?.displayName === "string"
    ? author.displayName
    : "Corredor";
  const authorPhotoUrl = typeof author?.photoUrl === "string"
    ? author.photoUrl
    : null;

  return db.runTransaction(async (transaction) => {
    const postDocument = await transaction.get(postRef);
    if (!postDocument.exists) {
      throw new HttpsError("not-found", "La conquista no existe.");
    }
    const post = postDocument.data();
    const connection = await getConnectionBetween(uid, post.userId, transaction);
    if (!canAccessPost(uid, post, connection)) {
      throw new HttpsError(
        "permission-denied",
        "No puedes comentar esta conquista."
      );
    }

    const commentDocument = await transaction.get(commentRef);
    if (commentDocument.exists) {
      const current = commentDocument.data();
      if (current.authorId === uid && current.text === text) {
        return { commentId, created: false };
      }
      throw new HttpsError(
        "already-exists",
        "commentId ya se uso para otro comentario."
      );
    }

    transaction.create(commentRef, {
      authorId: uid,
      authorName,
      authorPhotoUrl,
      text,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: null,
      deletedAt: null,
      isDeleted: false,
      moderationStatus: "ok",
    });
    transaction.update(postRef, {
      commentsCount: numericCount(post.commentsCount) + 1,
    });
    return { commentId, created: true };
  });
});

exports.deleteConquestComment = onCall({ region: REGION }, async (request) => {
  const uid = requireCallableAuth(request);
  const postId = requireId(request.data?.postId, "postId");
  const commentId = requireCommentId(request.data?.commentId);
  const postRef = db.collection("conquest_posts").doc(postId);
  const commentRef = postRef.collection("comments").doc(commentId);

  return db.runTransaction(async (transaction) => {
    const [postDocument, commentDocument] = await Promise.all([
      transaction.get(postRef),
      transaction.get(commentRef),
    ]);
    if (!commentDocument.exists) {
      return { commentId, deleted: false };
    }
    const ownsComment = commentDocument.data().authorId === uid;
    const ownsPost = postDocument.exists && postDocument.data().userId === uid;
    if (!ownsComment && !ownsPost) {
      throw new HttpsError(
        "permission-denied",
        "No puedes borrar este comentario."
      );
    }
    if (commentDocument.data().isDeleted === true) {
      return { commentId, deleted: false };
    }

    transaction.update(commentRef, {
      isDeleted: true,
      deletedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      text: "",
    });
    if (postDocument.exists) {
      transaction.update(postRef, {
        commentsCount: Math.max(
          0,
          numericCount(postDocument.data().commentsCount) - 1
        ),
      });
    }
    return { commentId, deleted: true };
  });
});

exports.reportConquestPost = onCall({ region: REGION }, async (request) => {
  const uid = requireCallableAuth(request);
  const postId = requireId(request.data?.postId, "postId");
  const reason = request.data?.reason;
  if (!REPORT_REASONS.has(reason)) {
    throw new HttpsError("invalid-argument", "Motivo de reporte no valido.");
  }
  const details = optionalTrimmedText(request.data?.details, "details", 500);
  const postRef = db.collection("conquest_posts").doc(postId);
  const reportRef = postRef.collection("reports").doc(uid);

  return db.runTransaction(async (transaction) => {
    const [postDocument, reportDocument] = await Promise.all([
      transaction.get(postRef),
      transaction.get(reportRef),
    ]);
    if (!postDocument.exists) {
      throw new HttpsError("not-found", "La conquista no existe.");
    }
    const post = postDocument.data();
    if (reportDocument.exists) {
      return {
        created: false,
        reportCount: numericCount(post.reportCount),
        moderationStatus: post.moderationStatus ?? "ok",
      };
    }
    if (post.userId === uid) {
      throw new HttpsError(
        "failed-precondition",
        "No puedes reportar tu propia conquista."
      );
    }

    const connection = await getConnectionBetween(uid, post.userId, transaction);
    if (!canAccessPost(uid, post, connection, {
      allowOwner: false,
      allowUnderReview: true,
    })) {
      throw new HttpsError(
        "permission-denied",
        "No puedes reportar esta conquista."
      );
    }

    const reportCount = numericCount(post.reportCount) + 1;
    let moderationStatus = post.moderationStatus ?? "ok";
    if (moderationStatus !== "removed") {
      if (reportCount >= REPORT_HIDE_THRESHOLD) {
        moderationStatus = "hidden";
      } else if (
        reportCount >= REPORT_REVIEW_THRESHOLD &&
        moderationStatus === "ok"
      ) {
        moderationStatus = "under_review";
      }
    }

    transaction.create(reportRef, {
      postId,
      reporterId: uid,
      reason,
      details,
      status: "open",
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.update(postRef, { reportCount, moderationStatus });
    return { created: true, reportCount, moderationStatus };
  });
});

exports.blockRunner = onCall({ region: REGION }, async (request) => {
  const uid = requireCallableAuth(request);
  const otherUserId = requireId(request.data?.otherUserId, "otherUserId");
  if (otherUserId === uid) {
    throw new HttpsError("invalid-argument", "No puedes bloquearte a ti mismo.");
  }

  const connectionRef = db
    .collection("connections")
    .doc(connectionIdFor(uid, otherUserId));
  const otherUserRef = db.collection("users").doc(otherUserId);
  return db.runTransaction(async (transaction) => {
    const [connectionDocument, otherUserDocument] = await Promise.all([
      transaction.get(connectionRef),
      transaction.get(otherUserRef),
    ]);
    if (!otherUserDocument.exists) {
      throw new HttpsError("not-found", "El corredor no existe.");
    }
    if (connectionDocument.exists && connectionDocument.data().status === "blocked") {
      const blockers = blockingUsers(connectionDocument.data());
      if (blockers.includes(uid)) {
        return { changed: false, blocked: true };
      }
      blockers.push(uid);
      blockers.sort();
      transaction.update(connectionRef, {
        blockedByUsers: blockers,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { changed: true, blocked: true };
    }

    if (connectionDocument.exists) {
      transaction.update(connectionRef, {
        status: "blocked",
        blockedBy: uid,
        blockedByUsers: [uid],
        blockedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      transaction.create(connectionRef, {
        requesterUserId: uid,
        recipientUserId: otherUserId,
        participants: sortedParticipants(uid, otherUserId),
        status: "blocked",
        source: "username",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        acceptedAt: null,
        blockedAt: FieldValue.serverTimestamp(),
        blockedBy: uid,
        blockedByUsers: [uid],
      });
    }
    return { changed: true, blocked: true };
  });
});

exports.unblockRunner = onCall({ region: REGION }, async (request) => {
  const uid = requireCallableAuth(request);
  const otherUserId = requireId(request.data?.otherUserId, "otherUserId");
  if (otherUserId === uid) {
    throw new HttpsError("invalid-argument", "Usuario no valido.");
  }
  const connectionRef = db
    .collection("connections")
    .doc(connectionIdFor(uid, otherUserId));

  return db.runTransaction(async (transaction) => {
    const connectionDocument = await transaction.get(connectionRef);
    if (!connectionDocument.exists || connectionDocument.data().status !== "blocked") {
      return { changed: false, blocked: false };
    }
    const blockers = blockingUsers(connectionDocument.data());
    if (!blockers.includes(uid)) {
      throw new HttpsError(
        "permission-denied",
        "Solo puedes retirar tu propio bloqueo."
      );
    }
    const remainingBlockers = blockers.filter((blocker) => blocker !== uid);
    if (remainingBlockers.length > 0) {
      transaction.update(connectionRef, {
        status: "blocked",
        blockedBy: remainingBlockers[0],
        blockedByUsers: remainingBlockers,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { changed: true, blocked: true };
    }

    transaction.update(connectionRef, {
      status: "removed",
      blockedBy: null,
      blockedByUsers: [],
      blockedAt: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { changed: true, blocked: false };
  });
});

exports.moderateConquestPost = onCall({ region: REGION }, async (request) => {
  const uid = requireCallableAuth(request);
  const claims = request.auth.token ?? {};
  if (claims.moderator !== true && claims.admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Se requiere el rol de moderacion."
    );
  }
  const postId = requireId(request.data?.postId, "postId");
  const status = request.data?.status;
  if (!MODERATION_STATUSES.has(status)) {
    throw new HttpsError("invalid-argument", "Estado de moderacion no valido.");
  }
  const postRef = db.collection("conquest_posts").doc(postId);

  return db.runTransaction(async (transaction) => {
    const postDocument = await transaction.get(postRef);
    if (!postDocument.exists) {
      throw new HttpsError("not-found", "La conquista no existe.");
    }
    if (postDocument.data().moderationStatus === status) {
      return { changed: false, moderationStatus: status };
    }
    transaction.update(postRef, {
      moderationStatus: status,
      moderatedAt: FieldValue.serverTimestamp(),
      moderatedBy: uid,
    });
    return { changed: true, moderationStatus: status };
  });
});
