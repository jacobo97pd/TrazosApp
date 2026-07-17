# Zapatillas — Gestión y desgaste

## Limitación de Strava
Con scope `read` se leen las zapatillas del atleta (`/athlete` → `shoes[]`) y el
`gear_id` de cada actividad (`/athlete/activities`). Trazos **NO** modifica el
equipamiento en Strava. La sync es del lado cliente (tokens solo en cliente).

## Modelo de datos
- `shoes/{id}` (id `strava_<gearId>` para importadas). Separa datos de Strava,
  calculados por Trazos y editados a mano.
- `shoeActivityLinks/{userId_activityId}` = **fuente de verdad** del km. Un doc
  por actividad → idempotente; el km se **reconstruye** desde los enlaces.
- Reglas: dueño-only en ambas colecciones.

## Sincronización (idempotente)
`ShoeSyncService.plan()` (puro): crea zapatillas nuevas (parser tolerante de
nombre), enlaza actividad↔zapatilla y recalcula `syncedDistanceMeters` con
`ShoeDistanceCalculator`. Precedencia:
- km sincronizado ← actividades (no un contador mutable).
- foto/notas/límite ← locales del usuario.
- **marca/modelo/apodo editados a mano NO se sobrescriben** (zapatilla existente).
- **reasignación manual** de una actividad a otra zapatilla se respeta en re-sync.

## Casos límite gestionados
Actividad duplicada/eliminada/actualizada, cambio de zapatilla, valores basura
(0/negativo/NaN/Infinity), actividad sin gear → `unassigned`, desvinculación de
Strava (los enlaces locales siguen dando km). Ver tests en `test/shoes/`.

## Desgaste (estimación)
`ShoeWearEstimator`: % + estado (nueva…sustitución) + **nivel de confianza** +
disclaimer obligatorio. Límite configurable; 0/NaN → baja confianza, nunca
definitivo. Sin peso/biomecánica/médico.

## Ampliar el estimador
Añadir factores (superficie, tipo de uso) ajustando `_confidence`/umbrales sin
cambiar la firma pública. Nuevos logros de zapatillas = añadir métrica a
`AchievementMetric` + `RunnerStats` + catálogo (ya integrados).

## Analytics
Eventos (`shoe_imported`, `shoe_wear_viewed`, …) **diferidos**: puntos marcados
como TODO; aplicar la política no-PII (sin marca/modelo como texto libre).
