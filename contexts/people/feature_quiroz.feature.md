# Contexto - Funcionalidad de suscripciones del propietario (rama: feature_quiroz)

## Rol del usuario

Propietario (y Administrador del sistema para consulta de ingresos por suscripción).

Esta rama es dueña del **módulo de suscripción del propietario** (`owner_subscription`): el rol Propietario accede a su propia vista para consultar el estado de la membresía de su motel, los beneficios contratados, la fecha de próximo cobro y el historial detallado de pagos, además de contar con la capacidad de registrar nuevos comprobantes de pago de forma reactiva.

> Aclaración de arquitectura: inicialmente este módulo existía como un archivo monolítico en PascalCase (`OwnerSubscriptionPage.dart`) con modelos, widgets privados y estado local mezclados. Se refactorizó completamente siguiendo la separación en capas (`models/`, `controllers/`, `widgets/`, `views/` y `routes/`), adaptando los tipos de datos a los estándares del proyecto (`int` para montos, `DateTime` para fechas y `AppStatus`).

## Feature: Gestión de la suscripción (Propietario)

Scenario: Propietario consulta los datos de su suscripción activa
  Given un propietario autenticado ingresa a la vista de suscripción
  When la pantalla carga
  Then visualiza la tarjeta principal con el nombre del plan ("Plan Premium Pro"), el nombre de su motel ("Motel Paraíso Real") y el badge de estado "Activa"
  And se detalla el monto recurrente formateado en moneda local y la fecha exacta del próximo cobro
  And se lista el desglose de beneficios incluidos con iconografía de verificación (ej. gestión de hasta 20 habitaciones, reportes en tiempo real, soporte 24/7)

Scenario: Propietario visualiza el historial de pagos registrados
  Given un propietario en la pantalla de suscripción
  When examina la sección de historial de pagos
  Then visualiza un contador dinámico con el total de registros existentes
  And cada pago se representa en una tarjeta individual con monto, fecha formateada, medio de pago utilizado, número de referencia/comprobante y su estado de procesamiento ("Completada")
  And las tarjetas se ordenan cronológicamente desde el cobro más reciente al más antiguo

Scenario: Visualización ante historial sin registros (Estado vacío)
  Given un propietario cuya cuenta no registra ningún pago previo
  When accede a la sección de historial de pagos
  Then el sistema despliega un estado vacío visual con un mensaje descriptivo ("No hay pagos registrados aún.") sin romper el layout

## Feature: Registro y validación de pagos de suscripción (Propietario)

Scenario: Propietario abre el modal de registro de pago
  Given un propietario en la pantalla de suscripción
  When presiona el botón principal "Ingresar pago"
  Then el sistema despliega un modal inferior (`AddPaymentSheet`) adaptado al teclado
  And el campo de monto se precarga automáticamente con el valor correspondiente a la tarifa del plan
  And se expone un selector con los métodos de pago aceptados (Transferencia Bancaria, Tarjeta de Crédito, PSE / Nequi / Daviplata, Efectivo / Corresponsal)
  And se presenta un campo obligatorio para ingresar el número de comprobante o referencia bancaria

Scenario: Propietario confirma el registro de pago exitosamente (Camino feliz)
  Given un propietario en el formulario de registro de pago con datos válidos
  When ingresa un monto mayor a cero, selecciona su medio de pago, escribe el comprobante y presiona "Confirmar pago"
  Then el sistema valida los campos, genera el nuevo registro con identificador único y fecha actual
  And inserta el nuevo pago en la primera posición de la lista de pagos del controlador
  And cierra el modal automáticamente
  And la interfaz se actualiza de forma reactiva reflejando el incremento del contador de registros
  And despliega un SnackBar flotante con confirmación ("Pago registrado correctamente")

Scenario: Intento de registro con campos vacíos o inválidos
  Given un propietario interactuando con el formulario de registro de pago
  When intenta confirmar el pago con el campo de monto vacío o con un valor menor o igual a cero
  Then el sistema detiene el envío y muestra un mensaje de error bajo el campo ("Ingresa un monto válido mayor a 0")
  When el propietario deja vacío el campo de número de comprobante/referencia
  Then el sistema muestra un mensaje de validación ("Ingresa el número de referencia") y no registra la transacción

Scenario: Cancelación o cierre del formulario de registro
  Given un propietario con el modal de registro de pago abierto
  When presiona el botón de cerrar (icono "X") o pulsa fuera del área del modal
  Then el formulario se descarta sin alterar el historial ni emitir notificaciones de error

## Alcance técnico

- **Directorios de trabajo**:
  - Modelos: `lib/models/subscription/subscription.dart` (dominio `SubscriptionDetails` y `SubscriptionPayment` inmutables con constructores `const`).
  - Controlador: `lib/controllers/subscription/owner_subscription_controller.dart` (extiende `ChangeNotifier`, mantiene estado en memoria, expone listas inmutables y centraliza `addPayment()`).
  - Componentes visuales: `lib/widgets/subscription/`
    - `subscription_detail_card.dart`: tarjeta principal de plan, montos y beneficios.
    - `subscription_payment_card.dart`: tarjeta reutilizable de historial de cobro.
    - `add_payment_sheet.dart`: bottom sheet modal con formulario validado.
  - Vista principal: `lib/views/owner_subscription/owner_subscription_page.dart` (puramente declarativa, escucha al controller mediante `ListenableBuilder`, con contención responsive a 920px).
  - Enrutamiento centralizado: `lib/routes/routes.dart` (registrado bajo `AppRoutes.ownerSubscription = '/subscription/owner'`).
  - Pruebas automatizadas: `test/subscription/owner_subscription_test.dart` (pruebas unitarias del controller y pruebas de widgets completas).
- **Widgets de Layout y Design System**:
  - Uso estricto de componentes del sistema de diseño: `AppCard`, `AppButton`, `AppTextField`, `StatusBadge`, `AppRadius`, `AppSpacing`, `AppColors` y `AppTextStyles`.
  - Responsive: uso de `ConstrainedBox(maxWidth: 920)` centrado con `SafeArea` y `ListView` con scroll seguro ante teclados virtuales (`viewInsets.bottom`).
- **Dependencias de entrada**:
  - `package:machuco/core/design_system/design_system.dart`.
  - `lib/utils/currency_formatter.dart` (`formatCurrencyAmount`) para el formateo homogéneo de precios enteros en pesos colombianos.
  - `lib/utils/date_formatter.dart` (`formatDayMonthLabel`) para la presentación de fechas sin hardcoding.
- **Dependencias de salida**:
  - Panel general del Propietario: cuando el menú o navegación del rol Propietario unifique los módulos, consumirá `AppRoutes.ownerSubscription`.
- **Fuera de alcance de esta rama**:
  - Pasarela de pagos bancaria real con webhooks (Wompi, MercadoPago, etc.) — se mantiene como mock reactivo en memoria al igual que los demás módulos del equipo.
  - Modificación de archivos de otras funcionalidades (reservas, productos, reseñas, moteles de clientes) para prevenir conflictos entre ramas.
- **Reglas de dominio**:
  - Montos tipados estrictamente como enteros (`int amount`) para permitir cálculos y formateo limpio.
  - Fechas como objetos `DateTime`.
  - Estados modelados mediante el enum compartido `AppStatus` (`active`, `completed`, `pending`, `cancelled`).
- **Datos externos y arquitectura**:
  - Ninguna vista consulta datos directamente; la UI es un reflejo reactivo del estado provisto por `OwnerSubscriptionController`.

## Notas para el agente

- **Mocking requerido**: al carecer de backend en esta fase del proyecto, el controlador mantiene su propio estado mockeado en memoria mediante `ChangeNotifier`, notificando cambios para refrescar la UI al invocar `addPayment()`.
- **Contexto histórico y refactor**: el archivo original `lib/views/owner_subscription/OwnerSubscriptionPage.dart` era un monolito de 557 líneas con modelos embebidos y `setState` local, violando las guías del proyecto. Fue reemplazado por la arquitectura en capas, eliminando también la carpeta vacía residual `lib/views/ownersubscription/`.
- **Error preexistente detectado en `develop`:**
  - En `lib/views/booking/client_view/create_booking_page.dart:61:27`, existe una llamada a `ProductController()` que arroja error en `flutter analyze` y `flutter test` general debido a que `ProductController` solo expone un constructor privado `_internal()` y el singleton `instance`.
  - **Regla estricta:** NO modificar archivos ajenos desde esta rama. Para probar nuestro módulo de forma aislada, ejecutar:
    ```bash
    flutter analyze lib/models/subscription lib/controllers/subscription lib/widgets/subscription lib/views/owner_subscription lib/routes/routes.dart test/subscription/owner_subscription_test.dart
    flutter test test/subscription/owner_subscription_test.dart
    ```
- **Autenticación en GitHub (cuentas múltiples):**
  - La cuenta con permisos de `WRITE` en `lauraagudelo04/machuco` es **`cristian055`**.
  - La cuenta `cquiroz6211` solo posee permisos de `READ`.
  - Para operaciones de Git y GitHub CLI (`gh`), asegurar que el usuario activo sea `cristian055` mediante:
    ```bash
    gh auth switch --user cristian055
    ```

### Intención visual

- **Pantalla de Suscripción (`owner_subscription_page.dart`)**:
  - Estructura vertical limpia centrada en pantalla con un ancho máximo de 920px.
  - Arriba: `SubscriptionDetailCard` en un bloque `AppCard` destacando el nombre del plan, el motel asociado, un `StatusBadge` con estado `Activa`, el monto recurrente en color violeta principal, la fecha de próximo cobro y los ítems de beneficios con icono check circular.
  - Centro: Botón de acción principal con ancho completo (`AppButton`) para "Ingresar pago" con icono de tarjeta.
  - Abajo: Encabezado de "Historial de pagos" con contador subordinado a la derecha, seguido de la lista de tarjetas `SubscriptionPaymentCard` con padding consistente (`AppSpacing.screen`).
- **Modal de pago (`add_payment_sheet.dart`)**:
  - Modal bottom sheet con esquinas superiores redondeadas (`AppRadius.xl`), encabezado con botón de cierre ("X"), campo de monto numérico, selector dropdown estilizado para medio de pago y campo de texto para el número de comprobante con validación en tiempo real al enviar.

### Nota sobre la construcción de la Interfaz (UI):
Construir siempre widgets modulares y desacoplados ubicados en `lib/widgets/subscription/`. Evitar clases privadas dentro del archivo de vista que limiten la reutilización o sobrecarguen las líneas del componente de pantalla.
