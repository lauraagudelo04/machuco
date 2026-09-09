# Contexto - Funcionalidad de bookings (rama: feature-juan_pablo)

## Rol del usuario

Cliente, Propietario, Administrador del sistema.

Esta rama es dueña del **módulo "Bookings" completo**: cada uno de los tres
roles definidos en el proyecto accede a su propia vista de reservas, pero
los tres comparten el mismo dominio de datos (`Reservation` /
`ReservationStatus` en `lib/models/booking/`). No se trata de tres
funcionalidades separadas — es una sola funcionalidad ("gestión de
reservas") con una superficie distinta por rol.

> Aclaración de proceso: inicialmente este archivo solo documentaba el rol
> Cliente, asumiendo por error que cada rama cubre un único rol. Se corrigió
> tras confirmar con la persona dueña de la rama que aquí sí corresponden
> los tres roles.

## Feature: Reserva de habitación (Cliente)

Scenario: Cliente inicia el proceso de reserva desde la vista de habitación
Given un cliente se encuentra en la vista de detalle de una habitación
When selecciona la acción de reservar
Then el sistema lo dirige al formulario de reservas
And el formulario muestra en la cabecera la información del motel y de la habitación seleccionada

Scenario: Cliente completa el formulario de reserva (Camino feliz)
Given un cliente autenticado en el formulario de reserva de una habitación
When define su estancia eligiendo fecha/hora de entrada y fecha/hora de salida
And ajusta la cantidad de personas sin superar el límite máximo permitido por la habitación
And agrega de forma opcional servicios adicionales ofrecidos por el motel
And agrega de forma opcional uno o más productos para la habitación
Then el sistema calcula y muestra el costo total
And habilita el botón principal de reserva
When el cliente presiona el botón de reservar
Then se crea el registro de la reserva con estado "pending"
And el estado de la habitación cambia a "reserved" en la franja de tiempo seleccionada
And el sistema navega a la pantalla de selección de método de pago

Scenario: Visualización de disponibilidad en el calendario y tiempo de preparación
Given un cliente interactuando con el selector de fechas y horas en el formulario
When visualiza las fechas en el calendario
Then el sistema solo resalta (en color) los días que no tienen reservas o que aún cuentan con horas disponibles
And bloquea los horarios garantizando automáticamente un margen de 1 hora de preparación después del fin de la reserva anterior (ej. si una reserva finaliza a las 18:00, el horario disponible más próximo será a las 19:00)
And muestra un mensaje explicativo si el usuario intenta forzar un horario bloqueado

Scenario: Validación del límite de ocupantes
Given un cliente en el formulario de reserva
When intenta incrementar el número de personas en el selector
Then el sistema deshabilita la acción de incrementar al alcanzar el máximo de personas permitidas para esa habitación específica

Scenario: Cliente completa el pago de una reserva pendiente
Given un cliente en la pantalla de selección de método de pago con una reserva en estado "pending"
When el sistema recibe una respuesta de transacción exitosa
Then el estado de la reserva cambia a "active" (o "upcoming" según la fecha)
And se mantiene el estado de la habitación como "reserved" en la franja de tiempo establecida de forma definitiva

Scenario: Pérdida de disponibilidad por concurrencia durante el llenado del formulario
Given un cliente llenando los datos de reserva para la habitación X
When presiona el botón de reservar
But otro usuario acaba de confirmar una reserva que se solapa con esas fechas/horas milisegundos antes
Then el sistema aborta la creación de la reserva
And notifica al cliente que los horarios acaban de ser ocupados y sugiere actualizar el calendario

Scenario: Interrupción de red al confirmar la reserva
Given un cliente con el formulario de reserva completo y válido
When presiona reservar y la conexión de red falla antes de recibir respuesta del servidor
Then el sistema muestra un error de conexión recuperable
And permite reintentar la acción garantizando la idempotencia (sin generar reservas duplicadas)

Scenario: Abandono del flujo de pago
Given una reserva creada en estado "pending" con una franja de tiempo temporalmente bloqueada
When transcurren 15 minutos sin registrar la selección y confirmación de un pago exitoso
Then el estado de la reserva cambia automáticamente a "cancelled"
And la franja de tiempo de la habitación vuelve a quedar disponible en el calendario (perdiendo el estado "reserved")

## Feature: Gestión de mis reservas (Cliente)

Scenario: Acceso y visualización general del historial de reservas
Given un cliente autenticado se encuentra en el Home de la aplicación
When selecciona el botón de "Mis reservas"
Then el sistema despliega una lista de reservas representadas en tarjetas
And las tarjetas se ordenan por defecto desde la reserva más reciente hasta la más antigua
And cada tarjeta muestra la siguiente información: nombre del motel, número de la habitación, precio total, fechas de la reserva y el estado actual de la reserva

Scenario: Filtrado y ordenamiento del historial
Given un cliente en la vista de su historial de "Mis reservas"
When selecciona las opciones de filtrado u ordenamiento
Then el sistema le permite filtrar los resultados por un motel específico o una habitación en particular
And le permite organizar y reordenar la lista según sus preferencias

Scenario: Navegación al detalle completo de la reserva
Given un cliente visualizando sus tarjetas en "Mis reservas"
When presiona sobre una tarjeta de reserva específica
Then el sistema navega a una nueva pantalla con la información detallada y completa de esa reserva
And presenta dos botones de acción principal: "Descargar factura" y "Ver/Añadir reseña", cuya activación depende del estado actual de la reserva

Scenario: Condiciones de activación para descargar la factura
Given un cliente en la vista detallada de una reserva
When el estado de la reserva es active, upcoming, completed o cancelled
Then el botón de "Descargar factura" se encuentra activo y permite la acción
But si el estado de la reserva es pending, el botón se mantiene inactivo o bloqueado (indicando que requiere la confirmación del pago)

Scenario: Condiciones de activación para gestionar reseñas (reviews)
Given un cliente en la vista detallada de una reserva
When el estado de la reserva es completed o cancelled
Then el botón de "Ver/Añadir reseña" se encuentra activo y permite interactuar con el flujo de reseñas
But si la reserva se encuentra en los estados pending, active o upcoming, el botón se mantiene inactivo o bloqueado

## Feature: Gestión de reservas del propietario (Propietario)

Scenario: Propietario visualiza las reservas de sus moteles
Given un propietario autenticado entra a su vista de reservas
When la pantalla carga
Then el sistema muestra un resumen operativo con el total de reservas, cuántas están activas/próximas y cuántas están pendientes de pago
And lista todas las reservas de los moteles que administra, en tarjetas con motel, habitación, huésped, fechas y estado

Scenario: Propietario filtra las reservas por motel
Given un propietario a cargo de más de un motel
When selecciona un motel específico en el filtro
Then la lista y el resumen operativo se recalculan solo con las reservas de ese motel
And puede volver a la opción "Todos" para ver el conjunto completo

Scenario: Propietario cancela una reserva y notifica al cliente
Given un propietario viendo una reserva en estado pending, active o upcoming
When selecciona la acción de cancelar
Then el sistema exige un motivo obligatorio antes de confirmar la cancelación
And al confirmar, el estado de la reserva cambia a cancelled
And se simula el envío de una notificación al cliente informando la cancelación (mock visual, sin backend ni notificación real)

Scenario: Propietario consulta el detalle de una reserva
Given un propietario viendo la lista de reservas de sus moteles
When toca una reserva específica
Then el sistema muestra el detalle: referencia, huésped, número de personas, habitación, fechas y estado actual

## Feature: Analítica de reservas del sistema (Administrador)

Scenario: Administrador visualiza el resumen agregado de la plataforma
Given un administrador autenticado entra a la vista de analítica de reservas
When la pantalla carga
Then el sistema muestra métricas agregadas de toda la plataforma: total de reservas, promedio de reservas por motel e ingresos estimados totales

Scenario: Administrador compara el rendimiento por motel
Given un administrador en la vista de analítica de reservas
When revisa el listado de moteles
Then cada motel muestra ciudad, total de reservas, reservas activas, reservas canceladas, promedio de reservas por día, tasa de ocupación e ingresos totales
And el listado permite identificar visualmente cuáles moteles tienen mejor o peor desempeño

## Alcance técnico

- **Directorios de trabajo** (los tres roles viven en esta rama):
  - Cliente — **ya implementado**: `lib/views/booking/client_view/`, `lib/controllers/booking/client_view/client_booking_controller.dart`.
  - Propietario — **pendiente** (archivo actualmente vacío, a reconstruir): `lib/views/booking/owner_view/`, `lib/controllers/booking/owner_view/owner_booking_controller.dart`.
  - Administrador — **pendiente** (archivo actualmente vacío, a reconstruir): `lib/views/booking/system_admin_view/`, `lib/controllers/booking/system_admin_view/system_admin_booking_controller.dart`.
  - Compartido entre los tres roles: `lib/models/booking/` (dominio `Reservation`/`ReservationStatus`), `lib/widgets/booking/`, `lib/utils/booking/`.
- **Widgets de Layout**: usar estrictamente `lib/widgets/layout` y el sistema de diseño existente. Los widgets de `lib/widgets/booking/` deben poder servir a más de un rol cuando el caso de uso coincide (p. ej. una tarjeta de reserva reutilizable entre Cliente y Propietario) — no duplicar un widget por rol si ya existe uno genérico que resuelve el caso.
- **Dependencias de entrada**:
  - Cliente: botón "Reservar" de la vista de detalle de habitación (rama `feature_laura`), vista y controller de servicios adicionales, controller de productos.
  - Propietario: necesita saber qué moteles administra. Antes de mockear una relación propia, revisar si ya existe (p. ej. `lib/controllers/motel/owner_controller/owner_motel_controller.dart`); si esa relación no está expuesta de forma reutilizable, mockearla dentro de `owner_booking_controller.dart` igual que el resto de datos.
  - Administrador: la agregación por motel se puede derivar en memoria a partir de las mismas reservas mockeadas; no depende de una fuente externa nueva.
- **Dependencias de salida**: `lib/views/motel/client_view/client_motels_page.dart` (rama `feature_juliang`) consume el modelo `Reservation` definido en esta rama.
- **Fuera de alcance**:
  - Procesamiento real de pagos (se maneja en otra feature).
  - Notificaciones reales (push/email) al cancelar una reserva — se simulan solo visualmente (snackbar/mensaje).
  - Autenticación/enrutamiento real por rol tras el login: hoy `lib/views/login/login_page.dart` navega siempre a `ClientMotelsPage` sin importar el tipo de perfil elegido en el registro. Arreglar ese enrutamiento no es responsabilidad de esta rama, pero cada vista de rol de bookings debe poder alcanzarse de forma directa (ruta nombrada o entrypoint temporal) mientras esa pieza no exista.
- **Reglas de dominio**: el estado de la reserva usa un único enum estricto compartido por los tres roles: `pending, active, upcoming, completed, cancelled`. Propietario y Administrador deben leer/derivar sobre este mismo enum — no crear uno paralelo (la implementación previa a este replanteo tenía un `BookingStatus` distinto para cada cosa; eso ya no aplica).
- **Datos externos**: cuando se necesiten datos de otros contextos, tomarlos desde el controller correspondiente siguiendo una lógica de uso correcta, nunca desde la vista.

## Notas para el agente

- **Mocking requerido**: al carecer de backend, cada controller de rol mantiene sus propios datos mockeados en memoria (`ChangeNotifier` o clase estática, según necesidad de reactividad), igual que ya se hizo para `client_booking_controller.dart`.
- **Contexto histórico**: las vistas de los 3 roles para bookings ya existieron completas en esta rama (commits previos al `dd71f74`) y fueron borradas deliberadamente en ese commit para reconstruirlas ahora vía agentes/skills. Esa versión anterior sirve como referencia de intención de negocio, pero usaba el modelo viejo `Booking`/`BookingStatus`/`MotelBookingSummary` — hay que adaptar cualquier idea reutilizada al modelo `Reservation`/`ReservationStatus` ya vigente, no copiar el código literal.
- Antes existía una `BookingHomePage` de demostración que permitía elegir un rol y navegar sin autenticación real, útil mientras no exista login-based routing por rol. Si se recupera algo similar como acceso temporal de desarrollo, debe quedar claramente marcado como no autenticado/no productivo (como lo estaba antes).

### Intención visual

- Formulario de creación de reserva (`create_booking_page.dart`): una sola
  pantalla con scroll, sin stepper/wizard. Secciones apiladas en este orden,
  cada una como bloque tipo AppCard: Cabecera (información del motel y
  habitación) → Fechas/horas (con soporte para selector de rango o fecha de
  entrada + bloque de 8 horas) → Personas (selector tipo contador - N +
  con validación de límite máximo) → Servicios y productos opcionales
  (checkboxes o chips seleccionables) → Resumen con total. El botón
  "Reservar" va al final del resumen, no flotante, habilitándose al
  completar los datos.

- "Mis Reservas" (historial, Cliente): accesible desde el Home. En la
  cabecera incluye opciones de filtrado (por motel o habitación) y
  ordenamiento. El cuerpo es una lista de reservas ordenada por defecto de
  más reciente a más antigua. Cada elemento es una tarjeta (AppCard, estilo
  similar a RoomCard/MotelCard) interactiva con: motel, número de
  habitación, monto total, fechas de la reserva y un StatusBadge indicando
  el estado actual.

- Detalle de una reserva (`booking_detail_page.dart`): accesible al
  presionar una tarjeta del historial. Utiliza un StatusBadge para
  comunicar el estado, sin timeline ni indicador de progreso. Debajo,
  presenta toda la información detallada de la reserva en formato de lista.
  Al final de la vista, se ubican dos botones de acción específicos:
  "Descargar factura" y "Ver/Añadir reseña", los cuales se habilitan o
  bloquean dinámicamente según el estado actual de la reserva.

- Resumen previo al pago (Cliente): pantalla completa dedicada (no
  AppBottomSheet) a la que se navega después de confirmar el formulario.
  Muestra motel, habitación, fechas/horas, personas, servicios elegidos y
  total, con un único CTA "Ir a pagar" al final.

- Propietario — "Reservas de mis hoteles": resumen operativo arriba
  (AppCard con métricas: total, activas/próximas, pendientes de pago),
  filtro horizontal por motel (chips), lista de tarjetas de reserva
  reutilizando el mismo componente de `widgets/booking` cuando aplique, con
  una acción de "Cancelar" visible solo cuando el estado lo permite.
  Cancelar abre un bottom sheet pidiendo motivo obligatorio antes de
  confirmar.

- Administrador — "Analítica de reservas": tarjetas de métricas agregadas
  arriba (total de reservas, promedio por motel, ingresos estimados) en un
  grid responsive, y debajo una lista de tarjetas por motel con sus
  indicadores (reservas totales/activas/canceladas, promedio diario,
  ocupación, ingresos). Vista de solo lectura, sin acciones de edición.

### Nota sobre la construcción de la Interfaz (UI):
Genera widgets que sean comunes y se puedan usar en cualquier vista. Evita
construir componentes visuales que queden anclados o acoplados únicamente a
una sola pantalla o a un solo rol; el objetivo es nutrir el sistema de
diseño general del aplicativo para su máxima reutilización.
