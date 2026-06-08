#!/usr/bin/env node
'use strict';

/**
 * RunRace — Seed de zonas de Madrid en Firestore
 *
 * Uso:
 *   node scripts/seed_zones_madrid.js \
 *     --project=runrace-XXXXX \
 *     --keyfile=./service-account.json \
 *     [--clear]   ← borra las zonas existentes antes de crear
 *
 * Alternativa sin --keyfile (usa GOOGLE_APPLICATION_CREDENTIALS del entorno):
 *   GOOGLE_APPLICATION_CREDENTIALS=./sa.json node scripts/seed_zones_madrid.js --project=...
 */

const path  = require('path');
const admin = require('firebase-admin');
const turf  = require('@turf/turf');

// ── CLI args ──────────────────────────────────────────────────────────────────
const args = Object.fromEntries(
  process.argv.slice(2)
    .filter(a => a.startsWith('--'))
    .map(a => {
      const eqIdx = a.indexOf('=');
      if (eqIdx === -1) return [a.slice(2), true];
      return [a.slice(2, eqIdx), a.slice(eqIdx + 1)];
    })
);

const PROJECT_ID = args['project'];
const KEY_FILE   = args['keyfile'];
const CLEAR      = Boolean(args['clear']);

if (!PROJECT_ID) {
  console.error('\n❌  Falta --project=YOUR_PROJECT_ID\n');
  process.exit(1);
}

// ── Firebase init ─────────────────────────────────────────────────────────────
let credential;
if (KEY_FILE) {
  const saPath = path.resolve(process.cwd(), KEY_FILE);
  credential   = admin.credential.cert(require(saPath));
} else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  credential = admin.credential.applicationDefault();
} else {
  console.error(
    '\n❌  Credenciales no encontradas.\n' +
    '    Usa --keyfile=ruta/service-account.json\n' +
    '    o configura GOOGLE_APPLICATION_CREDENTIALS.\n'
  );
  process.exit(1);
}

admin.initializeApp({ credential, projectId: PROJECT_ID });

const db       = admin.firestore();
const GeoPoint = admin.firestore.GeoPoint;

// ── Datos de zonas ────────────────────────────────────────────────────────────
// Coordenadas en formato GeoJSON estándar: [longitud, latitud]
// El primer punto == último punto (anillo cerrado) para que turf pueda
// calcular el centroide; en Firestore se almacena sin el punto de cierre.

const ZONES_RAW = [
  // ── Centro ───────────────────────────────────────────────────────────────
  {
    name: 'El Retiro',
    points: 130,
    // Parque del Retiro + barrio circundante
    coords: [
      [-3.6921, 40.4198],
      [-3.6818, 40.4196],
      [-3.6804, 40.4150],
      [-3.6830, 40.4086],
      [-3.6920, 40.4088],
      [-3.6932, 40.4140],
      [-3.6921, 40.4198],
    ],
  },
  {
    name: 'Malasaña',
    points: 80,
    // Acotado por Glorieta Bilbao (N), Gran Vía (S), Fuencarral (E), San Bernardo (W)
    coords: [
      [-3.7050, 40.4320],
      [-3.6985, 40.4315],
      [-3.6975, 40.4220],
      [-3.7020, 40.4205],
      [-3.7065, 40.4210],
      [-3.7075, 40.4280],
      [-3.7050, 40.4320],
    ],
  },
  {
    name: 'Chueca',
    points: 85,
    // Entre Alonso Martínez, Fuencarral, Gran Vía y Castellana
    coords: [
      [-3.6985, 40.4295],
      [-3.6878, 40.4288],
      [-3.6865, 40.4215],
      [-3.6910, 40.4198],
      [-3.6975, 40.4205],
      [-3.6985, 40.4295],
    ],
  },
  {
    name: 'Lavapiés',
    points: 75,
    // Barrio Embajadores, entorno metro Lavapiés
    coords: [
      [-3.7028, 40.4090],
      [-3.6950, 40.4082],
      [-3.6938, 40.4018],
      [-3.7005, 40.4005],
      [-3.7055, 40.4020],
      [-3.7060, 40.4065],
      [-3.7028, 40.4090],
    ],
  },
  {
    name: 'La Latina',
    points: 70,
    // Cava Baja, Plaza de la Paja, Toledo
    coords: [
      [-3.7100, 40.4135],
      [-3.7030, 40.4128],
      [-3.7025, 40.4068],
      [-3.7080, 40.4055],
      [-3.7135, 40.4068],
      [-3.7140, 40.4112],
      [-3.7100, 40.4135],
    ],
  },
  {
    name: 'Gran Vía',
    points: 65,
    // Tramo central Gran Vía + calles adyacentes
    coords: [
      [-3.7085, 40.4205],
      [-3.6940, 40.4196],
      [-3.6928, 40.4143],
      [-3.6990, 40.4128],
      [-3.7075, 40.4135],
      [-3.7090, 40.4172],
      [-3.7085, 40.4205],
    ],
  },
  {
    name: 'Atocha',
    points: 75,
    // Entorno estación Atocha, Paseo del Prado Sur
    coords: [
      [-3.6970, 40.4048],
      [-3.6845, 40.4040],
      [-3.6830, 40.3965],
      [-3.6895, 40.3948],
      [-3.6980, 40.3955],
      [-3.6995, 40.4008],
      [-3.6970, 40.4048],
    ],
  },

  // ── Norte-Centro ─────────────────────────────────────────────────────────
  {
    name: 'Chamberí',
    points: 100,
    // Alonso Martínez, Iglesia, Ríos Rosas
    coords: [
      [-3.7025, 40.4422],
      [-3.6920, 40.4418],
      [-3.6905, 40.4322],
      [-3.6960, 40.4302],
      [-3.7030, 40.4308],
      [-3.7045, 40.4382],
      [-3.7025, 40.4422],
    ],
  },
  {
    name: 'Salamanca',
    points: 110,
    // Serrano, Velázquez, Goya, Castellana Este
    coords: [
      [-3.6882, 40.4282],
      [-3.6755, 40.4278],
      [-3.6740, 40.4188],
      [-3.6800, 40.4168],
      [-3.6882, 40.4172],
      [-3.6898, 40.4222],
      [-3.6882, 40.4282],
    ],
  },
  {
    name: 'Castellana Norte',
    points: 95,
    // Santiago Bernabéu, Nuevos Ministerios
    coords: [
      [-3.6938, 40.4525],
      [-3.6772, 40.4520],
      [-3.6758, 40.4418],
      [-3.6832, 40.4398],
      [-3.6948, 40.4405],
      [-3.6962, 40.4472],
      [-3.6938, 40.4525],
    ],
  },

  // ── Norte ────────────────────────────────────────────────────────────────
  {
    name: 'Tetuán',
    points: 90,
    // Cuatro Caminos, Bravo Murillo
    coords: [
      [-3.7052, 40.4622],
      [-3.6898, 40.4618],
      [-3.6882, 40.4512],
      [-3.6942, 40.4492],
      [-3.7062, 40.4498],
      [-3.7078, 40.4568],
      [-3.7052, 40.4622],
    ],
  },
  {
    name: 'Fuencarral',
    points: 115,
    // Barrio de Fuencarral, Las Tablas Sur
    coords: [
      [-3.7182, 40.4832],
      [-3.6992, 40.4828],
      [-3.6978, 40.4682],
      [-3.7052, 40.4658],
      [-3.7192, 40.4665],
      [-3.7222, 40.4762],
      [-3.7182, 40.4832],
    ],
  },
  {
    name: 'Sanchinarro',
    points: 100,
    // Las Tablas Norte, Sanchinarro residencial
    coords: [
      [-3.6622, 40.5012],
      [-3.6402, 40.5008],
      [-3.6388, 40.4852],
      [-3.6472, 40.4830],
      [-3.6635, 40.4838],
      [-3.6662, 40.4932],
      [-3.6622, 40.5012],
    ],
  },
  {
    name: 'Hortaleza',
    points: 120,
    // Palomas, Pinar del Rey, Manoteras
    coords: [
      [-3.6642, 40.4782],
      [-3.6422, 40.4778],
      [-3.6402, 40.4622],
      [-3.6492, 40.4598],
      [-3.6652, 40.4602],
      [-3.6682, 40.4702],
      [-3.6642, 40.4782],
    ],
  },
  {
    name: 'Barajas',
    points: 110,
    // Pueblo Barajas, entorno aeropuerto
    coords: [
      [-3.5962, 40.4782],
      [-3.5712, 40.4778],
      [-3.5692, 40.4612],
      [-3.5792, 40.4588],
      [-3.5972, 40.4595],
      [-3.6008, 40.4698],
      [-3.5962, 40.4782],
    ],
  },

  // ── Este ─────────────────────────────────────────────────────────────────
  {
    name: 'Ciudad Lineal',
    points: 85,
    // Arturo Soria, Pueblo Nuevo
    coords: [
      [-3.6622, 40.4492],
      [-3.6432, 40.4488],
      [-3.6418, 40.4362],
      [-3.6492, 40.4342],
      [-3.6632, 40.4350],
      [-3.6658, 40.4432],
      [-3.6622, 40.4492],
    ],
  },
  {
    name: 'Moratalaz',
    points: 75,
    // Entorno metro Vinateros, Pavones
    coords: [
      [-3.6602, 40.4098],
      [-3.6422, 40.4092],
      [-3.6408, 40.3988],
      [-3.6482, 40.3968],
      [-3.6612, 40.3972],
      [-3.6632, 40.4048],
      [-3.6602, 40.4098],
    ],
  },

  // ── Sur ──────────────────────────────────────────────────────────────────
  {
    name: 'Arganzuela',
    points: 85,
    // Madrid Río, Delicias, Legazpi
    coords: [
      [-3.7152, 40.3992],
      [-3.7022, 40.3985],
      [-3.7012, 40.3898],
      [-3.7072, 40.3880],
      [-3.7162, 40.3888],
      [-3.7178, 40.3948],
      [-3.7152, 40.3992],
    ],
  },
  {
    name: 'Usera',
    points: 70,
    // Barrio chino, Pradolongo
    coords: [
      [-3.7092, 40.3882],
      [-3.6952, 40.3878],
      [-3.6938, 40.3782],
      [-3.7008, 40.3765],
      [-3.7102, 40.3770],
      [-3.7118, 40.3838],
      [-3.7092, 40.3882],
    ],
  },
  {
    name: 'Carabanchel',
    points: 95,
    // San Isidro, Pradolongo, Aluche Norte
    coords: [
      [-3.7282, 40.3922],
      [-3.7098, 40.3918],
      [-3.7082, 40.3802],
      [-3.7152, 40.3778],
      [-3.7282, 40.3782],
      [-3.7312, 40.3852],
      [-3.7282, 40.3922],
    ],
  },
  {
    name: 'Villaverde',
    points: 95,
    // Villaverde Alto, San Cristóbal
    coords: [
      [-3.7212, 40.3682],
      [-3.6982, 40.3678],
      [-3.6962, 40.3532],
      [-3.7062, 40.3510],
      [-3.7218, 40.3518],
      [-3.7252, 40.3612],
      [-3.7212, 40.3682],
    ],
  },
  {
    name: 'Puente de Vallecas',
    points: 80,
    // Entorno metro Portazgo, Picazo
    coords: [
      [-3.6752, 40.4012],
      [-3.6612, 40.4008],
      [-3.6598, 40.3912],
      [-3.6662, 40.3892],
      [-3.6758, 40.3898],
      [-3.6778, 40.3962],
      [-3.6752, 40.4012],
    ],
  },
  {
    name: 'Villa de Vallecas',
    points: 105,
    // Casco histórico Vallecas, Santa Eugenia
    coords: [
      [-3.6758, 40.3802],
      [-3.6552, 40.3798],
      [-3.6532, 40.3662],
      [-3.6622, 40.3638],
      [-3.6762, 40.3645],
      [-3.6792, 40.3732],
      [-3.6758, 40.3802],
    ],
  },
  {
    name: 'El Pozo del Tío Raimundo',
    points: 70,
    // Entre Vallecas y Moratalaz
    coords: [
      [-3.6552, 40.3882],
      [-3.6382, 40.3875],
      [-3.6368, 40.3772],
      [-3.6442, 40.3752],
      [-3.6562, 40.3760],
      [-3.6588, 40.3835],
      [-3.6552, 40.3882],
    ],
  },
  {
    name: 'Moncloa',
    points: 90,
    // Ciudad Universitaria, Princesa
    coords: [
      [-3.7242, 40.4382],
      [-3.7122, 40.4378],
      [-3.7112, 40.4302],
      [-3.7168, 40.4282],
      [-3.7252, 40.4288],
      [-3.7268, 40.4348],
      [-3.7242, 40.4382],
    ],
  },
];

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Elimina el punto de cierre del anillo (primero == último) para Firestore. */
function openRing(coords) {
  const first = coords[0];
  const last  = coords[coords.length - 1];
  return (first[0] === last[0] && first[1] === last[1])
    ? coords.slice(0, -1)
    : coords;
}

/** Convierte coordenadas GeoJSON [lng, lat] a objeto { lat, lng } para Firestore. */
function toLatLngMap([lng, lat]) {
  return { lat, lng };
}

/** Borra todos los documentos de la colección en batches de 400. */
async function clearCollection(collRef) {
  let deleted = 0;
  let snap;
  do {
    snap = await collRef.limit(400).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
    deleted += snap.size;
    process.stdout.write(`   Borradas ${deleted} zonas existentes...\r`);
  } while (!snap.empty);
  console.log(`   Borradas ${deleted} zona(s) existente(s).          `);
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function seed() {
  const total    = ZONES_RAW.length;
  const zonesRef = db.collection('zones');

  console.log('\n🏃  RunRace — Seed de zonas de Madrid');
  console.log(`    Proyecto : ${PROJECT_ID}`);
  console.log(`    Zonas    : ${total}`);
  console.log(`    Limpiar  : ${CLEAR ? 'sí' : 'no'}\n`);

  if (CLEAR) {
    process.stdout.write('   Borrando zonas existentes…\n');
    await clearCollection(zonesRef);
  }

  // Firestore batch: máx 500 ops, estamos bien con 25 zonas
  const batch = db.batch();

  for (let i = 0; i < total; i++) {
    const raw = ZONES_RAW[i];
    process.stdout.write(`   [${String(i + 1).padStart(2)}/${total}] ${raw.name}…\n`);

    // Validar mínimo de puntos únicos (sin el de cierre)
    const unique = openRing(raw.coords);
    if (unique.length < 3) {
      console.error(`   ⚠️  ${raw.name}: polígono con menos de 3 puntos únicos, se omite.`);
      continue;
    }

    // Calcular centroide con turf
    const turfPoly         = turf.polygon([raw.coords]);
    const centroidFeature  = turf.centroid(turfPoly);
    const [cLng, cLat]     = centroidFeature.geometry.coordinates;

    // Calcular área aproximada en km² para info de log
    const areaKm2 = (turf.area(turfPoly) / 1e6).toFixed(2);

    const doc = {
      name:      raw.name,
      city:      'Madrid',
      // Polígono como [{lat, lng}] — formato que lee ZoneModel.fromFirestore()
      polygon:   unique.map(toLatLngMap),
      // Centroide como GeoPoint — formato que lee validateCapture()
      centroid:  new GeoPoint(cLat, cLng),
      ownerId:   null,
      ownerName: null,
      ownerType: null,
      capturedAt: null,
      expiresAt:  null,
      points:    raw.points,
      color:     '#FFFFFF',  // blanco = zona libre
    };

    console.log(`         área ≈ ${areaKm2} km² · centroide (${cLat.toFixed(4)}, ${cLng.toFixed(4)})`);

    batch.set(zonesRef.doc(), doc);
  }

  process.stdout.write('\n   Escribiendo en Firestore…\n');
  await batch.commit();

  console.log(`\n✅  ${total} zonas creadas en Firestore (colección "zones")\n`);
}

seed().catch(err => {
  console.error('\n❌  Error:', err.message ?? err);
  process.exit(1);
});
