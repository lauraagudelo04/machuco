# Módulo: Reservas (`booking`)

Estado general: **funcional con persistencia local**. Los flujos de
creación, consulta, cancelación y pago en efectivo están implementados sobre
una capa de servicio y un repositorio con SQLite (Floor), sin backend ni
pasarela de pagos real. La organización de archivos y el contexto funcional
detallado de este módulo ya están documentados en:

- [`docs/booking_structure.md`](../booking_structure.md) — convención de
  carpetas por rol (`client_view`, `owner_view`, `system_admin_view`) y
  regla de integración de rutas. **Desactualizado** en el árbol de archivos
  exacto (ver `docs/booking_handoff.md#6-enlaces`).
- [`docs/booking_context.md`](../booking_context.md) — flujo funcional
  completo por rol (cliente, propietario, administrador), incluidos los
  estados de una reserva. **Desactualizado** en el flujo de "Pagar en
  efectivo" y de cancelación del propietario (ver
  `docs/booking_handoff.md#6-enlaces`).
- [`docs/booking_handoff.md`](../booking_handoff.md) — guía corta de
  transferencia del módulo: estado real por rol, bugs conocidos con
  archivo:línea y reglas de dominio no negociables. Es la referencia
  vigente si hay conflicto con los dos documentos anteriores.

Este archivo no repite ese contenido; describe el estado real de la
implementación.

## Capas

```
views -> controllers -> BookingService -> BookingRepository -> Floor DAO
```

- **Views** (`lib/views/booking/**`): solo presentación; no consultan datos
  ni calculan reglas.
- **Controllers** (`lib/controllers/booking/**`): estado de pantalla (carga,
  error, caché) y delegación en el servicio.
- **`BookingService`** (`lib/service/booking/booking_service.dart`): reglas de
  negocio (disponibilidad, precios, transiciones de estado, cancelación,
  filtros, ordenamiento y KPIs). No guarda estado propio y recibe el
  repositorio y el reloj por inyección.
- **`BookingRepository`** (`lib/repositories/booking/booking_repository.dart`):
  interfaz de acceso a datos con tres implementaciones:
  `InMemoryBookingRepository` (pruebas), `FloorBookingRepository` (SQLite) y
  `LazyBookingRepository` (resuelve la base al primer uso).
  `BookingRepositoryProvider` expone la instancia compartida por los tres
  roles.
- **Floor DAO** (`ReservationDao`, `ReservationCategoryDao`) sobre
  `AppDatabase`.

## Modelos

- `lib/models/booking/booking.dart`: entidad `Reservation` compartida por
  los tres roles (cliente, propietario, administrador), con estados
  `pending`, `upcoming`, `active`, `completed`, `cancelled` (ver glosario en
  `docs/booking_context.md`).

## Controllers (`ChangeNotifier`, por rol)

- `controllers/booking/client_view/client_booking_controller.dart`
  (`ClientBookingController`): selección de categoría, creación idempotente
  por `requestId`, resumen previo al pago y cancelación con motivo
  obligatorio. Las reglas (franjas, 1 hora de preparación, expiración a los
  15 minutos) viven en `BookingService`.
- `controllers/booking/owner_view/owner_booking_controller.dart`
  (`OwnerBookingController`): reservas generales del propietario, filtros
  por motel, habitación, cliente, estado y categoría, y flujo de cancelación
  con notificación simulada al cliente.
- `controllers/booking/system_admin_view/system_admin_booking_controller.dart`
  (`SystemAdminBookingController`): estadísticas y dashboard por motel para
  el administrador del sistema, con filtro por estado y categoría.

Los tres controladores exponen un estado de error recuperable: si el
repositorio o el servicio lanzan una excepción, `errorMessage` queda
definido y la vista muestra el estado de error con reintento (nunca un
listado vacío). Los parámetros `simulateError` y `simulateOffline` se
conservan solo como ganchos de demostración.

## Pantallas

- Cliente: `client_booking_home_page.dart`, `create_booking_page.dart`,
  `booking_checkout_page.dart`, `reservation_detail_page.dart`,
  `client_reservations_page.dart`.
- Propietario: `owner_booking_home_page.dart`, `owner_reservations_page.dart`,
  `owner_reservation_detail_page.dart`, `owner_cash_payment_page.dart`.
- Administrador: `system_admin_booking_home_page.dart`,
  `admin_motel_reservations_list_page.dart`,
  `admin_motel_reservation_dashboard_page.dart`.

Las vistas siguen el patrón descrito en
[../architecture.md](../architecture.md#views): instancian su controlador
en `initState`, se suscriben con `addListener` y llaman `setState`
manualmente.

## Rutas

Todas las rutas de reservas están centralizadas en `lib/routes/routes.dart`
(`AppRoutes.clientReservations`, `AppRoutes.ownerReservations`,
`AppRoutes.adminMotelReservationsList`, etc.), como exige
`docs/booking_structure.md`.

## Pruebas

Pruebas automatizadas del módulo:

- `test/service/booking/booking_service_test.dart`
- `test/repositories/booking/` (repositorio en memoria y Floor)
- `test/controllers/booking/client_view/client_booking_controller_test.dart`
- `test/controllers/booking/owner_view/owner_booking_controller_test.dart`
- `test/controllers/booking/system_admin_view/system_admin_booking_controller_test.dart`
- `test/widgets/booking/*_test.dart` (cancelación, dashboards, detalle,
  listados, resumen de pago con desglose de costos)

Los controladores de propietario y administrador incluyen pruebas con un
repositorio que siempre falla, para verificar el estado de error.

## Transiciones por reloj

`BookingService` recibe un reloj inyectable (`DateTime Function() now`), de
modo que las transiciones se prueban de forma determinista:

- `pending` sin pago pasa a `cancelled` a los 15 minutos y libera la franja.
- `upcoming` pasa a `active` al llegar la hora de entrada y a `completed` al
  cumplirse la salida.
- `syncStatuses` persiste esas transiciones al consultar; `resolveStatuses`
  es la versión pura que usan los getters síncronos de los controladores.

## Categorías y filtros

El catálogo `reservation_categories` se carga desde SQLite. El cliente debe
elegir una categoría antes de reservar y la reserva guarda su `categoryId`
(nulo en reservas anteriores al catálogo). Propietario y administrador
filtran por categoría; si el catálogo no carga, el filtro se omite sin
bloquear la pantalla.

## Cobertura de escenarios de la spec

Cubiertos: asignación aleatoria entre habitaciones activas libres del tipo y
rechazo sin unidades activas; conflicto de concurrencia con mensaje;
reintento idempotente tras error de red; validación de fecha y hora
obligatorias; desglose de costos en el resumen; estado vacío y error con
reintento en "Mis reservas"; filtro por cliente del propietario (reutiliza
`reservationsForClient`); estados de error recuperable en propietario y
administrador.

## Qué falta o es provisional

- No hay backend: las reservas se persisten solo en el dispositivo (ver
  "Persistencia local").
- El pago real de una reserva (`confirmPayment`) se dispara desde el pago con
  tarjeta; el procesamiento con pasarela real está fuera del alcance.
- La disponibilidad de habitaciones se calcula combinando este módulo con
  datos mock de otro (`RoomVisualData`, ver `widgets/room` y
  `controllers/room/room_mock_data.dart`); no hay una única fuente de verdad.
- La nota final de `docs/booking_context.md` ("Nota para el LLM (Claude)")
  sobre métricas adicionales del dashboard de administrador sigue sin
  resolver: es una petición abierta, no una implementación confirmada.

## Persistencia local de reservas (Floor)

`BookingRepositoryProvider.useDatabase()` (llamado en `main.dart`) cambia el
repositorio por defecto a `LazyBookingRepository` -> `FloorBookingRepository`.
El modelo de dominio `Reservation` no tiene anotaciones de Floor.

- Tablas (base `machuco.db`, version 2):
  - `reservation_categories`: catálogo de categorías (desde la versión 1).
  - `reservations`: una fila por reserva (`ReservationEntity`). Fechas como
    epoch en milisegundos, enums como su `name`. Indices en `requestId` y
    `motelId`.
  - `reservation_line_items`: servicios y productos (`kind` =
    `service`|`product`, `position` conserva el orden). `reservationId` es FK
    a `reservations.id` con `ON DELETE CASCADE`.
- `ReservationMapper` (`lib/repositories/booking/reservation_mapper.dart`)
  convierte filas <-> `Reservation`; `ReservationDao` inserta/actualiza la
  reserva y reemplaza sus lineas dentro de una `@transaction`.
- Siembra: si `reservations` esta vacia, el repositorio inserta una vez la
  semilla de `booking_seed_data.dart`.
- Migracion v1 -> v2 (`AppDatabase.migration1to2`): crea ambas tablas e
  indices para instalaciones que ya tenian la v1 (solo
  `reservation_categories`). Debe mantenerse igual al SQL generado en
  `app_database.g.dart`.
