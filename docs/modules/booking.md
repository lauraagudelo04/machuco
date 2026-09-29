# Módulo: Reservas (`booking`)

Estado general: **parcial, con datos mock**. Los flujos de creación,
consulta, cancelación y pago en efectivo están implementados en memoria,
sin backend ni pasarela de pagos real. La organización de archivos y el
contexto funcional detallado de este módulo ya están documentados en:

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

## Modelos

- `lib/models/booking/booking.dart`: entidad `Reservation` compartida por
  los tres roles (cliente, propietario, administrador), con estados
  `pending`, `upcoming`, `active`, `completed`, `cancelled` (ver glosario en
  `docs/booking_context.md`).

## Controllers (`ChangeNotifier`, por rol)

- `controllers/booking/client_view/client_booking_controller.dart`
  (`ClientBookingController`): **estado: mock funcional.** Maneja
  disponibilidad de franjas horarias (incluye 1 hora de preparación tras
  cada reserva), creación idempotente por `requestId`, expiración
  automática de reservas `pending` sin pago tras 15 minutos, y cancelación
  con motivo obligatorio. Los datos viven en una colección `static` en
  memoria compartida entre instancias del controlador (ver
  [../decisions_log.md](../decisions_log.md)); no hay persistencia real ni
  llamada a backend.
- `controllers/booking/owner_view/owner_booking_controller.dart`
  (`OwnerBookingController`): reservas generales del propietario, filtros
  por motel/estado y flujo de cancelación con notificación al cliente.
- `controllers/booking/system_admin_view/system_admin_booking_controller.dart`
  (`SystemAdminBookingController`): estadísticas y dashboard por motel para
  el administrador del sistema.

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

Es el único feature con pruebas automatizadas encontradas en el
repositorio:

- `test/controllers/booking/client_view/client_booking_controller_test.dart`
- `test/controllers/booking/owner_view/owner_booking_controller_test.dart`
- `test/controllers/booking/system_admin_view/system_admin_booking_controller_test.dart`
- `test/widgets/booking/*_test.dart` (cancelación, dashboards, detalle,
  listados)

## Qué falta o es provisional

- No hay backend ni persistencia real: todo el estado vive en memoria y se
  reinicia con la app.
- El pago real de una reserva (`confirmPayment` en
  `ClientBookingController`) tiene un método listo para integrarse, pero
  ninguna pantalla en el alcance actual lo dispara; el procesamiento de
  pagos está fuera del alcance implementado hoy.
- La disponibilidad de habitaciones se calcula combinando este controlador
  con datos mock de otro módulo (`RoomVisualData`, ver
  `widgets/room` y `controllers/room/room_mock_data.dart`); no hay una
  única fuente de verdad de disponibilidad.
- La nota final de `docs/booking_context.md` ("Nota para el LLM (Claude)")
  sobre métricas adicionales para el dashboard de administrador sigue sin
  resolver: es una petición abierta, no una implementación pendiente
  confirmada por el equipo.
