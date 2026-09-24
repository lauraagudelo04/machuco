# Guía de transferencia: módulo Bookings

Documento corto y accionable para que otra persona o agente **tome el
módulo de reservas** sin tener que releer todo
`contexts/people/feature-juan_pablo.feature.md` ni todo el código. Esta es
la referencia vigente sobre el estado real; ver la sección 7 para lo que
queda desactualizado en otros documentos.

## 1. Qué es este módulo

Bookings es un único dominio de datos (`Reservation` / `ReservationStatus`
en `lib/models/booking/booking.dart`) compartido por los tres roles del
producto (ver perfiles en `README.md#perfiles`): Cliente, Propietario y
Administrador. No son tres funcionalidades separadas — es una sola gestión
de reservas con una superficie de UI y un controller distintos por rol, pero
un solo enum de estado (`pending`, `active`, `upcoming`, `completed`,
`cancelled`) sin variantes paralelas.

## 2. Estado real por rol

| Rol | Estado | Archivos reales |
|---|---|---|
| Cliente | **Implementado, con un bug crítico de disponibilidad** (ver §3.1) | Vistas: `lib/views/booking/client_view/{client_booking_home_page,create_booking_page,booking_checkout_page,reservation_detail_page,client_reservations_page}.dart`. Controller: `lib/controllers/booking/client_view/client_booking_controller.dart`. |
| Propietario | **Implementado y funcional**| Vistas: `lib/views/booking/owner_view/{owner_reservations_page,owner_reservation_detail_page,owner_cash_payment_page}.dart`. Controller: `lib/controllers/booking/owner_view/owner_booking_controller.dart` (460 líneas). |
| Administrador | **Implementado y funcional**| Vistas: `lib/views/booking/system_admin_view/{admin_motel_reservations_list_page,admin_motel_reservation_dashboard_page}.dart`. Controller: `lib/controllers/booking/system_admin_view/system_admin_booking_controller.dart` (500 líneas). |

Los tres roles comparten `lib/widgets/booking/` (por ejemplo
`reservation_card.dart`, `cancellation_reason_sheet.dart` — este último lo
usan tanto Cliente como Propietario, cumpliendo la regla de no duplicar
widgets por rol) y el enum único `ReservationStatus`; no existe un
`BookingStatus` paralelo.

## 3. Bugs conocidos y su impacto

### 3.1 Asignación de habitación fija, no cálculo de disponibilidad real (Cliente) — crítico

El feature file (escenario "Cálculo de disponibilidad al momento de
reservar") exige que, al presionar "Reservar", el sistema cruce **todas**
las habitaciones activas de un tipo contra sus reservas y asigne una al
azar entre las que queden libres. El código hoy no hace eso:

- `RoomClientController.firstActiveRoomForType`
  (`lib/controllers/room/room_client_controller.dart:31-43`) fija de
  antemano la habitación activa de menor número del tipo, **antes** de
  llegar al formulario de reserva. El propio comentario del archivo
  (líneas 29-30) lo describe como "adaptador temporal".
- `room_client_page.dart:102` navega al formulario pasando ya esa única
  habitación (`arguments: room`).
- `ClientBookingController.isSlotAvailable`
  (`lib/controllers/booking/client_view/client_booking_controller.dart:184-208`)
  solo evalúa disponibilidad para ese `roomId` fijo recibido; nunca recibe
  ni recorre una lista de habitaciones candidatas del mismo tipo.

**Impacto:** el sistema no distingue "habitación ocupada" de "tipo sin
disponibilidad": si la única habitación activa asignada de entrada está
ocupada, el cliente ve el horario como no disponible aunque existan otras
habitaciones activas libres del mismo tipo. Rompe los escenarios de
disponibilidad y de concurrencia del feature file.

### 3.2 Botones deshabilitados en vez de ocultos (Cliente) — RESUELTO (2026-09-15)

Antes: `reservation_detail_page.dart` usaba `onPressed: null` en los botones
"Descargar factura" y "Ver / Añadir reseña" cuando el estado no aplica, en
vez de no renderizarse. El feature file lo dice explícitamente dos veces
(Gherkin "el botón ... no se muestra" y la nota de "Intención visual": "no
basta con deshabilitarlas: si el estado no aplica, la acción no se
renderiza").

**Corrección verificada:** los agentes `frontend` y `qa` envolvieron los 4
botones del panel de acciones ("Completar pago", "Descargar factura",
"Ver / Añadir reseña", "Cancelar reserva") en bloques
`if (_xEnabled(reservation.status)) [...]`
(`lib/views/booking/client_view/reservation_detail_page.dart:218-264`), así
que cada botón desaparece del árbol de widgets cuando su estado no aplica,
en vez de quedar deshabilitado. `test/widgets/booking/reservation_detail_page_test.dart`
se actualizó junto con el fix: los `expect(..., onPressed, isNull)` de antes
ahora son `expect(find.text(...), findsNothing)`, y los 7 tests del archivo
pasan con el comportamiento nuevo.

### 3.3 El rechazo de "tipo sin unidades activas" ocurre en la pantalla equivocada

El feature file especifica que el cruce y rechazo ocurren al presionar
"Reservar" dentro del formulario (no hay vista de calendario previa). El
código actual rechaza antes, en la pantalla de tipos de habitación:
`lib/views/room/client_view/room_client_page.dart:101-125` (el `onTap` del
`AppCard` de cada tipo, que llama a `firstActiveRoomForType` y muestra un
snackbar si es `null`, sin llegar nunca al formulario).

**Impacto:** es consecuencia directa del bug de §3.1 — al fijar la
habitación antes del formulario, la validación de "sin unidades activas"
también se adelanta a esa misma pantalla.

### 3.4 Orden por defecto de "Mis reservas" ambiguo

`client_reservations_page.dart:26` ordena por defecto usando
`ReservationSortField.checkIn`, no explícitamente por fecha de creación de
la reserva. El feature file solo dice "de la más reciente a la más
antigua", sin aclarar si es por `checkIn` o por `createdAt`. Deviación
menor, a confirmar con negocio antes de tratarla como bug.

> Los bugs 3.1, 3.2 y 3.3 corresponden a los puntos 1, 2 y 3 del reporte de
> QA que originó este documento; 3.4 corresponde al punto 5 (el punto 4 del
> QA, sobre el feature file desactualizado, se documenta en §7 y en
> `docs/decisions_log.md`, no como un bug de código).

## 4. Qué falta / deuda técnica

- **Sin test dedicado:** `create_booking_page.dart`,
  `client_reservations_page.dart`, `booking_checkout_page.dart`,
  `owner_cash_payment_page.dart`. Tampoco hay golden tests para widgets
  compartidos (`reservation_card.dart`, `quantity_stepper.dart`, etc.) ni
  un test de integración end-to-end del flujo completo de reserva.
- **Formato:** `dart format --set-exit-if-changed` marca sin formatear
  `lib/views/booking/client_view/create_booking_page.dart` y
  `lib/views/booking/client_view/reservation_detail_page.dart` (verificado
  de nuevo al escribir este documento).
- **`flutter analyze` y la suite de tests** están limpios hoy (90 tests
  pasan, 1 skip documentado por límite de reloj inyectable) — esto no es
  deuda, se deja registrado como línea base.
- El pago real (`ClientBookingController.confirmPayment`) tiene el método
  listo pero ninguna pantalla en el alcance actual lo dispara; el
  procesamiento de pagos sigue fuera de alcance (ver
  `docs/modules/booking.md`).

## 5. Reglas de dominio no negociables

- **Un solo enum de estado:** `ReservationStatus` (`pending`, `active`,
  `upcoming`, `completed`, `cancelled`) es compartido por los tres roles.
  No crear un `BookingStatus` paralelo ni un enum específico de rol.
- **`Room` solo tiene dos estados propios:** activa o inactiva
  (`isActive`), sin relación directa con el estado de una reserva puntual.
  No existe un campo "reservada/ocupada" persistente en la habitación.
- **La disponibilidad nunca se cachea como estado de la habitación.** Se
  calcula en el controller de reservas al momento de presionar "Reservar",
  cruzando las habitaciones **activas** de un tipo contra sus reservas
  vigentes (`pending`, `upcoming`, `active`) en el rango solicitado. No es
  una vista de calendario navegable.
- **Margen de 1 hora de preparación** obligatorio después de cada reserva
  (`ClientBookingController.preparationBuffer`), aplicado en
  `isSlotAvailable` y `explainBlockedSlot`.
- Conflicto de diseño ya señalado por el propio feature file, no resuelto
  aquí: `README_DISENO_FLUTTER.md#51-paleta-de-colores` define un
  `StatusBadge` de habitación con siete estados visuales, incompatible tal
  cual con el modelo de solo dos estados (`activa`/`inactiva`) de `Room`. Si
  la UI necesita esos matices, deben derivarse combinando `Room.isActive`
  con las reservas cruzadas en la capa de presentación, no agregarse como
  un tercer estado propio de `Room`.

## 6. Funcionamiento por rol: camino feliz y escenarios probables

Esta sección documenta **cómo se usa la funcionalidad hoy**, cruzando los
escenarios Gherkin de
[`contexts/people/feature-juan_pablo.feature.md`](../contexts/people/feature-juan_pablo.feature.md)
contra el código real. No repite las reglas de dominio de la sección 5 ni
los bugs de la sección 3 (los referencia cuando aplica). Para el inventario
técnico de archivos, ver [`docs/modules/booking.md`](modules/booking.md).

### 6.1 Cliente

**Camino feliz (lo que el código hace hoy, no la versión idealizada del Gherkin):**

1. En la vista de tipos de habitación (`lib/views/room/client_view/room_client_page.dart`),
   el cliente toca un tipo. `RoomClientController.firstActiveRoomForType`
   fija de antemano **una única habitación** (la de menor número activa de
   ese tipo) — no hay asignación al azar entre candidatas todavía; ver
   §3.1. Con esa habitación ya fija, navega a
   `CreateBookingPage` (`lib/views/booking/client_view/create_booking_page.dart`).
2. En el formulario: elige fecha/hora de entrada y de salida con selectores
   independientes (2 `showDatePicker` + 2 `showTimePicker`, no "el mismo
   calendario" que describe el Gherkin literalmente), ajusta personas con
   `QuantityStepper` (tope = `room.capacity`), y agrega servicios/productos
   opcionales. El resumen calcula el total en vivo. El botón "Reservar" solo
   se habilita si el formulario es válido (`_isFormValid`).
3. Al presionar "Reservar", `ClientBookingController.createReservation`
   revalida disponibilidad **solo de la habitación ya fija** recibida del
   paso 1 (otra vez §3.1: no cruza contra una lista de habitaciones
   candidatas del mismo tipo) y crea la reserva en `pending`.
4. Si la creación es exitosa, navega a `BookingCheckoutPage` (resumen previo
   al pago), que muestra una cuenta regresiva real de los 15 minutos antes
   de que la reserva expire (`Timer.periodic` de 1s que llama
   `checkExpirations()`).
5. "Ir a pagar" navega a `AppRoutes.paymentMethod` (selección de método de
   pago, feature de otra rama, fuera de alcance aquí). El procesamiento real
   de pago no está conectado a ninguna pantalla de este alcance (ver §4);
   el gancho `ClientBookingController.confirmPayment` existe pero nada lo
   invoca todavía.
6. La reserva creada aparece de inmediato en "Mis reservas"
   (`client_reservations_page.dart`) y en su propio detalle.

**Escenarios/reglas implementadas y probables hoy:**

- Validaciones del formulario: salida no posterior a la entrada, entrada en
  el pasado, estancia mayor a 24h continuas — mensajes inline
  (`_InlineNotice` en `create_booking_page.dart`).
- Límite de ocupantes: el stepper de personas bloquea incrementar al llegar
  a `room.capacity`.
- Cálculo de disponibilidad cruzando reservas vigentes + margen de 1 hora de
  preparación (`isSlotAvailable`/`explainBlockedSlot`), aplicado solo sobre
  la habitación ya fija recibida (limitación de §3.1).
- Herramientas de depuración visibles en el propio formulario
  (`_DebugToolsCard`): dos switches — "Simular error de red al reservar" y
  "Simular que el horario se ocupó justo antes" — permiten disparar a mano,
  sin backend, los escenarios de interrupción de red y de conflicto.
- **Interrupción de red con idempotencia: genuinamente implementada**, no
  solo simulada visualmente. `createReservation` recibe un `requestId`; si
  la primera llamada "falla por red", un reintento con el mismo `requestId`
  no duplica la reserva (deduplicación real en memoria). Cubierto por
  `test/controllers/booking/client_view/client_booking_controller_test.dart`
  (grupo "concurrencia e interrupción de red").
- Cuenta regresiva de expiración visible en `BookingCheckoutPage`.
- "Mis reservas": filtro por motel/habitación, orden por fecha de
  entrada/fecha de creación/total (asc/desc), skeleton de carga, estado de
  error y estado offline simulables desde el menú de depuración de la
  AppBar, estado vacío distinto si nunca hubo reservas vs. si el filtro no
  encontró nada.
- Visibilidad condicional de las 4 acciones del detalle según estado — ya
  corregida, ver §3.2 (resuelta).
- Cancelación con motivo obligatorio vía el bottom sheet compartido
  `lib/widgets/booking/cancellation_reason_sheet.dart`; el motivo queda
  visible de forma permanente en el detalle.

**Errores / casos borde que se pueden probar hoy:**

- Confirmar cancelación sin motivo → el bottom sheet bloquea con "El motivo
  de cancelación es obligatorio." y la reserva no cambia de estado.
- Cancelar una reserva en un estado no cancelable → lanza
  `ReservationCancellationException` (`invalidStatus`) con mensaje para la UI.
- Detalle o checkout de una reserva inexistente → `AppEmptyState` ("Reserva
  no encontrada").
- Checkout de una reserva que ya expiró (pasó a `cancelled` por abandono de
  pago) → `AppErrorState` explicando que el tiempo para pagar venció.
- Simular error de carga / sin conexión en "Mis reservas" desde el menú de
  depuración de la AppBar.
- Filtro de "Mis reservas" sin resultados → estado vacío con acción de
  "Limpiar filtros".
- Conflicto de horario disparado manualmente con el switch de depuración del
  formulario → rechazo con mensaje y acción de "Actualizar calendario".

**Escenarios del Gherkin que el código NO implementa hoy (verificado, no asumido):**

- Asignación **al azar** entre habitaciones activas candidatas del mismo
  tipo: no implementada, es el bug crítico de §3.1.
- "El mismo calendario" para entrada y salida: el código usa selectores de
  fecha y hora independientes, no un único componente de calendario.
- Mensaje "señala junto al selector de fechas que el campo es obligatorio"
  cuando no se ha elegido fecha/hora: el botón sí queda deshabilitado
  (`_isFormValid`), pero no hay ningún indicador de error junto a los
  selectores mientras están vacíos (solo muestran el placeholder "Elegir
  fecha"/"Elegir hora"); el mensaje de error inline solo aparece una vez que
  ambas fechas ya están seleccionadas y el rango resulta inválido.
- Pérdida de disponibilidad por **concurrencia real** (dos solicitudes
  simultáneas compitiendo por la última habitación con locking/bloqueo
  pesimista u optimista real): no existe tal mecanismo. Lo que hay es un
  flag manual (`simulateConcurrentConflict`) que el propio formulario expone
  como switch de depuración para forzar el mensaje de conflicto; no hay
  ninguna condición de carrera genuina que probar porque el dataset es
  local, en memoria y de un solo hilo.
- Expiración automática a los 15 minutos de una reserva `pending`: el
  mecanismo (`ClientBookingController.pendingPaymentTimeout` +
  `_expirePendingReservations`) sí está implementado y se ejecuta en la app
  real (perezosamente en cada lectura, y activamente cada segundo desde el
  `Timer` de `BookingCheckoutPage`), pero **no hay un test automatizado que
  verifique el paso real del tiempo**: existe un test con `skip` documentado
  en `client_booking_controller_test.dart:363-375` porque el controller usa
  `DateTime.now()` directamente y el proyecto no tiene aprobado un paquete
  de reloj inyectable (agregarlo unilateralmente violaría la regla de
  dependencias no acordadas de `CLAUDE.md`).
- El pago real de una reserva `pending` a partir de "una respuesta de
  transacción exitosa": no hay ninguna pantalla en este alcance que dispare
  `confirmPayment` (ya registrado en §4, no es un hallazgo nuevo).

### 6.2 Propietario

**Camino feliz:**

1. `OwnerReservationsPage` carga (`OwnerBookingController.loadReservations`)
   los moteles administrados por el propietario (vía
   `MotelController.getMotelsByOwnerId`, relación ya existente, no
   mockeada de nuevo) y sus reservas; muestra un resumen operativo (total,
   activas/próximas, pendientes de pago) y la lista de tarjetas ordenada de
   más reciente a más antigua.
2. Aplica filtros combinables por motel, estado y habitación
   (`ReservationFilterBar` + `filteredReservations`); puede limpiarlos con
   un botón cuando el resultado queda vacío.
3. Toca una reserva → `OwnerReservationDetailPage`: referencia, huésped,
   personas, fechas, total, `StatusBadge` y, si aplica, motivo de
   cancelación.
4. Si el estado es `pending`: botón "Pagar en efectivo" → `OwnerCashPaymentPage`
   (concepto + monto + un único botón de confirmación) → `registerCashPayment`
   marca el cobro como realizado, mueve la reserva a `active`/`upcoming` si
   seguía `pending`, y deja el acceso a "Ver factura" en `InvoiceAccessStatus.pending`
   (la factura **no** se genera ni se muestra de inmediato).
5. Si el estado es `pending` o `upcoming`: botón "Cancelar" → mismo flujo
   compartido de motivo obligatorio (`cancellation_reason_sheet.dart`) →
   cambia a `cancelled` y "notifica" al cliente solo con un `debugPrint` y un
   snackbar propio (mock visual, sin backend ni notificación real).

**Escenarios implementados y probables hoy:**

- Filtro combinable por motel, estado y habitación
  (`OwnerBookingController.roomOptions` deriva las opciones de habitación de
  las reservas ya cacheadas).
- Filtro sin resultados → estado vacío + acción de limpiar filtros.
- Orden por defecto de más reciente a más antigua.
- Vista acotada a un cliente específico: `OwnerReservationsPage` acepta
  `clientId`/`clientName` opcionales y reutiliza el **mismo** método
  `filteredReservations(clientId: ...)` que usaría el módulo de Clientes —
  cumple la exigencia del Gherkin de no duplicar ese filtro.
  `OwnerBookingController.reservationsForClient` queda expuesto para que ese
  módulo (fuera de alcance de esta rama) lo consuma directamente.
- Estados de carga (skeleton), error y offline simulables desde el menú de
  depuración de la AppBar, igual patrón que Cliente.

**Errores / casos borde probables:**

- Cancelar sin motivo → bloqueado igual que en Cliente, mismo componente
  compartido.
- Cancelar en un estado no cancelable → `ReservationCancellationException.invalidStatus`.
- Cobrar en efectivo un id de reserva inexistente →
  `ReservationCancellationException.notFound`.
- Detalle o cobro de una reserva inexistente → `AppEmptyState`.

**Gherkin simulado o no implementado (explícito):**

- La notificación al cliente al cancelar es un mock (`debugPrint` +
  snackbar del propio propietario); no hay backend, push ni email reales —
  coincide con lo que el propio feature file marca como "fuera de alcance".
- La generación real de la factura tras el cobro en efectivo no ocurre; el
  acceso queda "pendiente" (ya documentado en README y en el feature file,
  no es un hallazgo nuevo).

### 6.3 Administrador

**Camino feliz:**

1. La pantalla recibe `ownerId` como argumento de ruta (la navegación
   jerárquica real de "elegir propietario" pertenece a otra rama y no existe
   aquí). `AdminMotelReservationsListPage` carga los moteles de ese
   propietario junto con un KPI comparativo por motel
   (`SystemAdminBookingController.motelKpiSummary`), resaltando visualmente
   el mejor/peor motel por ingresos totales cuando hay más de uno con
   variación.
2. Al tocar un motel, `AdminMotelReservationDashboardPage` (recibe
   `motelId`) muestra: el total histórico de reservas, un gráfico de
   evolución mensual de los últimos 12 meses (`SimpleBarLineChart`), un
   filtro interactivo por estado sobre ese gráfico (recalcula solo la serie,
   sin repetir toda la carga del dashboard) y un desglose de pagos por
   método (efectivo/tarjeta/transferencia — mock propio de este controller,
   no forma parte del modelo `Reservation` compartido).
3. Vista de solo lectura: no hay ninguna acción de edición ni cancelación
   disponible para el Administrador.

**Escenarios implementados y probables hoy:**

- KPI comparativo por motel: ciudad, total de reservas, activas, canceladas,
  promedio de reservas por día, tasa de ocupación aproximada, ingresos
  totales y promedio mensual — todo derivado en memoria del dataset propio
  del controller.
- Resaltado de mejor/peor motel cuando hay variación de ingresos entre los
  moteles de un mismo propietario.
- Filtro de la serie de evolución por estado sin recargar todo el dashboard.
- Motel sin historial (el dataset deja deliberadamente el motel `'3'`/Motel
  Eclipse sin reservas): total histórico en 0, y estados vacíos explicativos
  tanto en el gráfico como en el desglose de pagos, en vez de un gráfico o
  lista vacía sin contexto.
- Estados de carga, error y offline simulables desde el menú de depuración
  de la AppBar, mismo patrón que Cliente/Propietario.

**Errores / casos borde probables:**

- Propietario sin moteles registrados → estado vacío dedicado en el
  listado.
- Motel sin reservas históricas → estados vacíos explicativos (no un gráfico
  vacío ni una lista vacía sin contexto).

**Gherkin no implementado (explícito):**

- La navegación jerárquica real (elegir propietario, luego motel) no existe
  en esta rama: la pantalla recibe `ownerId`/`motelId` directamente como
  argumentos de ruta. Es consistente con "Fuera de alcance" del feature
  file, pero implica que no hay forma de probar el flujo completo end-to-end
  sin esa otra rama.
- Las métricas "sugeridas" del feature file (ticket promedio, tasa de
  cancelación, lead time, duración promedio de estancia, mapa de calor de
  demanda, desempeño por tipo de habitación, comparación interanual) **no
  están implementadas**; el propio feature file las marca como candidatas
  abiertas a validar con negocio, no como requisito cerrado.
- La tasa de ocupación mostrada es una aproximación explícitamente
  documentada en el código (reservas de los últimos 30 días dividido entre
  la cantidad de habitaciones del motel, acotada a 100%), no un cálculo real
  de noches-habitación disponibles vs. ocupadas.

## 7. Enlaces

- [`contexts/people/feature-juan_pablo.feature.md`](../contexts/people/feature-juan_pablo.feature.md)
  — contrato funcional completo (Gherkin por rol, alcance técnico, intención
  visual). **Su sección "Alcance técnico" sobre Propietario/Administrador
  está desactualizada** (los marca como "pendiente/vacío" cuando ya están
  implementados) — ver `docs/decisions_log.md`, entrada 2026-09-15.
- [`docs/decisions_log.md`](decisions_log.md) — registro de desalineaciones
  entre el feature file/documentos raíz y el código real, incluida la de
  arriba.
- [`docs/modules/booking.md`](modules/booking.md) — inventario técnico
  detallado (modelos, controllers, pantallas, rutas, pruebas) del módulo;
  sigue vigente como referencia de estructura, complementa este documento.
- [`docs/booking_context.md`](booking_context.md) y
  [`docs/booking_structure.md`](booking_structure.md) — quedan como
  **referencia histórica desactualizada**, no como fuente de verdad:
  `booking_context.md` describe que "Pagar en efectivo" genera y muestra la
  factura de inmediato (hoy la deja en estado pendiente, ver §3 de este
  documento) y que la cancelación del propietario "dispara una notificación
  automática" (hoy es un mock visual sin backend, ver §6.2); `booking_structure.md`
  describe un árbol de archivos (`booking_detail_page.dart`,
  `client_booking_home_page.dart` como único archivo de cliente, etc.) que
  ya no coincide con el árbol real listado en §2 de este documento. Para
  arquitectura por capas ver [`docs/architecture.md`](architecture.md).
