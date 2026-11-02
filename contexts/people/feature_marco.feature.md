# Contexto — Gestión de reseñas (rama original: feature_marco)

> Funcionalidad de Marco, trabajada por Cristian a mitad de semestre.
> Vuelve a Marco al final del semestre.

## Historial del traspaso

| Fecha | Quién | Qué pasó |
|---|---|---|
| 2026-09-08 a 09-12 | Marco (`marcojr282`) | Construye las vistas de propietario y administración de reseñas (PR #99). Juan José aporta etiquetas y ajustes en la lista del cliente. |
| 2026-09-16 | Cristian | Recibe la funcionalidad y audita el código (ver "Estado recibido"). |
| 2026-09-29 | Cristian (`cquiroz6211`) | Refactor sobre un modelo `Review` único (commit `7c1a28f`). |
| 2026-10-13 | Andrés Cardona | Guarda localmente el borrador de una reseña con `shared_preferences` (commit `ba846e8`). |
| 2026-11-02 | Cristian | Actualiza `feature_quiroz` con `develop` y crea este documento. |
| Fin de semestre | Marco | Recibe la funcionalidad de vuelta. |

## Rol de usuario que atiende esta funcionalidad

Cliente (escribe reseñas), Propietario (las lee y responde) y Administrador
del sistema (las modera).

## Estado recibido (auditoría del 2026-09-16)

Problemas encontrados al recibir el código de `feature_marco`:

1. **Modelo incompleto.** `Review` no tenía `id`, ni `authorId` (solo el
   nombre como texto), ni relación con motel o habitación.
2. **`ReviewType` sin uso.** El enum `motel | room` quedó desconectado; en su
   lugar se usaba un `String tag`.
3. **Tres islas de datos.** Cliente, propietario y administrador tenían cada
   uno su controlador con su propia lista falsa. Lo que hacía uno no lo veía
   el otro.
4. **Wrappers mutables.** `AdminReviewEntry` y `OwnerReviewEntry` existían
   solo para tapar los campos que le faltaban al modelo.
5. **Singletons.** Los controladores usaban `static final instance`.
6. **La reseña del cliente se perdía.** `AddReviewSheet` fijaba el autor como
   `'Tú'` y guardaba en un controlador que se destruía al salir.
7. **Fontanería manual en vistas.** `didChangeDependencies` +
   `addListener`/`removeListener` + `setState` en lugar de `ListenableBuilder`.

## Qué se cambió (refactor del 2026-09-29, commit `7c1a28f`)

- `Review` es ahora la única representación del dominio: `id`, `authorId`,
  `authorName`, `motelId`, `roomId` (opcional), `type` (`ReviewType`),
  `rating` (1-5), `status` (`ReviewModerationStatus`), `reportReason`,
  `adminReply` y `ownerReply`. Es inmutable y se actualiza con `copyWith`.
- Se eliminaron `AdminReviewEntry` y `OwnerReviewEntry`.
- Los datos falsos viven en un solo lugar: `ReviewData.all()`.
- Se eliminaron los singletons. Los controladores se inyectan por parámetro;
  si la vista no recibe uno, crea el suyo en `initState`.
- Las vistas de propietario, administración y cliente usan `ListenableBuilder`.
- `AddReviewSheet` arma un `Review` completo y lo entrega por el callback
  `onSave(Review)`, en vez de escribir directo en un controlador.

Después, Andrés agregó el borrador local de la reseña (commit `ba846e8`):
`ReviewsController.loadDraft`, `saveDraft` y `clearDraft` con la clave
`addReviewDraft` en `shared_preferences`.

## Deuda pendiente (estado al 2026-11-02)

Verificado contra el código de `develop` (`33743ec`):

1. **Las islas siguen en la práctica.** `ReviewData.all()` devuelve una
   lista **nueva** en cada llamada. Cada controlador copia esa lista y la
   modifica por su cuenta. Si el propietario responde, el administrador no ve
   la respuesta. Falta un repositorio compartido.
2. **No hay persistencia.** Todo vive en memoria; se pierde al cerrar la app.
3. **El autor sigue fijo.** `add_review_sheet.dart:126-127` usa
   `authorId: 'user-current'` y `authorName: 'Tú'`. Debe venir del usuario
   autenticado (Firebase Auth, ver `lib/service/firebase/current_user.dart`).
4. **`ReviewType` duplicado.** Existe en `lib/models/review/review.dart` (el
   que se usa) y en `lib/models/review/review_type.dart` (nadie lo importa).
   Borrar el segundo.
5. **Sin pruebas.** No hay ningún archivo de prueba del módulo de reseñas.
6. **Tokens de diseño.** `admin_review_card.dart:299` y
   `owner_review_card.dart:188` usan `Colors.white` y `FontWeight.w700`
   directo en lugar de tokens del design system.
7. **Navegación inconsistente.** El propietario entra con la ruta con nombre
   `AppRoutes.ownerReviews` (`owner_motels_page.dart:255`). El administrador
   entra con `MaterialPageRoute` directo (`admin_motels_page.dart:254`),
   aunque existe `AppRoutes.adminReviews`.

## Feature: Escribir una reseña (Cliente)

  Scenario: Cliente abre el formulario desde una reserva completada
    Given un cliente con una reserva habilitada para reseñar
    When abre el detalle de la reserva o el detalle del motel
    Then ve la sección de reseñas (`ReviewsSection`) del motel
    And puede abrir el formulario "Añadir reseña"

  Scenario: Cliente guarda una reseña válida
    Given un cliente en el formulario "Añadir reseña"
    When elige qué reseñar ("Motel" o "Habitación"), selecciona una calificación de 1 a 5, escribe "Título" y "Tu reseña", y presiona "Guardar"
    Then la reseña se agrega a la lista del motel
    And si eligió "Habitación", la reseña queda asociada a la habitación seleccionada
    And el borrador local se borra

  Scenario: Cliente intenta guardar con campos incompletos
    Given un cliente en el formulario "Añadir reseña"
    When presiona "Guardar" sin calificación o sin título o sin texto
    Then ve "Selecciona una calificación" si falta la calificación
    And ve "Campo requerido" bajo cada campo de texto vacío
    And la reseña no se guarda

  Scenario: Cliente sale sin guardar y vuelve después
    Given un cliente que escribió parte de una reseña
    When cierra el formulario y lo vuelve a abrir para el mismo motel
    Then recupera el borrador guardado localmente

## Feature: Leer y responder reseñas (Propietario)

  Scenario: Propietario consulta las reseñas de sus moteles
    Given un propietario autenticado
    When entra a "Reseñas" desde el menú de sus moteles
    Then ve solo las reseñas de sus moteles
    And puede filtrar por motel y buscar por texto

  Scenario: Propietario responde una reseña
    Given un propietario viendo una reseña
    When presiona "Responder", escribe un mensaje y confirma
    Then la reseña muestra "Tu respuesta" con el mensaje
    And el botón cambia a "Editar respuesta"

  Scenario: Propietario envía una respuesta vacía
    Given un propietario con el formulario de respuesta abierto
    When confirma un mensaje vacío o solo con espacios
    Then la respuesta no se guarda

## Feature: Moderar reseñas (Administrador del sistema)

  Scenario: Administrador filtra reseñas por estado
    Given un administrador en el panel de reseñas
    When elige un filtro ("Todas", "Visibles", "Ocultas" o "Reportadas") o busca por texto
    Then la lista muestra solo las reseñas que cumplen el filtro

  Scenario: Administrador oculta o muestra una reseña
    Given un administrador viendo una reseña
    When elige "Ocultar" (o "Mostrar" si ya está oculta)
    Then el estado de la reseña cambia entre "Visible" y "Oculta"

  Scenario: Administrador atiende una reseña reportada
    Given una reseña con estado "Reportada" y un "Motivo del reporte"
    When el administrador elige "Descartar reporte"
    Then la reseña vuelve a estado "Visible"

  Scenario: Administrador responde o elimina una reseña
    Given un administrador viendo una reseña
    When elige "Responder" y confirma un mensaje
    Then la reseña muestra "Respuesta del administrador"
    When elige "Eliminar"
    Then la reseña desaparece de la lista

## Alcance técnico

- **Carpetas donde se trabaja**:
  - Modelo: `lib/models/review/` (`review.dart`, `review_data.dart`).
  - Controladores: `lib/controllers/review/`
    - `add_review_controller.dart` → `ReviewsController` (cliente + borrador).
    - `owner_review_controller.dart` → `OwnerReviewController`.
    - `review_administration_controller.dart` → `ReviewAdministrationController` y `ReviewFilter`.
  - Vistas: `lib/views/review/` (`add_review_page.dart` con `ReviewsSection`,
    `owner_view/owner_review_page.dart`, `review_administration_page.dart`).
  - Widgets: `lib/widgets/review/` (tarjetas, hojas de respuesta, selector de
    estrellas, `add_review_sheet.dart`).
  - Rutas: `AppRoutes.ownerReviews = '/reviews/owner'` y
    `AppRoutes.adminReviews = '/reviews/admin'` en `lib/routes/routes.dart`.
- **Depende de**:
  - Moteles y habitaciones (`motelId`, `roomId`) — módulo de moteles.
  - Reservas del cliente: `reservation_detail_page.dart` decide cuándo se
    puede reseñar.
  - Autenticación (Firebase Auth) para el autor real de la reseña.
  - `LocalPreferencesService` para el borrador.
- **De quién depende trabajo de esta funcionalidad** (avisar si cambia la
  API pública de `ReviewsSection` o de las rutas):
  - `lib/views/motel/client_view/client_motel_detail_page.dart`
  - `lib/views/booking/client_view/reservation_detail_page.dart`
  - `lib/views/motel/owner_view/owner_motels_page.dart`
  - `lib/views/motel/system_admin_view/admin_motels_page.dart`
- **Fuera de alcance**:
  - Cambiar la lógica de reservas o de moteles.
  - Notificaciones al propietario cuando llega una reseña.
- **Decisiones ya tomadas**:
  - Un solo modelo `Review` inmutable; nada de wrappers por rol.
  - Controladores inyectables, sin singletons.
  - Borrador local con `shared_preferences`.
- **Decisión pendiente (validar con el equipo y registrar en
  `docs/decisions_log.md`)**:
  - Dónde se guardan las reseñas. Propuesta: **Supabase + caché en Floor**,
    el mismo patrón que moteles (`docs/motels_persistence.md`), porque la
    reseña cuelga de un motel o habitación que ya vive en Supabase.

## Registro de implementación (rama `feature_quiroz`)

Anota aquí cada entrega con fecha, commit y qué punto de la "Deuda pendiente"
resuelve.

| Fecha | Commit | Qué se hizo | Deuda resuelta |
|---|---|---|---|
| 2026-11-02 | — | Creación de este documento de traspaso. | — |
| 2026-11-02 | `549096c` | Pruebas de los 3 controladores; "Descartar reporte" ahora borra el motivo. | — (bug nuevo) |
| 2026-11-02 | `cb211df` | `ReviewRepository` compartido (`lib/repositories/review/`); los datos de ejemplo salen de `models/`. | 1, 5 (parcial) |
| 2026-11-02 | `f09611f` | `ReviewRules`, `averageRatingOf` y `submitReview`: el formulario ya no crea la reseña. | 3 (parcial: autor en un solo lugar) |
| 2026-11-02 | `014ef47` | Token `AppColors.rating`, `dispose` en páginas, se borra `review_type.dart`. | 4, 6 |
| 2026-11-02 | `483d164` | Autor real: `ReviewAuthorProvider` (`lib/service/review/`) toma `uid` de Firebase Auth y nombre del perfil en Firestore; sin sesión no se guarda. | 3 |
| 2026-11-02 | (ver git log) | El repositorio pasa a `lib/database/repository/review/`, donde el equipo guarda los repositorios (guía de Firebase, punto 10). | — |
