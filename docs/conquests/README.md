# Conquistas, historias e interacciones

Este documento describe la arquitectura social de las conquistas (fases C-F):
publicaciones, historias, feed, interacciones, reportes, bloqueos, moderacion y
analytics. El principio general es que el cliente representa el estado, pero
las decisiones sensibles y los contadores se resuelven en backend.

## Modelo de datos

| Ruta | Proposito | Clave de idempotencia |
| --- | --- | --- |
| `zone_conquests/{conquestId}` | Hito permanente de una zona conquistada | Usuario + actividad |
| `conquest_posts/{postId}` | Publicacion, recuerdo o historia | ID del post |
| `conquest_posts/{postId}/story_views/{viewerId}` | Primera vista de una historia | UID del espectador |
| `conquest_posts/{postId}/reactions/{userId}` | Reaccion actual (`like` o `applause`) | UID del usuario |
| `conquest_posts/{postId}/comments/{commentId}` | Comentario y su borrado logico | ID de cliente estable durante reintentos |
| `conquest_posts/{postId}/reports/{reporterId}` | Reporte unico sobre el post | UID de quien reporta |
| `connections/{pairId}` | Relacion social y bloqueo entre dos usuarios | Par de UID ordenado |

`ConquestPost` conserva snapshots de zona y actividad para que el recuerdo no
cambie si cambia el dato original. Una historia no necesita otro modelo: es un
post con `expiresAt`. La caducidad limita lectura e interaccion aunque el
documento siga existiendo en Firestore.

Los campos `likesCount`, `applauseCount`, `commentsCount`, `reportCount` y
`moderationStatus` son propiedad del servidor. El cliente no debe escribirlos
ni corregirlos de forma optimista en Firestore.

Los comentarios guardan un snapshot de nombre y foto del autor para evitar una
lectura adicional por fila. `deletedAt` representa borrado logico; un comentario
borrado no vuelve a exponer su texto.

Los motivos de reporte son codigos cerrados:

- `spam`
- `harassment`
- `hate_speech`
- `violence`
- `sexual_content`
- `dangerous_activity`
- `privacy`
- `misinformation`
- `other`

El reporte puede incluir detalles opcionales de hasta 500 caracteres para el
equipo de moderacion. Esos detalles no se muestran en el producto, no se
devuelven al autor reportado y nunca se envian a analytics.

## Feed y detalle

El feed y el detalle publico se obtienen mediante funciones callable. Esto
permite aplicar visibilidad, caducidad, moderacion y bloqueos antes de devolver
datos. No se debe sustituir por una consulta global directa desde el cliente.

El feed solo incluye posts que el solicitante puede ver y excluye, como minimo:

- publicaciones privadas o fuera del alcance de su visibilidad;
- posts archivados o borrados;
- historias caducadas;
- contenido `under_review`, `hidden` o `removed` para terceros;
- autores bloqueados en cualquiera de las dos direcciones.

La paginacion debe usar el cursor opaco devuelto por el backend. El cliente no
debe reconstruirlo ni mezclar paginas de dos sesiones distintas.

## Funciones callable

Todas requieren Firebase Auth salvo las tareas internas del backend. Los IDs
del actor siempre proceden de `request.auth.uid`, nunca de un campo enviado por
el cliente.

| Funcion | Operacion |
| --- | --- |
| `getConquestFeed` | Devuelve una pagina filtrada del feed y su siguiente cursor |
| `getConquestStories` | Devuelve hasta 30 historias activas y visibles |
| `getConquestDetail` | Devuelve un post si el usuario puede verlo |
| `setConquestReaction` | Crea, cambia o elimina la reaccion idempotente del usuario; devuelve ambos contadores |
| `createConquestComment` | Valida y crea un comentario con ID idempotente; incrementa el contador |
| `deleteConquestComment` | Borra logicamente un comentario propio o de un post propio |
| `reportConquestPost` | Registra un reporte unico y ejecuta los umbrales de moderacion |
| `blockRunner` | Bloquea otro usuario mediante la relacion determinista del par |
| `unblockRunner` | Retira un bloqueo creado por el usuario autenticado |
| `moderateConquestPost` | Cambia el estado de moderacion con claim de moderador o admin |

Contratos consumidos por los repositorios Dart:

- `getConquestFeed({limit, cursor?})` devuelve `{items, nextCursor?, hasMore}`.
  El cursor actual usa `{createdAtSeconds, createdAtNanoseconds, id}` para no
  perder precision entre posts del mismo milisegundo; `nextCursor` conserva
  tambien `createdAtMs` solo como compatibilidad. El limite es 1-30.
- `getConquestStories({limit})` devuelve `{items}` con el mismo DTO del feed y
  limita `limit` al rango 1-30.
- `getConquestDetail({postId})` devuelve `{item}`.
- `setConquestReaction({postId, kind})` devuelve
  `{changed, reaction, likesCount, applauseCount}`; `kind: null` retira la
  reaccion.
- `createConquestComment({postId, commentId, text})` devuelve
  `{commentId, created}`. `text` se recorta y debe medir 1-500 caracteres.
- `deleteConquestComment({postId, commentId})` devuelve
  `{commentId, deleted}` y aplica borrado logico.
- `reportConquestPost({postId, reason, details?})` devuelve
  `{created, reportCount, moderationStatus}`. Los detalles se recortan, vacio
  equivale a `null` y el maximo es 500 caracteres.
- `blockRunner({otherUserId})` y `unblockRunner({otherUserId})` devuelven
  `{changed, blocked}` y mutan el par determinista.
- `moderateConquestPost({postId, status})` devuelve
  `{changed, moderationStatus}`.

Los payloads contienen solo el identificador del recurso y el dato necesario
para la accion: tipo de reaccion, texto del comentario, motivo cerrado, detalles
opcionales del reporte o estado de moderacion. Los reintentos de reaccion,
comentario con el mismo ID, reporte y bloqueo son idempotentes.

Los estados admitidos por `moderateConquestPost` son `ok`, `under_review`,
`hidden` y `removed`. El callable debe rechazar cualquier otro valor.

## Moderacion 3/5

Cada usuario solo aporta un reporte por post:

1. Con menos de 3 reportes unicos, el post conserva su estado actual.
2. Al alcanzar 3, pasa a `under_review` y deja de aparecer a terceros.
3. Al alcanzar 5, pasa a `hidden`.
4. Un moderador o admin puede resolverlo como `ok`, `hidden` o `removed`.

Los umbrales se aplican en una transaccion junto al reporte y su contador para
que dos envios concurrentes no pierdan incrementos. Reenviar el mismo reporte
no aumenta el contador.

La moderacion manual requiere un custom claim `moderator: true` o
`admin: true`. Tras asignarlo con Firebase Admin SDK, el usuario debe renovar
su ID token antes de llamar a `moderateConquestPost`.

## Bloqueos

El bloqueo reutiliza `connections/{pairId}` para mantener un unico documento
por pareja. `blockedByUsers` conserva la intencion independiente de cada
participante; `blockedBy` se mantiene para clientes antiguos. Cada usuario solo
puede retirar su propio bloqueo y la relacion sigue bloqueada mientras quede
otro actor en la lista. No se crea una solicitud de conexion al bloquear.

Mientras exista el bloqueo:

- ninguno de los dos aparece en el feed del otro;
- el detalle y nuevas interacciones se rechazan;
- las pantallas deben ocultar contenido ya cargado al recibir el nuevo estado;
- no se restaura automaticamente una conexion aceptada al desbloquear.

El filtrado visual no sustituye la comprobacion del callable. Un cliente
antiguo o modificado tampoco debe poder interactuar con un usuario bloqueado.

## Privacidad y analytics

La ubicacion se muestra exclusivamente con el `locationPrivacyMode` y los
snapshots permitidos por el autor. Nunca se reconstruye una ruta GPS a partir de
una publicacion.

`AnalyticsService` expone una API cerrada, sin mapas arbitrarios. Se emiten
estos eventos:

- `conquest_feed_view`
- `conquest_detail_view` (`own_post`: `0` o `1`)
- `conquest_reaction_toggle` (tipo permitido y estado activo)
- `conquest_comment_create`
- `conquest_report_submit` (motivo cerrado)
- `runner_block`
- `my_conquests_view`

No se envian IDs de post o usuario, captions, comentarios, nombres, URLs,
coordenadas ni texto libre. Los tests pueden sustituir el provider por
`NoopAnalyticsService`.

## Limite de Firebase Storage y download URLs

Las reglas de Firestore y los bloqueos controlan el descubrimiento del post,
pero no revocan una URL de descarga que ya se haya entregado. Las download URLs
de Firebase Storage contienen un token de acceso y pueden seguir funcionando si
alguien las guardo, aunque despues se oculte el documento.

Ademas, la regla actual de `conquest_media/{uid}/{fileName}` permite lectura a
cualquier usuario autenticado que conozca la ruta; no evalua la visibilidad ni
el bloqueo del post. La autorizacion fina de media requeriria servir URLs
efimeras desde backend o una capa de descarga que compruebe el post.

Consecuencias y medidas:

- no subir ubicacion precisa, EXIF ni secretos dentro de la imagen;
- mantener la sanitizacion de imagenes antes de subirlas;
- no registrar download URLs en analytics o logs;
- para retirada fuerte, borrar el objeto o rotar su token desde un entorno de
  confianza, ademas de marcar el post como `removed`;
- asumir que copias ya descargadas o caches de terceros no son revocables.

Por ello, `hidden` protege la distribucion dentro de Trazos, mientras que
`removed` debe activar tambien el procedimiento de retirada del archivo cuando
el caso lo requiera.

## Despliegue

Orden recomendado desde la raiz del proyecto:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
npm --prefix functions ci
node --check functions/index.js
firebase deploy --only "firestore:rules,firestore:indexes"
firebase deploy --only "functions:getConquestFeed,functions:getConquestStories,functions:getConquestDetail,functions:setConquestReaction,functions:createConquestComment,functions:deleteConquestComment,functions:reportConquestPost,functions:blockRunner,functions:unblockRunner,functions:moderateConquestPost"
```

Desplegar backend, reglas e indices antes que una version de la app que dependa
de ellos. Esperar a que los indices aparezcan como habilitados en Firebase
Console y realizar la matriz de `QA.md` contra el proyecto de staging antes de
promover a produccion.

Si cambian las reglas de Storage o el procedimiento de retirada:

```powershell
firebase deploy --only storage
```
