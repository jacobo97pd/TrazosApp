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
const MIN_OVERLAP_RATIO    = 0.60;
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

// ── 1. validateCapture (callable) ────────────────────────────────────────────
//
// Recibe: { polygonCoords: [{lat, lng}], zoneId: string }
// Retorna: { success: bool, points?: number, reason?: string }
//
// Validaciones (todas en servidor para evitar trampas):
//   a) polygonCoords.length >= 4
//   b) El GeoJSON cierra correctamente
//   c) Perímetro >= 500 m
//   d) booleanPointInPolygon(zone.centroid, runnerPolygon)
//   e) Si zona con dueño: área(intersección) / área(zona) >= 60 %
//   f) Anti-cheat: uid del token JWT == userId en contexto de auth
//
// Si todo OK: actualiza zones/{zoneId} y users/{uid} en transacción atómica.
// FCM al dueño anterior se envía FUERA de la transacción.

exports.validateCapture = onCall({ region: REGION }, async (request) => {
  // f) Autenticación obligatoria
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes estar autenticado.");
  }

  const uid              = request.auth.uid;
  const { polygonCoords, zoneId } = request.data ?? {};

  if (!Array.isArray(polygonCoords) || typeof zoneId !== "string") {
    throw new HttpsError("invalid-argument", "Parámetros incorrectos.");
  }

  // a) Mínimo de puntos
  if (polygonCoords.length < MIN_POLYGON_POINTS) {
    return { success: false, reason: "min_points" };
  }

  // b) Construir GeoJSON (lanza si las coordenadas no son válidas)
  let runnerPolygon;
  try {
    runnerPolygon = turf.polygon([toClosedRing(polygonCoords)]);
  } catch {
    return { success: false, reason: "invalid_polygon" };
  }

  // c) Perímetro mínimo — se usa el perímetro del polígono como proxy de distancia
  const perimeterKm = turf.length(
    turf.lineString(runnerPolygon.geometry.coordinates[0]),
    { units: "kilometers" }
  );
  if (perimeterKm * 1000 < MIN_PERIMETER_M) {
    return { success: false, reason: "insufficient_distance" };
  }

  // c2) Anti-trampas por velocidad media (defensa en profundidad; el cliente
  // también lo valida). Si no llegan los datos, no bloqueamos por esto.
  const distM = Number(request.data?.distanceMeters);
  const durS  = Number(request.data?.durationSeconds);
  if (Number.isFinite(distM) && Number.isFinite(durS) && durS > 0) {
    const avgKmh = (distM / 1000) / (durS / 3600);
    if (avgKmh > MAX_AVG_SPEED_KMH || avgKmh < MIN_AVG_SPEED_KMH) {
      return { success: false, reason: "invalid_speed" };
    }
  }

  // ── Lectura + escritura atómica ──────────────────────────────────────────
  const zoneRef = db.collection("zones").doc(zoneId);
  const userRef = db.collection("users").doc(uid);

  // Capturamos datos del dueño anterior FUERA de la tx para enviar FCM después
  let prevOwnerFcm = null;

  const result = await db.runTransaction(async (tx) => {
    const [zoneSnap, userSnap] = await Promise.all([
      tx.get(zoneRef),
      tx.get(userRef),
    ]);

    if (!zoneSnap.exists) {
      return { success: false, reason: "zone_not_found" };
    }

    const zone = zoneSnap.data();
    const user = userSnap.data() ?? {};
    let prevOwnerRef = null;
    let prevOwnerSnap = null;

    if (zone.ownerId && zone.ownerId !== uid) {
      prevOwnerRef = db.collection("users").doc(zone.ownerId);
      prevOwnerSnap = await tx.get(prevOwnerRef);
    }

    // d) Centroide de la zona dentro del polígono del corredor
    const centroidPoint = turf.point([
      zone.centroid.longitude,
      zone.centroid.latitude,
    ]);
    if (!turf.booleanPointInPolygon(centroidPoint, runnerPolygon)) {
      return { success: false, reason: "centroid_not_inside" };
    }

    // e) Si la zona ya tiene dueño: cobertura mínima del 60 %
    if (zone.ownerId) {
      let zonePolygon;
      try {
        zonePolygon = turf.polygon([toClosedRing(zone.polygon)]);
      } catch {
        return { success: false, reason: "invalid_zone_polygon" };
      }

      const intersection = turf.intersect(
        turf.featureCollection([runnerPolygon, zonePolygon])
      );

      if (!intersection) {
        return { success: false, reason: "no_overlap" };
      }

      const overlapRatio = turf.area(intersection) / turf.area(zonePolygon);
      if (overlapRatio < MIN_OVERLAP_RATIO) {
        return {
          success: false,
          reason:  "insufficient_overlap",
          overlap: Math.round(overlapRatio * 100),
        };
      }

      // Guardar info para FCM post-transacción
      if (zone.ownerId !== uid) {
        prevOwnerFcm = { ownerId: zone.ownerId, zoneName: zone.name };
      }
    }

    // ── Todo válido → escribir ────────────────────────────────────────────
    const expiresAt = Timestamp.fromDate(
      new Date(Date.now() + ZONE_EXPIRATION_DAYS * 24 * 60 * 60 * 1000)
    );
    const displayName = user.displayName ?? uid;
    const isClub      = Boolean(user.clubId);

    tx.update(zoneRef, {
      ownerId:    uid,
      ownerName:  displayName,
      ownerType:  isClub ? "club" : "solo",
      capturedAt: Timestamp.now(),
      expiresAt,
      color:      "#FF4D6D",
    });

    tx.update(userRef, {
      capturedZones: FieldValue.arrayUnion(zoneId),
    });

    if (prevOwnerRef && prevOwnerSnap?.exists) {
      tx.update(prevOwnerRef, {
        capturedZones: FieldValue.arrayRemove(zoneId),
      });
    }

    return { success: true, points: zone.points ?? 0 };
  });

  // Enviar FCM al dueño anterior FUERA de la transacción
  if (result.success && prevOwnerFcm) {
    const prevDoc = await db.collection("users").doc(prevOwnerFcm.ownerId).get();
    await sendFcm(
      prevDoc.data()?.fcmToken,
      "¡Te han robado una zona!",
      `Alguien ha capturado ${prevOwnerFcm.zoneName}. ¡Recupérala!`,
      { type: "zone_captured", zoneId }
    );
  }

  return result;
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
      .where("ownerId",   "!=", null)
      .get();

    if (snap.empty) {
      console.log("checkExpiredZones: no hay zonas expiradas.");
      return;
    }

    // Recopilar datos de propietarios antes de limpiar
    const fcmTasks = snap.docs.map(async (doc) => {
      const zone = doc.data();
      if (!zone.ownerId) return;
      const ownerDoc = await db.collection("users").doc(zone.ownerId).get();
      return sendFcm(
        ownerDoc.data()?.fcmToken,
        "Tu zona ha expirado",
        `${zone.name} ha sido liberada. ¡Vuelve a correr para recuperarla!`,
        { type: "zone_expired", zoneId: doc.id }
      );
    });

    // Limpiar zonas en batches (límite Firestore: 500 ops/batch)
    const BATCH_SIZE = 400;
    for (let i = 0; i < snap.docs.length; i += BATCH_SIZE) {
      const batch = db.batch();
      snap.docs.slice(i, i + BATCH_SIZE).forEach((doc) => {
        const zone = doc.data();
        batch.update(doc.ref, {
          ownerId:    null,
          ownerName:  null,
          ownerType:  null,
          capturedAt: null,
          expiresAt:  null,
          color:      null,
        });
        if (zone.ownerId) {
          batch.update(db.collection("users").doc(zone.ownerId), {
            capturedZones: FieldValue.arrayRemove(doc.id),
          });
        }
      });
      await batch.commit();
    }

    // FCMs en paralelo — errores individuales no interrumpen el resto
    await Promise.allSettled(fcmTasks);

    console.log(`checkExpiredZones: ${snap.size} zona(s) liberada(s).`);
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
      .where("ownerId",   "!=", null)
      .get();

    await Promise.allSettled(
      snap.docs.map(async (doc) => {
        const zone    = doc.data();
        const userDoc = await db.collection("users").doc(zone.ownerId).get();
        await sendFcm(
          userDoc.data()?.fcmToken,
          "Defiende tu zona",
          `${zone.name} expira en menos de 24 h. ¡Sal a correr!`,
          { type: "zone_expiring", zoneId: doc.id }
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
