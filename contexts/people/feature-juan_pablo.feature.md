# Contexto - Funcionalidad de bookings (rama: feature-juan_pablo)

## Rol del usuario

Cliente, Propietario, Administrador del sistema.

Esta rama es dueña del **módulo "Bookings" completo**: cada uno de los tres
roles definidos en el proyecto accede a su propia vista de reservas, pero
los tres comparten el mismo dominio de datos (`Reservation` /
`ReservationStatus` en `lib/models/booking/`). No se trata de tres
funcionalidades separadas — es una sola funcionalidad ("gestión de
reservas") con una superficie distinta por rol.


## Feature: Reserva de habitación (Cliente)

Scenario: Cliente inicia el proceso de reserva desde la vista de habitación
Given un cliente se encuentra en la vista de los tipos de habitación
When selecciona el tipo de habitación que desea reservar
Then el sistema lo dirige al formulario de reservas
And el formulario muestra en la cabecera la información del motel y el tipo de habitación seleccionada

Scenario: Cliente completa el formulario de reserva (Camino feliz)
Given un cliente autenticado en el formulario de reserva de una habitación
When define su estancia eligiendo fecha/hora de entrada y fecha/hora de salida en el mismo calendario
And ajusta la cantidad de personas sin superar el límite máximo permitido por la habitación
And agrega de forma opcional servicios adicionales ofrecidos por el motel
And agrega de forma opcional uno o más productos para la habitación
Then el sistema calcula y muestra el costo total
And habilita el botón principal de reserva
When el cliente presiona el botón de reservar
Then se crea el registro de la reserva con estado "pending"
And el sistema asigna al azar una habitación específica entre las habitaciones **activas** de ese tipo que no tengan ninguna reserva solapada con las fechas/horas solicitadas (respetando el margen de 1 hora de preparación)
And el sistema navega a la pantalla de Resumen de la Reserva

Scenario: Cliente revisa el resumen antes de pagar
Given un cliente que acaba de crear una reserva en estado "pending"
When llega a la pantalla de Resumen de la Reserva
Then el sistema muestra el motel, el tipo de habitación, la habitación específica asignada, las fechas/horas, la cantidad de personas, el desglose de costos (habitación + adicionales) y el costo total
And presenta el botón único **[Ir a Pagar]**
When el cliente presiona "Ir a Pagar"
Then el sistema navega a la pantalla de selección de método de pago

Scenario: Cálculo de disponibilidad al momento de reservar (sin calendario)
Given un motel con varias habitaciones del mismo tipo, cada una con un único estado propio: activa o inactiva (sin relación con el estado de la reserva)
When el cliente presiona "Reservar" con un tipo de habitación y un rango de fechas/horas ya definidos en el formulario
Then el sistema descarta de entrada todas las habitaciones de ese tipo marcadas como inactivas
And de las habitaciones activas restantes, cruza cada una contra sus propias reservas (`pending`, `upcoming`, `active`) para ese rango de fechas/horas, incluyendo el margen de 1 hora de preparación
And considera el rango solicitado disponible si al menos una habitación activa de ese tipo no tiene una reserva solapada
But considera el rango no disponible únicamente cuando todas las habitaciones activas de ese tipo tienen una reserva solapada
And este cálculo se realiza siempre en el controller al momento de reservar (no en la vista, y no como una vista de calendario navegable), ya que no existe un campo de "reservada/ocupada" almacenado en la habitación

Scenario: Tipo de habitación sin unidades activas
Given un motel donde ninguna habitación del tipo solicitado está marcada como activa
When el cliente intenta reservar ese tipo de habitación (no existe una vista de calendario previa donde consultarlo; el cruce ocurre al presionar reservar)
Then el sistema rechaza la creación de la reserva indicando que no hay unidades disponibles de ese tipo, independientemente de las fechas/horas elegidas o de si existen reservas registradas

Scenario: Intento de confirmar sin seleccionar fecha/hora
Given un cliente en el formulario de reserva sin haber seleccionado fecha/hora de entrada o de salida
When intenta presionar el botón de reservar
Then el sistema mantiene el botón deshabilitado o bloquea el envío
And señala junto al selector de fechas que el campo es obligatorio

Scenario: Validación de fecha/hora de salida inválida
Given un cliente en el formulario de reserva con fecha/hora de entrada ya seleccionada
When selecciona una fecha/hora de salida anterior o igual a la de entrada
Then el sistema rechaza la selección
And muestra un mensaje indicando que la salida debe ser posterior a la entrada

Scenario: Validación del límite de ocupantes
Given un cliente en el formulario de reserva
When intenta incrementar el número de personas en el selector
Then el sistema deshabilita la acción de incrementar al alcanzar el máximo de personas permitidas para esa habitación específica

Scenario: Cliente completa el pago de una reserva pendiente
Given un cliente en la pantalla de selección de método de pago con una reserva en estado "pending"
When el sistema recibe una respuesta de transacción exitosa
Then el estado de la reserva cambia a "active" (o "upcoming" según la fecha)

Scenario: Pérdida de disponibilidad por concurrencia durante el llenado del formulario
Given un cliente llenando los datos de reserva para un tipo de habitación del motel Y, en un horario donde solo queda una habitación activa de ese tipo sin solapamiento
When presiona el botón de reservar
But otro usuario acaba de confirmar una reserva que ocupa esa misma última habitación activa disponible milisegundos antes
Then el sistema aborta la creación de la reserva porque ya no queda ninguna habitación activa de ese tipo sin solaparse en el rango solicitado
And notifica al cliente que los horarios acaban de ser ocupados y sugiere modificar las fechas/horas o el tipo de habitación e intentar nuevamente

Scenario: Interrupción de red al confirmar la reserva
Given un cliente con el formulario de reserva completo y válido
When presiona reservar y la conexión de red falla antes de recibir respuesta del servidor
Then el sistema muestra un error de conexión recuperable
And permite reintentar la acción garantizando la idempotencia (sin generar reservas duplicadas)

Scenario: Abandono del flujo de pago
Given una reserva creada en estado "pending" con una franja de tiempo temporalmente bloqueada
When transcurren 15 minutos sin registrar la selección y confirmación de un pago exitoso
Then el estado de la reserva cambia automáticamente a "cancelled"
And esa reserva deja de contar en el cruce de disponibilidad, por lo que la habitación vuelve a considerarse libre para ese rango en el siguiente cálculo (no existe un estado "reserved" persistente en la habitación)

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
And presenta un panel inferior con hasta cuatro acciones dinámicas, cuya visibilidad depende del estado actual de la reserva: "Ver factura", "Añadir reseña", "Completar pago" y "Cancelar reserva"

Scenario: Condiciones de activación para ver la factura
Given un cliente en la vista detallada de una reserva
When el estado de la reserva es active, upcoming o completed
Then el botón de "Ver factura" es visible y permite la acción
But si el estado de la reserva es pending o cancelled, el botón "Ver factura" no se muestra

Scenario: Condiciones de activación para gestionar reseñas (reviews)
Given un cliente en la vista detallada de una reserva
When el estado de la reserva es completed o cancelled
Then el widget de "Ver/Añadir reseña" y la lista de reseñas es visible y permite interactuar con el flujo de reseñas ["se debe traer el widget realizado por el contexto de reseñas"]
But si la reserva se encuentra en los estados pending, active o upcoming, el widget no se muestra

Scenario: Condición de activación para completar el pago desde el detalle
Given un cliente en la vista detallada de una reserva
When el estado de la reserva es pending
Then el botón de "Completar pago" es visible y lo dirige a la pantalla de selección de método de pago
But si el estado es active, upcoming, completed o cancelled, el botón no se muestra

Scenario: Condición de activación para cancelar desde el detalle
Given un cliente en la vista detallada de una reserva
When el estado de la reserva es pending o upcoming
Then el botón de "Cancelar reserva" es visible
But si el estado es active, completed o cancelled, el botón no se muestra

Scenario: Cliente cancela una reserva desde el detalle
Given un cliente en la vista detallada de una reserva en estado pending o upcoming
When presiona "Cancelar reserva"
Then el sistema abre un modal de confirmación
When el cliente confirma la cancelación
Then el sistema despliega un campo de texto obligatorio para ingresar el "Motivo de cancelación"
And el cliente no puede confirmar sin completar ese campo
When el cliente ingresa el motivo y confirma
Then el estado de la reserva cambia a "cancelled"
And el motivo de cancelación queda visible de forma permanente en el detalle de la reserva

Scenario: Cliente nuevo sin historial de reservas
Given un cliente autenticado sin ninguna reserva registrada
When accede a "Mis reservas"
Then el sistema muestra un estado vacío explicando que aún no tiene reservas y una acción para ir a explorar moteles

Scenario: Error al cargar el historial de reservas del cliente
Given un cliente autenticado accede a "Mis reservas"
When la consulta al repositorio de reservas falla (p. ej. por conexión)
Then el sistema muestra un estado de error comprensible con opción de reintentar
And no muestra un listado vacío como si el cliente no tuviera reservas

Scenario: Cliente intenta cancelar sin ingresar motivo
Given un cliente en el modal de cancelación de una reserva en estado pending o upcoming
When confirma la cancelación sin escribir un motivo
Then el sistema bloquea la confirmación y señala que el campo de motivo es obligatorio
And la reserva permanece en su estado original

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

Scenario: Propietario filtra las reservas por estado
Given un propietario en su vista de reservas generales
When selecciona un estado específico en el filtro (pending, upcoming, active, completed o cancelled)
Then la lista se recalcula mostrando solo las reservas en ese estado

Scenario: Ordenamiento cronológico por defecto
Given un propietario en su vista de reservas generales
When la pantalla carga o se aplica cualquier combinación de filtros
Then la lista se ordena por defecto de la reserva más reciente a la más antigua

Scenario: Propietario cobra una reserva en efectivo
Given un propietario viendo el detalle de una reserva
When selecciona la acción "Pagar en efectivo"
Then el sistema navega a una pantalla con el detalle del cobro (concepto y monto a cobrar) y un botón de confirmación de pago
When el propietario confirma el pago
Then el sistema registra el cobro como realizado
But el botón de "Ver factura" para esa reserva queda en estado "pendiente" (por implementar), en lugar de generar y mostrar la factura de inmediato, ya que la generación real de facturas no está en el alcance actual de esta rama

Scenario: Propietario cancela una reserva y notifica al cliente
Given un propietario viendo una reserva en estado pending o upcoming
When selecciona la acción de cancelar
Then el sistema exige un motivo obligatorio antes de confirmar la cancelación
And al confirmar, el estado de la reserva cambia a cancelled
And se simula el envío de una notificación al cliente informando la cancelación (mock visual, sin backend ni notificación real)
But si la reserva está en estado active, completed o cancelled, la acción de cancelar no está disponible

Scenario: Propietario consulta el detalle de una reserva
Given un propietario viendo la lista de reservas de sus moteles
When toca una reserva específica
Then el sistema muestra el detalle: referencia, huésped, número de personas, habitación, fechas y estado actual

Scenario: Propietario consulta el historial de reservas de un cliente específico
Given un propietario accediendo al detalle de un cliente desde el módulo de Clientes (fuera del alcance de esta rama)
When solicita el historial de reservas de ese cliente
Then el controller de reservas del propietario expone un método para filtrar únicamente las reservas de ese cliente, limitadas a los moteles administrados por el propietario actual


Scenario: Propietario aplica un filtro sin resultados
Given un propietario en su vista de reservas generales
When aplica una combinación de filtros (motel, estado, habitación o cliente) que no coincide con ninguna reserva
Then el sistema muestra un estado vacío indicando que no hay reservas para esos filtros
And ofrece la opción de limpiar los filtros aplicados

Scenario: Propietario filtra las reservas por habitación
Given un propietario en su vista de reservas generales
When selecciona una habitación específica en el filtro
Then la lista se recalcula mostrando solo las reservas de esa habitación

Scenario: Propietario filtra las reservas por cliente
Given un propietario en su vista de reservas generales
When selecciona o busca un cliente específico en el filtro
Then la lista se recalcula mostrando solo las reservas de ese cliente, limitadas a los moteles que administra
And este filtro reutiliza el mismo método del controller que consume el módulo de Clientes al consultar el historial de un cliente puntual (ver escenario "Propietario consulta el historial de reservas de un cliente específico")


Scenario: Propietario intenta cancelar sin ingresar motivo
Given un propietario en el flujo de cancelación de una reserva en estado pending o upcoming
When confirma la cancelación sin escribir un motivo
Then el sistema bloquea la confirmación y señala que el campo de motivo es obligatorio
And la reserva permanece en su estado original y no se dispara notificación al cliente


## Feature: Analítica de reservas del sistema (Administrador)

> El acceso del administrador es jerárquico: primero elige un propietario, luego
> un motel de ese propietario, y desde ahí entra al módulo de Reservas para ver
> la analítica. Esta feature asume que la selección de propietario y motel ya
> ocurrió (la navegan otras ramas) y se enfoca en la vista de estadísticas de
> reservas una vez dentro de un motel.

Scenario: Administrador visualiza el listado de moteles de un propietario con KPIs básicos
Given un administrador que ya seleccionó un propietario
When entra a la vista general de reservas de ese propietario
Then el sistema lista los moteles del propietario, cada uno con un KPI básico de promedio de reservas mensuales

Scenario: Administrador abre el dashboard detallado de un motel
Given un administrador viendo el listado de moteles de un propietario
When selecciona un motel específico
Then el sistema muestra el indicador numérico del total histórico de reservas recibidas
And un gráfico de líneas/barras con la evolución de las reservas durante el último año

Scenario: Administrador segmenta el gráfico de evolución por estado
Given un administrador en el dashboard detallado de un motel
When aplica un filtro interactivo sobre el gráfico por estado de la reserva (completed, cancelled, etc.)
Then el gráfico recalcula la serie mostrada solo con las reservas en ese estado

Scenario: Administrador consulta el desglose de pagos por método
Given un administrador en el dashboard detallado de un motel
When revisa la sección de pagos
Then el sistema muestra el total y la cantidad de reservas pagadas, categorizadas y totalizadas por método de pago

Scenario: Administrador compara el rendimiento entre moteles de un mismo propietario
Given un administrador en el listado de moteles de un propietario
When revisa el listado
Then cada motel muestra al menos ciudad, total de reservas, reservas activas, reservas canceladas, promedio de reservas por día, tasa de ocupación e ingresos totales
And el listado permite identificar visualmente cuáles moteles tienen mejor o peor desempeño


Scenario: Administrador abre el dashboard de un motel sin reservas históricas
Given un administrador entra al dashboard detallado de un motel que nunca ha recibido reservas
When la pantalla carga
Then el sistema muestra el total histórico en cero
And el gráfico de evolución y el desglose de pagos muestran un estado vacío explicativo en lugar de un gráfico vacío sin contexto


Nota (no es un Scenario, es una sugerencia abierta): el contexto de negocio
pide explícitamente sugerir qué otras métricas o gráficos aportarían valor
al panel gerencial del administrador. Candidatas a evaluar con
producto/negocio antes de comprometerlas en el alcance de esta rama:

- Ticket promedio por reserva (ingreso total / número de reservas).
- Tasa de cancelación (canceladas / total de reservas del período).
- Tiempo promedio de anticipación entre la creación de la reserva y la
  fecha de entrada (lead time).
- Duración promedio de la estancia.
- Horarios y días de la semana con mayor demanda (mapa de calor simple).
- Desempeño por tipo de habitación (cuál se reserva más y cuál genera más
  ingreso).
- Comparación del mes actual contra el mismo mes del año anterior.

Estas métricas no forman parte de los criterios de aceptación hasta que se
validen; no deben implementarse como requisito cerrado solo por aparecer
aquí.

## Alcance técnico

- **Directorios de trabajo** (los tres roles viven en esta rama):
  - Cliente — **ya implementado**: `lib/views/booking/client_view/`, `lib/controllers/booking/client_view/client_booking_controller.dart`.
  - Propietario — **ya implementado**: `lib/views/booking/owner_view/`, `lib/controllers/booking/owner_view/owner_booking_controller.dart`.
  - Administrador — **ya implementado**: `lib/views/booking/system_admin_view/`, `lib/controllers/booking/system_admin_view/system_admin_booking_controller.dart`.
  - Compartido entre los tres roles: `lib/models/booking/` (dominio `Reservation`/`ReservationStatus`), `lib/widgets/booking/`, `lib/utils/booking/`.
- **Widgets de Layout**: usar estrictamente `lib/widgets/layout` y el sistema de diseño existente. Los widgets de `lib/widgets/booking/` deben poder servir a más de un rol cuando el caso de uso coincide (p. ej. una tarjeta de reserva reutilizable entre Cliente y Propietario) — no duplicar un widget por rol si ya existe uno genérico que resuelve el caso.
- **Dependencias de entrada**:
  - Cliente: Tipos de habitaciones en la vista de las habitaciones (rama `feature_laura`), vista y controller de servicios adicionales, controller de productos. Además, el cálculo de disponibilidad y la asignación aleatoria necesitan la lista de habitaciones de un motel por tipo con su campo de activación (`isActive` o equivalente) — si el controller/repositorio de habitaciones ya expone eso, consumirlo desde ahí; si no, mockearlo dentro del propio `client_booking_controller.dart` junto con las reservas.
  - Propietario: necesita saber qué moteles administra. Antes de mockear una relación propia, revisar si ya existe (p. ej. `lib/controllers/motel/owner_controller/owner_motel_controller.dart`); si esa relación no está expuesta de forma reutilizable, mockearla dentro de `owner_booking_controller.dart` igual que el resto de datos.
  - Administrador: la agregación por motel se puede derivar en memoria a partir de las mismas reservas mockeadas; no depende de una fuente externa nueva.
  - Reviews: la agregación de los widgets de reseñas se deben validar en el contexto de `lib/views/review` o en `lib/widgets/review`
  - Invoice: se está a la espera de tener la funcionalidad en el repositorio.
- **Dependencias de salida**: `lib/views/motel/client_view/client_motels_page.dart` (rama `feature_juliang`) consume el modelo `Reservation` definido en esta rama.
- **Fuera de alcance**:
  - Procesamiento real de pagos (se maneja en otra feature).
  - Notificaciones reales (push/email) al cancelar una reserva — se simulan solo visualmente (snackbar/mensaje).
  - El módulo de "Clientes" del propietario (listado de clientes asociados, desasociación y desactivación) — pertenece a otra funcionalidad. Esta rama solo debe exponer, desde el controller de reservas, la capacidad de filtrar el historial de reservas por cliente para que ese módulo lo consuma.
  - La navegación jerárquica del administrador (lista de propietarios → moteles de un propietario) — pertenece a otra rama; esta feature asume que esa selección ya ocurrió y se enfoca en la vista de reservas/estadísticas dentro de un motel ya elegido.
  - Autenticación/enrutamiento real por rol tras el login: hoy `lib/views/login/login_page.dart` navega siempre a `ClientMotelsPage` sin importar el tipo de perfil elegido en el registro. Arreglar ese enrutamiento no es responsabilidad de esta rama, pero cada vista de rol de bookings debe poder alcanzarse de forma directa (ruta nombrada o entrypoint temporal) mientras esa pieza no exista.
- **Reglas de dominio**: el estado de la reserva usa un único enum estricto compartido por los tres roles: `pending, active, upcoming, completed, cancelled`. Propietario y Administrador deben leer/derivar sobre este mismo enum — no crear uno paralelo (la implementación previa a este replanteo tenía un `BookingStatus` distinto para cada cosa; eso ya no aplica).
  - **Reglas de dominio — Habitación vs. Reserva (dos estados independientes)**: la habitación (`Room`) es un modelo aparte del de esta rama, pero su estado de activación es la entrada clave para calcular disponibilidad, así que se documenta aquí: `Room` solo tiene dos estados propios, **activa** o **inactiva** (si puede o no ofrecerse para reservar), sin relación directa con el estado de una reserva puntual. No existe una vista de calendario navegable en esta rama: la disponibilidad **no se lee de un campo en la habitación** ni se muestra por adelantado; se calcula en el momento en que el cliente presiona reservar, cruzando las habitaciones activas de un tipo contra sus reservas vigentes (`pending`, `upcoming`, `active`) en el rango solicitado, con el margen de 1 hora de preparación. No cachear ese resultado como si fuera un estado persistente de la habitación.
  >   Nota de conflicto a resolver con el equipo: [README_DISENO_FLUTTER.md](README_DISENO_FLUTTER.md#51-paleta-de-colores) define un `StatusBadge` de habitación con siete estados (Disponible, Reservada, Ocupada, Limpieza, Mantenimiento, Bloqueada, Fuera de servicio). Eso no es compatible tal cual con un modelo de solo dos estados (activa/inactiva). Si la interfaz necesita mostrar esos matices visuales, deben derivarse en la capa de presentación combinando `Room.isActive` con las reservas cruzadas (por ejemplo: "activa + sin reserva en este instante" → Disponible; "activa + con reserva en curso" → Ocupada), no agregarse como un tercer estado propio de `Room`. Esta rama no decide esa reconciliación, solo la señala.
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
  Al final de la vista se ubica un panel de hasta cuatro acciones —
  "Completar pago", "Ver factura", "Ver/Añadir reseña" y "Cancelar
  reserva" — que se muestran u ocultan según el estado actual de la
  reserva (no basta con deshabilitarlas: si el estado no aplica, la acción
  no se renderiza). "Cancelar reserva" abre un AppDialog de confirmación
  seguido de un campo de texto obligatorio para el motivo, igual que en el
  flujo del propietario.

- Resumen previo al pago (Cliente): pantalla completa dedicada (no
  AppBottomSheet) a la que se navega después de confirmar el formulario.
  Muestra motel, tipo de habitación, la habitación específica asignada
  automáticamente por el sistema, fechas/horas, personas, servicios
  elegidos y total, con un único CTA "Ir a pagar" al final.

- Propietario — "Reservas de mis hoteles": resumen operativo arriba
  (AppCard con métricas: total, activas/próximas, pendientes de pago),
  filtros horizontales por motel y por estado (chips) y la lista ordenada
  por defecto de más reciente a más antigua, con tarjetas de reserva
  reutilizando el mismo componente de `widgets/booking` cuando aplique.
  Cada tarjeta/detalle expone "Pagar en efectivo" (lleva a una pantalla de
  cobro con botón de confirmación; por ahora solo registra el cobro y deja
  el acceso a la factura en estado "pendiente", sin generarla de inmediato)
  y "Cancelar" visible solo cuando el estado es pending o upcoming.
  Cancelar abre un bottom sheet pidiendo motivo obligatorio antes de
  confirmar.

- Administrador — "Estadísticas de reservas": tras seleccionar un
  propietario (fuera del alcance de esta rama), se muestra una lista de sus
  moteles con un KPI básico (promedio de reservas mensuales) en cada
  tarjeta. Al entrar a un motel específico se abre el dashboard detallado:
  indicador numérico del total histórico de reservas, un gráfico de
  líneas/barras con la evolución del último año y filtros interactivos
  sobre ese gráfico por estado de la reserva, seguido de un desglose de
  pagos totalizado por método de pago. Vista de solo lectura, sin acciones
  de edición.

### Nota sobre la construcción de la Interfaz (UI):
Genera widgets que sean comunes y se puedan usar en cualquier vista. Evita
construir componentes visuales que queden anclados o acoplados únicamente a
una sola pantalla o a un solo rol; el objetivo es nutrir el sistema de
diseño general del aplicativo para su máxima reutilización.