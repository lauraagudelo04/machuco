# Módulo: Reservas (`booking`)

Estado general: **funcional con persistencia local**. Los flujos de
creación, consulta, cancelación y pago en efectivo están implementados sobre
una capa de servicio y un repositorio con SQLite (Floor) y sincronización
Firestore, sin pasarela de pagos real. La organización de archivos y el contexto funcional
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

### Integración «En el Local» con Payment

El contrato específico está en [../payment_persistence.md](../payment_persistence.md).
La elección conserva `pending` y usa `paymentMethod = 'En el Local'` como
lugar, no como método recibido. Por decisión del usuario no vence en 15 minutos
ni por inasistencia: requiere cancelación explícita. Un checkout sin esa
elección sí vence. Payment confirma la recepción y actualiza la reserva de
forma atómica; el acceso de cobro local de Booking lleva a Finanzas para elegir
el método real. El sandbox de tarjeta no acredita dinero ni confirma reservas.
No se agregan estados, tablas ni una pasarela.

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

El catálogo `reservation_categories` es un dato maestro en Supabase
(`supabase/migrations/202611070001_create_reservation_categories.sql`, solo
lectura pública). `FloorReservationCategoryRepository` lo lee por REST
(`SupabaseReservationCategorySource`) la primera vez que se usa y actualiza la
caché SQLite; sin conexión, o si la tabla remota está vacía, usa la caché y,
si también está vacía, siembra `defaultReservationCategories`. El cliente debe
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

- Sin sesión de Firebase las reservas se persisten solo en el dispositivo
  (modo demo). Con sesión se sincronizan con Firestore (ver "Sincronización
  con Firestore"); un cambio hecho sin conexión puede quedar sobrescrito por
  la copia remota en la siguiente lectura (no hay cola de reintentos).
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

- Tablas (base común `machuco.db` de `AppDatabaseProvider`, versión 13):
  - `reservation_categories`: caché local del maestro de categorías de
    Supabase.
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
- Migración 12 -> 13 (`migration12To13` en `app_database.dart`): crea las
  tres tablas e índices de reservas en bases que ya tenían la versión 12 de
  `develop`. Debe mantenerse igual al SQL generado en `app_database.g.dart`.

## Sincronización con Firestore

`BookingRepositoryProvider.useDatabase()` envuelve el repositorio local en
`SyncedBookingRepository` (`lib/repositories/booking/`):

- **Sin sesión** (`CurrentUser.uidOrNull == null`): se comporta igual que el
  repositorio local, con la semilla de demostración y sin llamar a Firebase.
- **Con sesión**: `getAll` descarga primero lo que el rol puede leer (cliente:
  `listForGuest(uid)`, propietario: `listForOwner(uid)`, admin: `listAll()`),
  lo guarda en SQLite (la copia remota gana) y oculta la semilla
  (`isSeedReservationId`). Sin conexión devuelve la caché.
- `add` y `update` guardan en local y suben en segundo plano
  (`ReservationCloudRepository.saveReservation`). No se suben la semilla ni las
  reservas de moteles que no están en el catálogo de Supabase (sin propietario
  conocido). Un error al subir conserva la copia local.
- Documento `reservations/{id}` (`ReservationFirestoreDocument`): los campos de
  `Reservation` más `ownerId`, el propietario del motel (`motels.owner_id` de
  Supabase), que usan las reglas para autorizar al propietario.
- Reglas (`firestore.rules`, `match /reservations/{reservationId}`): leen el
  cliente (`guestId`), el propietario (`ownerId`) y el admin; solo el cliente
  crea, a su nombre; las actualizaciones solo cambian estado, motivo de
  cancelación, acceso a factura y método de pago, con las transiciones de
  `BookingService`; nadie borra.
- Identidad: los controladores de cliente y propietario usan el uid de Firebase
  (`CurrentUser.uidOrNull`) y solo sin sesión los ids de demostración. Para que
  un propietario vea reservas, `motels.owner_id` debe ser su uid: los moteles
  nuevos ya se crean así desde `OwnerMotelsPage`.
