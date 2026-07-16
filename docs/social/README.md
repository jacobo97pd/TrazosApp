# Social — Conexiones de corredores (Fase B)

## Limitación real de Strava
La API pública NO da amigos/seguidores ni señal de que dos atletas se conozcan.
Por eso NO hay "importar amigos". El descubrimiento por Strava es un **directorio
opt-in**: usuarios de Trazos con Strava conectado que activan
`social.discoverable`. Fuente = `stravaMatch` ("También usa Trazos"). El resto de
altas (username, inviteLink, qr, club, challenge) son el camino principal.

## Consentimiento y privacidad
`SocialPrivacy` (en `users/{uid}.social`) por defecto restrictivo:
`discoverable=false` (se activa explícitamente, nunca en silencio),
`showActivities=false`, `aggregatedOnly=true`, `appearInLeaderboards=false`.
El usuario puede sincronizar Strava sin participar en lo social.

## Modelo de datos
- `connections/{id}` con `id = min(uidA,uidB)_max(...)` → **doc único por par**:
  impide duplicados y solicitudes cruzadas (ambas direcciones = mismo doc).
  Campos: requester/recipientUserId, participants[2], status, source, fechas,
  blockedBy. Estados: suggested/pending/accepted/declined/blocked/removed.

## Reglas de seguridad
Solo los dos `participants` leen/escriben su doc; el solicitante crea; no se
puede cambiar `participants`; no se borra (se marca removed/blocked). Endurecer
en backend las transiciones finas (accept solo por recipient) es trabajo futuro.

## Idempotencia / casos límite
- Duplicado mismo solicitante → no reenvía. Cruzado → aceptado.
- Bloqueado → no admite solicitudes. Declinado/removed → permite nueva.
- Revocar Strava / borrar cuenta / no-participante en retos: fases siguientes.

## Componentes
`RunnerConnection`, `RunnerConnectionService` (puro), `RunnerConnectionRepository`
(+Firestore/InMemory), `StravaIdentityMatcher`, `SocialPrivacy`.

## Ampliar
Nuevos orígenes = añadir a `ConnectionSource`. Nuevas transiciones = método en
el service con su guarda + test. UI en Fase G.
