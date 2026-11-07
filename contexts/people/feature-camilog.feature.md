# Contexto — Payment (rama: feature-camilog)

## Roles de usuario que atiende esta funcionalidad

Propietario y Administrador del sistema. El cliente participa en la selección
de método de pago de Reservas/Payment_Method, no mediante un historial de Payment.

Feature: Pagos de reservas y pago en el local

  Scenario: Identificar la opción de pagar en el establecimiento
    Given la pantalla Método de pago de Payment_Method
    When se muestran las opciones de pago de la reserva
    Then la opción antes llamada Efectivo muestra exactamente «En el Local»
    And se conserva la opción Tarjeta y el comportamiento de ambas opciones

  Scenario: Consultar el maestro de métodos de pago
    Given el catálogo payment_method de Supabase con id y nombre
    When Payment consulta los métodos disponibles
    Then ofrece Efectivo, Tarjeta de crédito, Tarjeta de débito y Transferencia bancaria desde el catálogo
    And conserva una copia local para consultas posteriores sin conexión

  Scenario: Registrar un pago en el local
    Given un pago pendiente del motel del propietario
    When el propietario confirma que recibió el pago con un método del maestro
    Then se guarda el método, la fecha y el comprobante en SQLite
    And el pago queda pagado sin ejecutar un cobro bancario desde la aplicación

  Scenario: Registrar el método desde Finanzas de mi motel
    Given un pago pendiente visible en la vista del propietario
    When pulsa «Registrar pago»
    Then se muestra su cliente, reserva y valor sin permitir cambiarlos
    And se exige elegir explícitamente un método del maestro antes de confirmar
    And solo tras guardar en SQLite pasa a Pagos realizados con método, fecha y comprobante

  Scenario: Fallar al guardar sin perder la selección
    Given un método seleccionado en el registro del pago
    When SQLite no permite guardar
    Then el pago permanece pendiente y el formulario conserva el método
    And se permite reintentar sin mostrar un registro exitoso

  Scenario: Conservar los pagos después de reiniciar
    Given un pago guardado en SQLite
    When se cierra y se vuelve a abrir la aplicación
    Then el pago conserva su estado, método y comprobante

  Scenario: Filtrar registros por cliente y motel en el repositorio
    Given pagos de diferentes clientes y moteles
    When el repositorio consulta los pagos de un cliente o de un motel
    Then se devuelven únicamente los registros correspondientes

  Scenario: Evitar la confirmación duplicada
    Given un pago que ya fue confirmado
    When se intenta confirmar nuevamente
    Then no se modifica el pago ni se genera otro comprobante

  Scenario: Sincronizar los pagos del propietario con Firebase
    Given pagos del motel guardados en SQLite
    And un propietario con una sesión Firebase activa
    When abre o actualiza Finanzas de mi motel
    Then sus pagos se guardan en la colección payments con su uid y motel
    And se incorporan en SQLite los pagos válidos del mismo propietario y motel
    And no se crean documentos duplicados

  Scenario: Conservar el pago cuando Firebase no está disponible
    Given un pago recibido que se guardó correctamente en SQLite
    When Firebase no permite sincronizarlo
    Then el pago continúa pagado en el dispositivo
    And se informa que la sincronización puede reintentarse

  Scenario: Proteger los pagos remotos por propietario
    Given documentos de pago en Cloud Firestore
    When un usuario intenta consultarlos o modificarlos
    Then solo el propietario activo asociado puede escribir sus pagos
    And el administrador puede leerlos
    And el cliente no obtiene un historial de Payment

  Scenario: Manejar un catálogo no disponible
    Given que Supabase no responde
    When se consultan los métodos de pago
    Then se utiliza el catálogo local si existe
    And si no existe se informa el problema y se permite reintentar

## Alcance técnico

- **Carpetas donde trabajo**: lib/models/payment/, lib/repositories/payment/, lib/controllers/payment/, lib/views/payment/, test/database/ y pruebas específicas de Payment. Contrato y guía de configuración en docs/payment_persistence.md.
- **Archivo común autorizado**: lib/database/app_database.dart y su código generado, con migraciones que conserven los demás módulos.
- **Archivos comunes Firebase autorizados**: FirestoreCollections para registrar `payments` y firestore.rules para protegerla. Firebase ya se inicializa en main.dart y no se vuelve a configurar desde esta rama.
- **Depende de**: maestro remoto payment_method de Supabase, AppDatabase compartida, Firebase Auth y Cloud Firestore ya configurados en develop; no de las clases de Suscripción o Payment_Method.
- **De quién depende trabajo mío**: las vistas por rol de Payment; no se cambia el contrato de otras funcionalidades en esta etapa.
- **Excepción autorizada en Payment_Method**: únicamente lib/views/payment_method/payment_method_selection_page.dart para cambiar la etiqueta «Efectivo» por «En el Local», con pruebas específicas de esa vista. No cambiar su lógica ni la pantalla de tarjeta.
- **Fuera de alcance**: lib/models/payment_method/, lib/controllers/payment_method/, las demás vistas de lib/views/payment_method/, integración de una pasarela, escrituras en Supabase y cambios en Booking. Tampoco se reinicializa Firebase ni se reemplazan sus archivos de configuración compartidos.
- **Decisiones autorizadas**: SQLite mediante Floor/sqflite como copia local; Cloud Firestore para sincronizar Payment por propietario y motel; catálogo remoto con id y nombre y todos sus métodos disponibles para Payment. «En el Local» es la etiqueta de la opción de la pantalla de selección, no un reemplazo global de «Efectivo» en Payment ni en el maestro.
- **Entorno de ejecución**: Android en el AVD preferido `Camilo_Pixel10`, con sesión Firebase real y los `--dart-define` de Supabase documentados en docs/payment_persistence.md. No iniciar normalmente con usuarios hardcodeados ni con datos demo; esos modos no representan la app final y la autenticación hardcodeada no sincroniza Firestore.

## Notas para los agentes

- Implementar por etapas: persistencia y pruebas; repositorio y catálogo; controladores y pantallas.
- No asignar un método específico del maestro a pagos históricos que solo indican «online».
- No usar datos de demostración en Payment ni sincronizarlos con el proyecto Firebase compartido.
- No borrar ni recrear la base existente como sustituto de una migración.
- Los fixtures históricos `pay-001` a `pay-003` y `owner-pay-001` a `owner-pay-003` se eliminan de SQLite antes de sincronizar. La conexión de la elección del cliente con Reservas queda pendiente; no inventar pagos para sustituir ese flujo.
- En la vista del propietario, los totales salen de SQLite y las comisiones quedan sin calcular hasta acordar su regla. No mantener los anteriores indicadores fijos como si fueran reales.
- Ejecutar las pruebas mediante un subagente con el modelo openai/gpt-6-luna-fast (GPT-6 Luna Fast), según la preferencia explícita del usuario.
- Por decisión explícita del usuario, eliminar el historial de Payment del cliente («Mis pagos»), su controlador y sus rutas/alias exclusivos. No reintroducirlo ni planificar su conexión a SQLite: no pertenece a la app final. Conservar Payment_Method, los datos y modelos compartidos, y los filtros del repositorio; no borrar pagos existentes.

## Convenciones que deben conservarse en próximas intervenciones

- **Dos momentos distintos**: el cliente elige «En el Local» como lugar de pago; el propietario registra después el método con el que recibió el dinero. Efectivo sigue siendo uno de los métodos del maestro, no el nombre genérico de todos los pagos en el establecimiento.
- **Origen de pendientes**: el flujo deseado es «En el Local» → pago pendiente → recepción y registro por el propietario → pagado. La integración con Reservas aún no existe; no asumir que los ejemplos actuales prueban ese flujo completo ni cambiar Booking sin autorización.
- **Estados**: `pending`, `paid`, `refunded` y `cancelled` se conservan diferenciados. No marcar todos los pagos como pagados ni interpretar una consulta filtrada por `status = 'paid'` como el contenido completo de la tabla.
- **Comprobantes nuevos**: `lib/repositories/payment/payment_repository.dart` genera `LOCAL-${payment.id}` y lo guarda en `payments.receiptNumber`. Por ejemplo, el pago `owner-pay-001` tiene comprobante `LOCAL-owner-pay-001`. Es un identificador local determinista, no una referencia de transacción bancaria. No cambiar esta convención silenciosamente.
- **Método en Firestore**: conservar `paymentMethodId` como identidad del maestro y guardar también `paymentMethodName` como copia legible. Firestore no hace joins con Supabase; no reemplazar el ID por el nombre ni volver a publicar documentos numéricos sin su nombre cuando exista un método del maestro.
- **Históricos sin maestro**: un pago antiguo puede tener `paymentMethodId = NULL` y `method = 'online'`. Eso no equivale a un pago pendiente ni permite inferir crédito, débito o transferencia. Para consultar nombres puede usarse `COALESCE(catalog.name, payments.method, 'Sin definir')` con LEFT JOIN.
- **Fechas en SQLite**: los conversores actuales almacenan microsegundos desde epoch. Al consultar fechas con SQL, convertir con `datetime(paidAt / 1000000, 'unixepoch', 'localtime')`; no tratar esos valores como milisegundos.
- **Persistencia local y remota**: propietario y maestro usan SQLite en el dispositivo; Payment sincroniza los registros del propietario con Cloud Firestore sin enviar pagos a Supabase. Firestore usa su cola local sin conexión y no exige otra migración Floor. El administrador todavía usa el store en memoria. El historial del cliente fue retirado por decisión del usuario, no queda pendiente de migración.
- **Configuración**: Payment recibe `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` mediante `--dart-define`. La sincronización requiere una sesión Firebase real, no autenticación hardcodeada, y Payment no admite un modo demo. No copiar valores por defecto de otros módulos ni introducir credenciales en archivos versionados. La clave publicable no es `service_role` y no reemplaza RLS.
- **Inspección de la base**: la original está en `/data/data/com.example.machuco/databases/machuco.db`. Las copias extraídas para DB Browser son fotografías, no bases conectadas al emulador. Cerrar la app antes de extraer y copiar también `-wal`/`-shm` si existen, manteniéndolos juntos. Una copia en Temp es temporal; no mover ni borrar por ello la original del dispositivo.
