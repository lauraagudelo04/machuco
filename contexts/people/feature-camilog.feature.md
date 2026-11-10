# Contexto — Payment (rama: feature-camilog)

## Roles de usuario que atiende esta funcionalidad

Propietario y Administrador del sistema. El cliente participa en la selección
de método de pago de Reservas/Payment_Method, no mediante un historial de Payment.

Feature: Pagos de reservas y pago en el local

  Scenario: Identificar la opción de pagar en el establecimiento
    Given la pantalla Método de pago de Payment_Method
    When se muestran las opciones de pago de la reserva
    Then la opción antes llamada Efectivo muestra exactamente «En el Local»
    And Tarjeta se identifica como simulación y no acredita pagos reales

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
    Then solo el propietario activo asociado puede confirmar la recepción de sus pagos
    And el cliente activo solo puede crear o reintentar su pendiente vinculado a una reserva
    And el administrador puede leerlos
    And el cliente no obtiene un historial de Payment

  Scenario: Manejar un catálogo no disponible
    Given que Supabase no responde
    When se consultan los métodos de pago
    Then se utiliza el catálogo local si existe
    And si no existe se informa el problema y se permite reintentar

  Scenario: Elegir pagar en el establecimiento con una reserva real
    Given una reserva pendiente del cliente autenticado guardada en SQLite
    When elige «En el Local» antes de vencer el checkout
    Then se guarda un único pago pay-<reserva> pendiente y sin método ni comprobante
    And la reserva conserva pending y paymentMethod «En el Local»
    And ambas escrituras locales son atómicas
    And vuelve a sus reservas, sin presentar una factura de dinero recibido

  Scenario: Conservar la reserva hasta cancelación explícita
    Given una reserva pendiente que ya eligió «En el Local»
    When pasan los 15 minutos o llega la hora de entrada sin recibir dinero
    Then no se cancela automáticamente ni se considera pagada
    And cliente o propietario pueden cancelarla explícitamente

  Scenario: Reintentar una sincronización fallida
    Given un pago pendiente guardado cuya sincronización falló
    When el cliente vuelve a finalizar la misma elección, incluso después de reiniciar
    Then se vuelve a intentar sincronizar sin crear otro pago ni ocultar un fallo

  Scenario: Recibir dinero y actualizar la reserva
    Given un pago de una reserva pendiente con elección «En el Local»
    When el propietario registra el método recibido
    Then pago y reserva se actualizan en una sola transacción SQLite
    And el comprobante es LOCAL-<id del pago>
    And Firebase confirma pago y reserva en una sola transacción remota
    And si falla la red el comprobante local se conserva y se informa el reintento

  Scenario: No acreditar el sandbox de tarjeta
    Given el formulario de tarjeta de demostración
    When finaliza la simulación de una reserva real
    Then no se crea un pago paid ni se confirma la reserva como pagada

  Scenario: Validar el vínculo remoto del pago
    Given una reserva y un pago con sus identificadores reales
    When se intenta crear el pago en Firestore
    Then debe coincidir el cliente, propietario, motel, habitación, importe y fecha con la reserva
    And el cliente solo crea o reintenta el mismo pendiente, sin acceso de lectura a Payment

  Scenario: Consultar el catálogo real desde el cliente
    Given un cliente autenticado y moteles habilitados en SQL Connect
    When abre o actualiza la lista de moteles
    Then consulta ListAvailableMotels mediante el controlador persistente
    And ve los moteles disponibles de distintos propietarios con sus UUID reales
    And no se sustituye un fallo por la lista de ejemplo

  Scenario: Conservar la identidad del motel al reservar
    Given un motel real seleccionado del catálogo
    When navega al detalle, las habitaciones y el formulario de reserva
    Then conserva el ID del motel y el motelId de la habitación
    And el formulario consulta GetMotelById y usa el nombre real
    And si no logra consultar un motel disponible informa el error y permite reintentar

## Alcance técnico

- **Carpetas donde trabajo**: lib/models/payment/, lib/repositories/payment/, lib/controllers/payment/, lib/views/payment/, test/database/ y pruebas específicas de Payment. Contrato y guía de configuración en docs/payment_persistence.md.
- **Archivo común autorizado**: lib/database/app_database.dart y su código generado, con migraciones que conserven los demás módulos.
- **Archivos comunes Firebase autorizados**: FirestoreCollections para registrar `payments` y firestore.rules para protegerla. Firebase ya se inicializa en main.dart y no se vuelve a configurar desde esta rama.
- **Depende de**: maestro remoto payment_method de Supabase, AppDatabase compartida, Firebase Auth, Firestore, modelos y persistencia de Booking y el checkout de Payment_Method. Moteles ya usa SQL Connect; Payment no se migra a ese backend.
- **Integración autorizada en esta conversación**: cambios puntuales en checkout de Payment_Method; contrato, vencimiento y reconciliación de Booking; acceso de cobro del propietario hacia Finanzas y sus argumentos en routes.dart; reglas y pruebas de ambas colecciones. No reorganizar módulos ni cambiar otras reglas de negocio.
- **Herramientas comunes**: build.yaml limita Floor a AppDatabase para evitar que su analizador antiguo procese sintaxis nueva de otras pantallas. No cambiar dependencias por ese motivo.
- **Excepción puntual autorizada por el usuario**: diagnosticar y corregir el fallo al guardar moteles en SQL Connect para desbloquear la prueba manual. Limitarse al repositorio/gateway de Moteles y sus pruebas; no cambiar el catálogo de cliente ni crear registros de prueba en la nube por cuenta del agente. No desplegar SQL Connect sin autorización adicional.
- **Resultado de esa intervención**: se conservaron errores GraphQL anidados y diagnóstico debug sanitizado del gateway, con 14 pruebas puntuales aprobadas. Después de actualizar solo la app de propietario conservando su sesión, el usuario confirmó que pudo crear el motel, habitaciones, productos y servicios. No se modificaron autenticación ni permisos de SQL Connect. Se observó un 403 en consultas del menú, pero no se demostró que fuera la causa del guardado original: no documentarlo como una corrección de permisos. En esa intervención el catálogo del cliente quedó fuera; después el usuario autorizó expresamente la conexión siguiente.
- **Conexión del catálogo cliente autorizada posteriormente**: ClientMotelsPage usa SQL Connect real con refresco, error/reintento/vacío y sin filtrar por propietario. El ID se conserva en las rutas existentes hacia detalle/habitaciones; CreateBookingPage resuelve ese UUID con el controlador persistente antes de permitir reservar. Añadir pruebas de catálogo y metadatos de reserva y actualizar únicamente el emulador cliente. No cambiar la sincronización de productos, servicios o habitaciones, ni reglas, ni crear reservas por cuenta del agente.
- **Verificación de esa conexión**: 27 pruebas focalizadas y 918 Flutter completas aprobadas; análisis dirigido sin avisos. APK instalado en emulator-5554 conservando la sesión. Se comprobó visualmente que el motel creado por el usuario aparece en el catálogo real; emulator-5556 no se actualizó ni se crearon reservas. La sincronización de habitaciones entre dispositivos sigue siendo un flujo separado, no darla por validada por ver el motel.
- **Integración Git posterior**: develop se incorporó hasta `ba5a2bc`, conservando SQLite v17, servicios adicionales, facturas y registro espejo de moteles. Se resolvió el conflicto de firestore.rules manteniendo el bloque de facturas además de Payment/Reservas. Esta integración no publica reglas ni reinstala las apps de los emuladores. El commit solicitado excluye la eliminación local previa de android/key.properties.example y los cuatro archivos generados de plugins que ya estaban modificados antes del trabajo.
- **Validación posterior a integrar develop**: 938 pruebas Flutter y 125 pruebas de reglas aprobadas. Análisis completo: 0 errores, 0 warnings y 63 infos. Las pruebas de reglas se ejecutaron únicamente contra demo-machuco; no se desplegaron cambios al proyecto compartido.
- **Fuera de alcance**: integración de una pasarela, escrituras en Supabase, nuevas colecciones, migración del administrador de Payment y una política automática de inasistencia. No reinicializar Firebase ni reemplazar su configuración.
- **Despliegue autorizado en esta intervención**: el usuario autorizó explícitamente probar y publicar únicamente Firestore Rules en `machuco`, respaldando y comparando primero la versión publicada para conservar reglas de otras ramas. No autoriza borrar documentos, desplegar índices/SQL Connect ni futuras publicaciones sin revisión.
- **Política de perfiles confirmada por el usuario**: conservar la regla existente que permite al administrador activo eliminar clientes/propietarios, nunca administradores; estos se anonimizan. La antigua prueba que prohibía toda eliminación ajena se ajusta a esta política e incluye denegación a administradores deshabilitados o con contraseña temporal pendiente.
- **Reglas compartidas preservadas**: al comparar con Firebase se encontraron `additionalServices` y el espejo `motels` publicados pero ausentes en la referencia local. Conservar esos bloques sin cambiar sus permisos; no confundir el espejo con una migración de Payment o Moteles.
- **Publicación realizada**: reglas de Firestore publicadas y releídas en `machuco` el 2026-11-10T04:06:40Z, ruleset `73a9bc51-a254-4bc2-8c2c-8a70ce8b786e`; fuente remota coincide con la local. Suite de reglas 125/125. No se modificaron documentos ni índices. Registro y respaldo en docs/payment_persistence.md; prueba Android en dos dispositivos aún pendiente.
- **Decisiones autorizadas**: SQLite mediante Floor/sqflite como copia local; Cloud Firestore para sincronizar Payment por propietario y motel; catálogo remoto con id y nombre y todos sus métodos disponibles para Payment. «En el Local» es la etiqueta de la opción de la pantalla de selección, no un reemplazo global de «Efectivo» en Payment ni en el maestro.
- **Entorno de ejecución**: Android en el AVD preferido `Camilo_Pixel10`, con sesión Firebase real y los `--dart-define` de Supabase documentados en docs/payment_persistence.md. No iniciar normalmente con usuarios hardcodeados ni con datos demo; esos modos no representan la app final y la autenticación hardcodeada no sincroniza Firestore.

## Notas para los agentes

- Implementar por etapas: persistencia y pruebas; repositorio y catálogo; controladores y pantallas.
- No asignar un método específico del maestro a pagos históricos que solo indican «online».
- No usar datos de demostración en Payment ni sincronizarlos con el proyecto Firebase compartido.
- No borrar ni recrear la base existente como sustituto de una migración.
- Los fixtures históricos `pay-001` a `pay-003` y `owner-pay-001` a `owner-pay-003` se eliminan de SQLite antes de sincronizar. Los pendientes nuevos nacen del checkout de una reserva real; no inventar pagos para sustituir ese flujo.
- En la vista del propietario, los totales salen de SQLite y las comisiones quedan sin calcular hasta acordar su regla. No mantener los anteriores indicadores fijos como si fueran reales.
- Ejecutar las pruebas mediante un subagente con el modelo openai/gpt-6-luna-fast (GPT-6 Luna Fast), según la preferencia explícita del usuario.
- Por decisión explícita del usuario, eliminar el historial de Payment del cliente («Mis pagos»), su controlador y sus rutas/alias exclusivos. No reintroducirlo ni planificar su conexión a SQLite: no pertenece a la app final. Conservar Payment_Method, los datos y modelos compartidos, y los filtros del repositorio; no borrar pagos existentes.

## Convenciones que deben conservarse en próximas intervenciones

- **Dos momentos distintos**: el cliente elige «En el Local» como lugar de pago; el propietario registra después el método con el que recibió el dinero. Efectivo sigue siendo uno de los métodos del maestro, no el nombre genérico de todos los pagos en el establecimiento.
- **Origen de pendientes**: «En el Local» → pago y reserva pending → recepción por el propietario → pago paid y reserva upcoming/active. Decisión explícita del usuario: la elección se conserva hasta cancelación manual, sin vencimiento automático por inasistencia. Un checkout sin esa elección sigue venciendo en 15 minutos.
- **Estados**: `pending`, `paid`, `refunded` y `cancelled` se conservan diferenciados. No marcar todos los pagos como pagados ni interpretar una consulta filtrada por `status = 'paid'` como el contenido completo de la tabla.
- **Comprobantes nuevos**: `lib/repositories/payment/payment_repository.dart` genera `LOCAL-${payment.id}` y lo guarda en `payments.receiptNumber`. Por ejemplo, el pago `owner-pay-001` tiene comprobante `LOCAL-owner-pay-001`. Es un identificador local determinista, no una referencia de transacción bancaria. No cambiar esta convención silenciosamente.
- **Método en Firestore**: conservar `paymentMethodId` como identidad del maestro y guardar también `paymentMethodName` como copia legible. Firestore no hace joins con Supabase; no reemplazar el ID por el nombre ni volver a publicar documentos numéricos sin su nombre cuando exista un método del maestro.
- **Históricos sin maestro**: un pago antiguo puede tener `paymentMethodId = NULL` y `method = 'online'`. Eso no equivale a un pago pendiente ni permite inferir crédito, débito o transferencia. Para consultar nombres puede usarse `COALESCE(catalog.name, payments.method, 'Sin definir')` con LEFT JOIN.
- **Fechas en SQLite**: fechas de Payment (paidAt, reservationDate) en microsegundos; fechas de ReservationEntity (checkIn, createdAt) en milisegundos. No mezclarlas. Para paidAt en SQL usar `datetime(paidAt / 1000000, 'unixepoch', 'localtime')`.
- **Persistencia local y remota**: tras integrar develop, SQLite usa v17 por las tablas de servicios adicionales; Payment no agrega otra migración. La selección y la recepción ligadas a reservas usan transacciones de Firestore (requieren conexión); si fallan, SQLite conserva los datos para reintento explícito. Booking reconcilia pendientes/comprobantes locales después de reiniciar antes de aceptar una copia remota antigua. El administrador todavía usa memoria y el historial del cliente sigue retirado.
- **Configuración**: Payment recibe `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` mediante `--dart-define`. La sincronización requiere una sesión Firebase real, no autenticación hardcodeada, y Payment no admite un modo demo. No copiar valores por defecto de otros módulos ni introducir credenciales en archivos versionados. La clave publicable no es `service_role` y no reemplaza RLS.
- **Inspección de la base**: dev usa `/data/data/co.machuco.app.dev/databases/machuco.db`; prod usa co.machuco.app. La antigua com.example.machuco conserva su base independiente: no borrarla ni desinstalarla para migrar datos. Las copias para DB Browser son fotografías; cerrar la app y copiar también -wal/-shm si existen. No borrar originales del dispositivo.
