# Contexto — Daniel Puerta (rama: feature_daniel)

## Rol de usuario que atiende esta funcionalidad

Cliente | Propietario | Administrador del sistema

El módulo PQRS tiene una vista por cada uno de los tres roles, sobre el
mismo conjunto de solicitudes.

Feature: PQRS (peticiones, quejas, reclamos y sugerencias)

  Scenario: El cliente abre una solicitud
    Given un cliente está en la vista de PQRS de un motel
    When elige el tipo de solicitud, escribe asunto y descripción,
      adjunta fotos opcionales y confirma
    Then la solicitud queda registrada en estado "pending", asociada al
      id real del motel y del cliente, y aparece primera en su listado

  Scenario: El propietario responde por primera vez
    Given una solicitud en estado "pending"
    When el propietario agrega un comentario
    Then la solicitud pasa a "inProgress" y el cambio de estado queda
      registrado en la trazabilidad junto al comentario

  Scenario: El comentario del cliente no mueve el estado
    Given una solicitud en estado "pending" o "inProgress"
    When el cliente agrega un comentario
    Then el comentario se registra en la trazabilidad pero el estado no
      cambia

  Scenario: Solo el cliente cierra una solicitud solucionada
    Given el propietario marcó la solicitud como "resolved"
    When el cliente confirma la solución
    Then la solicitud pasa a "closed" y deja de admitir actualizaciones

  Scenario: No se puede cerrar una solicitud que no está solucionada
    Given una solicitud en estado "pending" o "inProgress"
    When se intenta cerrarla desde la vista del cliente
    Then la operación se rechaza indicando el estado actual, sin
      modificar la solicitud

  Scenario: Una solicitud en estado final no admite cambios
    Given una solicitud en estado "closed" o "rejected"
    When cualquier actor intenta comentar, resolver o rechazar
    Then la operación se rechaza y la solicitud queda intacta

  Scenario: El administrador filtra por motel
    Given el administrador está en la vista de PQRS del sistema
    When selecciona un motel del selector
    Then ve únicamente las solicitudes de ese motel, y el selector lista
      solo los moteles que tienen solicitudes

## Alcance técnico

- **Carpetas donde trabajo**: `lib/models/pqrs/`, `lib/controllers/pqrs/`,
  `lib/views/pqrs/` (`client_view/`, `owner_view/`, `system_admin_view/`),
  `lib/widgets/pqrs/`
- **Depende de**:
  - `MotelController` / modelo `Motel` (moteles y sus ids canónicos)
  - `ClientController` / modelo `Client` (clientes y sus nombres)
  - No se modifican: se consumen tal como están
- **De quién depende trabajo mío**: nadie consume `PqrsRequest` fuera de
  este módulo por ahora
- **Fuera de alcance de esta rama**:
  - La capa de sesión / usuario autenticado (es del módulo de login, de
    Juan Gallego, y está pendiente de una decisión de equipo)
  - El backend y la persistencia real
  - Reservas, pagos y notificaciones
- **Decisiones ya tomadas específicas de esta funcionalidad**:
  - El tipo se maneja con el enum `PqrsType`
    (`peticion`, `queja`, `reclamo`, `sugerencia`), no con strings
  - El estado se maneja con el enum `PqrsStatus`
    (`pending`, `inProgress`, `resolved`, `closed`, `rejected`);
    `closed` y `rejected` son finales
  - El autor de cada entrada de trazabilidad se maneja con el enum
    `PqrsActor` (`client`, `owner`, `systemAdmin`)
  - Los datos viven en `PqrsStore`; las reglas de ciclo de vida y las
    notificaciones viven en `PqrsController`, que es un `ChangeNotifier`
  - Las vistas se sincronizan con `ListenableBuilder` — Flutter puro, sin
    gestor de estado externo

## Notas para los agentes

- `PqrsStore` y `PqrsController` exponen una instancia compartida
  (`.instance`) porque todavía no hay inyección de dependencias. No
  introducir un gestor de estado externo para resolverlo.
- Las constantes `pqrsCurrentClientId` y `pqrsCurrentMotelId` son un
  sustituto temporal de la sesión. Apuntan a ids reales
  (`ClientController` y `MotelController`), pero **no** son una capa de
  sesión: desaparecen cuando el equipo decida cómo se propaga el usuario
  autenticado. No construir esa capa desde esta rama.
- El módulo consume los ids canónicos de motel (`'1'`, `'2'`, `'3'`). No
  volver a inventar ids propios: antes existían `'m-aurora'` y
  `'m-eclipse'`, que no correspondían a ningún motel real.
- `PqrsRequest.motelName` es un valor desnormalizado de respaldo para
  mostrar. El nombre autoritativo se resuelve con
  `PqrsController.loadMotelsWithRequests()`, que va contra
  `MotelController`.
- `lib/views/pqrs/PqrsPage.dart` es un archivo heredado con nombre en
  `UpperCamelCase` que incumple la convención del proyecto. Renombrarlo
  requiere coordinar con quien lo referencie.
