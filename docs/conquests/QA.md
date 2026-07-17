# QA de conquistas, feed e interacciones

Esta matriz cubre las fases D-F. Ejecutarla primero con emuladores y despues en
un proyecto de staging con usuarios desechables.

## Preparacion

Crear cuatro actores:

| Actor | Estado |
| --- | --- |
| A | Autor de posts e historias |
| B | Usuario autenticado sin bloqueo |
| C | Usuario que sera bloqueado por A |
| M | Usuario con custom claim `moderator: true` |

Preparar posts de A con visibilidad publica y privada, uno archivado, uno
borrado logicamente y una historia con expiracion corta. No usar datos personales
reales en captions, comentarios, nombres ni imagenes.

## Matriz funcional y de permisos

| Caso | Accion | Resultado esperado |
| --- | --- | --- |
| Feed publico | B abre y pagina el feed | Orden descendente, sin duplicados y con cursor estable |
| Privacidad | B intenta abrir el post privado de A por ID | `permission-denied` o `not-found`, sin filtrar metadatos |
| Propietario | A abre "Mis conquistas" | Ve sus posts permitidos, incluidos los privados |
| Archivado/borrado | B refresca el feed | No aparecen ni son interactuables |
| Historia activa | B la abre dos veces | Se conserva una sola `story_view` con la primera fecha |
| Historias visibles | B abre Comunidad | Solo aparecen historias activas publicas o de conexiones no bloqueadas |
| Historia caducada | B abre tras `expiresAt` | No se devuelve ni admite interaccion |
| Reaccion nueva | B aplaude el post | Un doc `reactions/{uid}` y contador correcto |
| Reintento | Repetir exactamente la misma peticion | Sin documento ni incremento duplicado |
| Cambio | B cambia `applause` por `like` | Sigue habiendo una reaccion y los contadores cuadran |
| Retirada | B elimina su reaccion | Desaparece su doc y el contador no baja de cero |
| Comentario | B envia texto valido | Se normaliza, aparece una vez y sube el contador |
| Comentario invalido | Vacio, solo espacios o sobre el limite | `invalid-argument`, sin documento ni contador |
| Borrado propio | B elimina su comentario | Borrado logico, texto no visible y contador ajustado una vez |
| Borrado ajeno | C intenta borrar el comentario de B | `permission-denied` |
| Reporte propio duplicado | B reporta dos veces el mismo post | Un solo reporte y un solo incremento |
| Motivo invalido | B envia un codigo fuera del enum como motivo | `invalid-argument` |
| Detalles de reporte | B envia detalles de mas de 500 caracteres | `invalid-argument`, sin reporte parcial |
| Umbral 3 | Tres usuarios distintos reportan | Estado `under_review`; desaparece para terceros |
| Umbral 5 | Cinco usuarios distintos reportan | Estado `hidden` |
| Moderador | M cambia a `ok`, `hidden` y `removed` | Solo valores admitidos y auditoria coherente |
| Sin claim | B llama a moderacion | `permission-denied` |
| Bloqueo sin conexion | A bloquea a C | Se crea/actualiza el par determinista sin solicitud pendiente |
| Bloqueo repetido | A repite `blockRunner` | Idempotente, conserva quien bloqueo |
| Bloqueo cruzado | C intenta interactuar o abrir detalle de A | Rechazado por backend y oculto en UI |
| Bloqueo mutuo | A bloquea a C y despues C bloquea a A | Se conservan ambas intenciones; quitar una no elimina la otra |
| Desbloqueo ajeno | C intenta quitar el bloqueo de A | `permission-denied` |
| Desbloqueo propio | A desbloquea a C | Se retira el bloqueo, sin restaurar conexion previa |

## Concurrencia y resiliencia

- Lanzar reacciones simultaneas de varios usuarios y comparar documentos con
  contadores del post.
- Lanzar el tercer y quinto reporte en paralelo; el estado final debe ser
  `under_review` y `hidden`, respectivamente.
- Cortar la red despues de pulsar una accion y reintentar al reconectar. No debe
  duplicarse reaccion, reporte, bloqueo ni comentario confirmado.
- Paginar mientras entra un post nuevo. No repetir filas y no perder la
  posibilidad de refrescar desde el inicio.
- Abrir detalle, bloquear al autor desde otro dispositivo y volver a actuar en
  el detalle antiguo. El backend debe rechazarlo aunque la UI aun no refrescase.

## Moderacion y retirada de media

1. Moderar un post con imagen como `hidden`: desaparece del producto, pero
   comprobar que una download URL guardada puede seguir respondiendo.
2. Moderarlo como `removed` y ejecutar el procedimiento de retirada del objeto.
3. Verificar que la URL deja de servir cuando el objeto/token ha sido revocado.
4. Confirmar que miniaturas, caches y logs no contienen una segunda URL activa.
5. Registrar que un usuario autenticado que conozca la ruta de Storage puede
   leerla con las reglas actuales, aunque el post no sea visible.

Este caso demuestra una limitacion deliberadamente documentada: las reglas de
Firestore no revocan archivos ya descargados ni URLs previamente compartidas.

## Analytics y privacidad

Revisar Firebase Analytics DebugView durante cada flujo:

- cada apertura registra como maximo el evento de pantalla correspondiente;
- una accion confirmada registra un evento, no cada rebuild del widget;
- los parametros solo contienen enums cerrados;
- no aparecen UID, postId, commentId, caption, comentario, nombre, URL,
  coordenadas, nombre de zona ni motivo en texto libre;
- con `NoopAnalyticsService` no se emite ningun evento.

## Accesibilidad y UI

- Probar loading, error, vacio y paginacion en feed y "Mis conquistas".
- Confirmar labels semanticos en avatar, imagen, aplauso, comentarios y menu.
- Comprobar contraste, foco de teclado y botones con area tactil suficiente.
- Probar textos largos, nombres largos y media ausente/error de red.
- Verificar que el teclado no tapa el campo ni el envio de comentarios.
- Revisar el comportamiento con tamanos de texto del sistema: actualmente la
  app fija `TextScaler.noScaling`, limitacion que debe quedar registrada antes
  de una auditoria de accesibilidad.

## Comandos de verificacion

Desde PowerShell, en la raiz del repositorio:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
npm --prefix functions ci
node --check functions/index.js
firebase emulators:start --only firestore,functions
```

Con los emuladores en ejecucion, lanzar la suite de integracion configurada
contra `FIRESTORE_EMULATOR_HOST` y `FUNCTIONS_EMULATOR_HOST`. Antes del release:

```powershell
firebase deploy --only "firestore:rules,firestore:indexes"
firebase deploy --only "functions:getConquestFeed,functions:getConquestStories,functions:getConquestDetail,functions:setConquestReaction,functions:createConquestComment,functions:deleteConquestComment,functions:reportConquestPost,functions:blockRunner,functions:unblockRunner,functions:moderateConquestPost"
git status --short
```

La puerta de salida queda cerrada si falla analyze/tests, si un contador no
coincide con sus subdocumentos, si un bloqueado puede leer/interactuar mediante
callable o si analytics contiene PII.
