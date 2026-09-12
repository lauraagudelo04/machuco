# Contexto - Funcionalidad de PQRS (rama: feature_daniel)

## Rol del usuario

Cliente, Propietario y Administrador del sistema.

Esta rama es dueña del **módulo de PQRS** (peticiones, quejas, reclamos y sugerencias): el Cliente abre solicitudes sobre un motel y hace seguimiento de las suyas, el Propietario responde y resuelve las de su motel, y el Administrador del sistema supervisa las de toda la plataforma filtrando por motel. Los tres roles operan sobre el mismo conjunto de solicitudes, con una vista por rol y una trazabilidad compartida.

> Aclaración de arquitectura: los datos viven en `PqrsStore` y las reglas de ciclo de vida en `PqrsController`, que es un `ChangeNotifier`. Las vistas se sincronizan con `ListenableBuilder` — Flutter puro, sin gestor de estado externo, porque el proyecto todavía no ha decidido cuál usar.

## Feature: Registro y seguimiento de solicitudes (Cliente)

Scenario: Cliente abre una solicitud
  Given un cliente en la vista de PQRS de un motel
  When elige el tipo de solicitud, escribe asunto y descripción, adjunta fotos opcionales y confirma
  Then la solicitud queda registrada en estado "pending", asociada al id real del motel y del cliente
  And aparece primera en su listado, con el nombre del motel resuelto desde `MotelController` y el del cliente desde `ClientController`

Scenario: El comentario del cliente no mueve el estado
  Given una solicitud propia en estado "pending" o "inProgress"
  When el cliente agrega un comentario con fotos opcionales
  Then el comentario queda registrado en la trazabilidad con su autor y su fecha
  And el estado de la solicitud no cambia

Scenario: Solo el cliente cierra una solicitud solucionada
  Given una solicitud que el propietario marcó como "resolved"
  When el cliente confirma la solución
  Then la solicitud pasa a "closed" y deja de admitir actualizaciones

Scenario: Intento de cierre sobre una solicitud no solucionada
  Given una solicitud en estado "pending" o "inProgress"
  When se intenta cerrarla desde la vista del cliente
  Then la operación se rechaza indicando el estado actual
  And la solicitud queda intacta, sin entradas nuevas en la trazabilidad

## Feature: Atención de solicitudes del motel (Propietario)

Scenario: La primera respuesta del propietario activa la solicitud
  Given una solicitud de su motel en estado "pending"
  When el propietario agrega un comentario
  Then la solicitud pasa a "inProgress"
  And el cambio de estado queda registrado en la trazabilidad junto al comentario

Scenario: Propietario propone una solución
  Given una solicitud en estado "pending" o "inProgress"
  When el propietario la marca como solucionada describiendo la solución
  Then la solicitud pasa a "resolved" y queda a la espera de que el cliente la cierre
  And si ya estaba en "resolved" la operación se rechaza

Scenario: Propietario rechaza una solicitud
  Given una solicitud que no procede
  When el propietario la rechaza indicando el motivo
  Then la solicitud pasa a "rejected", que es un estado final
  And el motivo queda visible en la trazabilidad

Scenario: Una solicitud en estado final no admite cambios
  Given una solicitud en estado "closed" o "rejected"
  When cualquier actor intenta comentar, resolver o rechazar
  Then la operación se rechaza indicando el estado
  And la solicitud queda intacta

## Feature: Supervisión de solicitudes de la plataforma (Administrador)

Scenario: Administrador filtra las solicitudes por motel
  Given el administrador en la vista de PQRS del sistema
  When selecciona un motel del selector
  Then ve únicamente las solicitudes de ese motel
  And el selector lista solo los moteles que tienen solicitudes, resueltos como modelo `Motel` real vía `MotelController`

Scenario: Visualización ante ausencia de solicitudes
  Given un estado de datos sin solicitudes registradas
  When el administrador accede a la vista
  Then se muestra un estado vacío descriptivo sin romper el layout

Scenario: Consulta de indicadores agregados
  Given el propietario o el administrador en su vista de PQRS
  When examina el panel de estadísticas
  Then visualiza el total de solicitudes, su distribución por estado y la tasa de resolución

## Alcance técnico

- **Carpetas donde trabajo**: `lib/models/pqrs/`, `lib/controllers/pqrs/`, `lib/views/pqrs/` (`client_view/`, `owner_view/`, `system_admin_view/`), `lib/widgets/pqrs/`
- **Depende de**:
  - `MotelController` y el modelo `Motel` — moteles y sus ids canónicos
  - `ClientController` y el modelo `Client` — clientes y sus nombres
  - Se consumen tal como están; **no se modifican desde esta rama**
- **De quién depende trabajo mío**: por ahora nadie consume `PqrsRequest` fuera de este módulo
- **Fuera de alcance de esta rama**:
  - La capa de sesión / usuario autenticado — pertenece al módulo de login y está pendiente de una decisión de equipo
  - El backend y la persistencia real
  - Reservas, pagos, reseñas y notificaciones
- **Decisiones ya tomadas específicas de esta funcionalidad**:
  - El tipo se maneja con el enum `PqrsType` (`peticion`, `queja`, `reclamo`, `sugerencia`), nunca con strings sueltos
  - El estado se maneja con el enum `PqrsStatus` (`pending`, `inProgress`, `resolved`, `closed`, `rejected`); `closed` y `rejected` son finales (`isFinal`)
  - El autor de cada entrada de trazabilidad se maneja con el enum `PqrsActor` (`client`, `owner`, `systemAdmin`)
  - El modelo es Dart puro: las etiquetas, iconos y colores de los enums viven en `lib/widgets/pqrs/pqrs_presentation.dart`, no en el modelo
  - Rutas registradas: `/pqrs`, `/pqrs/client`, `/pqrs/owner`, `/pqrs/admin`

## Notas para el agente

- `PqrsStore` y `PqrsController` exponen una instancia compartida (`.instance`) porque todavía no hay inyección de dependencias. **No introducir un gestor de estado externo** ni agregar dependencias al `pubspec.yaml` para resolverlo.
- Las constantes `pqrsCurrentClientId` y `pqrsCurrentMotelId` son un sustituto temporal de la sesión. Apuntan a ids reales de `ClientController` y `MotelController`, pero **no son una capa de sesión**: desaparecen cuando el equipo decida cómo se propaga el usuario autenticado. No construir esa capa desde esta rama.
- El módulo consume los ids canónicos de motel (`'1'`, `'2'`, `'3'`). No volver a inventar ids propios: antes existían `'m-aurora'` y `'m-eclipse'`, que no correspondían a ningún motel real y provocaron que Motel Eclipse tuviera dos identidades en la app.
- `PqrsRequest.motelName` es un valor desnormalizado de respaldo para mostrar. El nombre autoritativo se resuelve con `PqrsController.loadMotelsWithRequests()`, que va contra `MotelController`.
- Después de cualquier `await` en una vista, comprobar `mounted` antes de usar el `context` (ver `lib/views/pqrs/client_view/pqrs_page.dart`).
- **Regla estricta**: no modificar archivos ajenos desde esta rama. Para verificar el módulo de forma aislada:
  ```bash
  flutter analyze lib/models/pqrs lib/controllers/pqrs lib/views/pqrs lib/widgets/pqrs
  ```
- `lib/views/pqrs/PqrsPage.dart` es un archivo heredado con nombre en `UpperCamelCase` que incumple la convención del proyecto y aparece como `info` en `flutter analyze`. Renombrarlo exige coordinar con `lib/routes/routes.dart` y con quien lo referencie.

### Intención visual

- **Listados por rol** (`client_view/`, `owner_view/`, `system_admin_view/`): lista de `PqrsRequestCard`, la tarjeta resumen compartida por los tres perfiles, con `PqrsStatusBadge` (píldora de estado) y chips de metadatos. El administrador suma un selector de motel encabezando la lista.
- **Panel de estadísticas** (`PqrsStatsPanel`, propietario y administrador): anillo de tasa de resolución dibujado con `CustomPainter`, filas de métricas y barras de distribución por estado.
- **Detalle de solicitud** (`*_detail_page.dart`): `PqrsTimeline` como trazabilidad cronológica — quién escribió, cuándo y con qué fotos — con chips que marcan los cambios de estado, y `PqrsUpdateComposer` al pie para que cliente y propietario agreguen entradas.
- **Fotos**: `PqrsPhotoTile` y `PqrsPhotoStrip` muestran adjuntos simulados; no hay almacenamiento real de imágenes en el proyecto todavía.

### Nota sobre la construcción de la Interfaz (UI):
Los widgets del módulo viven en `lib/widgets/pqrs/` y se reutilizan entre los tres perfiles — evitar duplicar una tarjeta o una píldora por rol. Las etiquetas, iconos y colores de los enums se resuelven en `pqrs_presentation.dart` para que el modelo siga siendo Dart puro. Nunca hardcodear hexadecimales, radios ni duraciones en una vista: usar los tokens del design system.
