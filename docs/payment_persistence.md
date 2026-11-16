# Payment: persistencia y maestro de métodos

## Alcance de esta etapa

`PaymentRepository` coordina el DAO de Payment y el maestro de Supabase.
`FirestorePaymentCloudRepository` sincroniza los registros locales del
propietario con Cloud Firestore. El checkout de `payment_method` crea los
pendientes ligados a Booking. Payment no escribe en Supabase ni procesa
cobros bancarios.
`OwnerPaymentController` y «Finanzas de mi motel» consultan primero SQLite,
permiten registrar el pago recibido y después sincronizan con Firebase.
El administrador aún utiliza `PaymentStore` en memoria: su migración
queda pendiente. El historial «Mis pagos»
del cliente y su controlador se eliminaron por decisión del usuario, junto con
sus rutas obsoletas; no forman parte de la app final. Esto no elimina la
selección de método de pago de Reservas ni los registros compartidos de SQLite.

## Flujo del propietario

1. La vista carga únicamente los pagos guardados para el motel actual.
2. «Registrar pago» abre el detalle del cliente, reserva y valor, y consulta
   el maestro mediante el controlador. No selecciona un método automáticamente.
3. El propietario elige cómo recibió el dinero y pulsa «Confirmar pago».
4. Durante la escritura se bloquean el doble envío y el cierre del formulario.
   Si falla, conserva la selección, muestra el error y permite reintentar.
5. Solo después de guardar en SQLite, el pago pasa a «Pagos realizados» y
   muestra el método, fecha y comprobante. Cancelados y reembolsados van en
   «Otros estados».
6. El guardado local no se revierte si Firebase no está disponible. La pantalla
   informa el problema y el botón de actualización permite reintentar.

Ingresos, cantidad recibida, pendiente y clientes frecuentes se calculan con
los registros locales, no con los totales fijos anteriores. El resumen no se
presenta como mensual. Las comisiones se muestran como no calculadas hasta
que exista una regla acordada.

## Pago creado desde Payment_Method

Al finalizar la selección con una reserva real, `PaymentCheckoutController`
(`lib/controllers/payment_method/`) registra el pago de esa reserva con el id
determinista `pay-<id de la reserva>`:

- **«En el Local»:** estado `pending`, sin `paymentMethodId`, `paidAt` ni
  comprobante. El propietario lo confirma después con «Registrar pago» y elige
  el método. La reserva conserva `pending` y `paymentMethod = 'En el Local'`:
  es un lugar de pago, no una prueba de dinero recibido. Se vuelve a Mis reservas,
  no a una factura de pago realizado.
- **Tarjeta:** el formulario es solo una simulación. El checkout real la
  rechaza sin crear un registro `paid` ni confirmar Booking. No existe una
  pasarela aprobada; no se generan comprobantes `CARD-…` nuevos.

El pago se guarda primero en SQLite y después se intenta enviar a Firestore con
`PaymentCloudRepository`. Se exige la sesión del cliente que creó la reserva;
no se inventan identificadores de huéspedes. Si no se conoce el propietario o
Firebase falla, el registro local se conserva y se muestra el aviso. Repetir
«En el Local» vuelve a intentar sincronizar usando el mismo ID, incluso si
se cerró la pantalla. La selección actualiza pago y reserva en una transacción
SQLite, y después una transacción de Firestore actualiza ambos documentos.

`firestore.rules` permite ahora que un cliente activo cree **sus** pagos
(`clientId == request.auth.uid`), únicamente pendientes y sin método. Se permite
repetir el mismo pendiente cambiando solo `updatedAt`; el cliente no puede
acreditar cobros ni leer Payment. El usuario autorizó explícitamente probar y
publicar las reglas en `machuco`, conservando las reglas ya publicadas de
otras ramas. Cada publicación requiere respaldo, comparación y pruebas de
la versión que se va a publicar; no incluye índices, SQL Connect ni cambios
de datos.

`Reservation` aporta `guestId`, `guestName` y `requestId`; este último se usa
como referencia de pagos nuevos. `ownerId` sale de `Motel.ownerId` en SQL
Connect y debe ser el UID real. No se agrega una colección de moteles.

### Contrato de vencimiento y recepción

Decisión explícita del usuario: una reserva que ya eligió «En el Local»
permanece pendiente hasta cancelación explícita por cliente o propietario.
No se cancela a los 15 minutos ni automáticamente al llegar el check-in.
El checkout que todavía no eligió ese lugar sigue venciendo en 15 minutos;
una primera selección tardía se rechaza localmente y en las reglas.

Para pagos `pay-<reserva>`, recibir dinero actualiza en una sola transacción
SQLite el pago y la reserva (`upcoming` antes del check-in, `active` después),
con el método recibido e `invoiceAccessStatus = pending`. Firestore confirma
ambos en una sola transacción. No hay una transacción distribuida entre
SQLite y Firestore: si falla la red, la recepción local no se pierde y debe
reintentarse. Booking reconcilia el registro local durable después de reiniciar
para no sustituir la selección o el comprobante por una copia pendiente antigua.
Una cancelación remota no se resucita; un conflicto de recepción se informa.

El acceso de cobro de Booking para «En el Local» lleva a Finanzas, donde se
elige explícitamente el método del maestro; no asume que todo pago es efectivo.

## Contrato remoto

```http
GET <SUPABASE_URL>/rest/v1/payment_method?select=id,nombre&order=id.asc
apikey: <SUPABASE_PUBLISHABLE_KEY>
Accept: application/json
```

La respuesta esperada es HTTP 200 con una lista JSON no vacía:

```json
[
  {"id": 1, "nombre": "Efectivo"},
  {"id": 2, "nombre": "Tarjeta de crédito"},
  {"id": 3, "nombre": "Tarjeta de débito"},
  {"id": 4, "nombre": "Transferencia bancaria"}
]
```

- Cada `id` debe ser un entero positivo único; `nombre`, un texto no vacío.
- Los nombres se decodifican como UTF-8. Las opciones provienen del servidor;
  la aplicación no fija una lista ni infiere el método de pagos antiguos.
- La clave se envía en el header, nunca en la URL. No se utiliza una clave
  `service_role`; los permisos de lectura del catálogo dependen de RLS.
- Tiempo máximo de espera: 15 segundos. No se reintenta automáticamente.
- Errores de conexión, timeout, permisos, otros estados HTTP, JSON inválido,
  IDs repetidos o una lista vacía permiten recuperar el catálogo local.
- Sin copia local, se devuelve un error de repositorio con un mensaje en
  español. Los cuerpos de error y las credenciales no se incluyen en él.

## SQLite

- `payments`: datos del pago, estado, método, fecha y comprobante.
- `payment_method_catalog`: copia del maestro; `nombre` se mapea a `name`.
- `findPaymentMethods()` intenta actualizar desde Supabase y guarda el resultado
  completo solo después de validarlo. Un resultado remoto inválido no altera
  el catálogo local. Los errores de SQLite no se disfrazan de errores de red.
- La actualización del maestro conserva los IDs históricos para no romper
  vínculos de pagos. El contrato remoto actual no define bajas ni `is_active`;
  el catálogo local conservador tampoco garantiza vigencia sin conexión.
- `createPayment()` inserta, no sobrescribe pagos existentes ni carga datos de
  demostración automáticamente.
- Las consultas por cliente y motel son filtros locales, no autorización de
  backend ni sincronización entre dispositivos.
- `registerLocalPayment()` confirma la recepción de un pago pendiente del motel
  indicado usando un método ya descargado. No requiere conexión a Supabase.
- Se guarda la fecha actual y el comprobante local determinista `LOCAL-<id>`.
  La actualización condicional y la transacción del DAO impiden confirmaciones
  duplicadas, incluso simultáneas. Un pago cancelado o reembolsado no se confirma.
- No se guardan números de tarjetas, CVV, claves bancarias ni tokens de pago.

## Cloud Firestore

- Colección: `payments`, declarada una sola vez en
  `FirestoreCollections.payments`.
- El ID del documento es el ID estable del pago; las escrituras repetidas son
  idempotentes y no crean comprobantes ni documentos duplicados.
- Cada documento incluye `ownerId` con el UID de Firebase Auth, `motelId`, los
  datos necesarios para reconstruir `PaymentRecord` y `updatedAt` asignado por
  el servidor. Cuando existe `paymentMethodId`, también guarda
  `paymentMethodName` como copia legible del maestro: Firestore no realiza joins
  con Supabase y el ID se conserva para mantener la identidad referencial. No
  contiene credenciales ni datos bancarios.
- La vista no importa Firebase. `OwnerPaymentController` depende de la interfaz
  `PaymentCloudRepository` y la implementación Firestore traduce errores a
  mensajes seguros en español.
- Al cargar Finanzas se muestran primero los registros de SQLite. Después se
  actualizan las reservas, se descargan los pagos del propietario y motel y se
  mezclan antes de subir cambios locales. Una copia pendiente antigua no
  bloquea el resto de pagos ni reemplaza una recepción remota ya confirmada.
- Las transacciones remotas ligadas a reservas requieren conexión. SQLite es
  la copia durable para reintentar; no se promete una transacción Firestore
  encolada sin conexión. Payment no agrega tablas ni migraciones. Tras integrar
  develop, la versión compartida de Floor es v17 (servicios adicionales).
- Al mezclar datos no se permite que una copia remota pendiente haga retroceder
  un pago local ya procesado. Se acepta `pending` → estado procesado y
  `paid` → `refunded`, además de actualizaciones del mismo estado.
- Para importar un pago con `paymentMethodId`, el maestro de Supabase debe estar
  disponible o existir en la caché SQLite, porque conserva su llave foránea.

### Seguridad

El propietario activo consulta y confirma sus pagos; el administrador conserva
lectura. El cliente activo solo crea o repite su pendiente. El ID canónico y
cliente, propietario, motel, habitación, importe y fecha se contrastan con la
reserva mediante `getAfter`. La selección y la recepción deben tener su
contrapartida en la reserva. Los datos del vínculo son inmutables y no se
permite retroceder `paid` a `pending` ni reemplazar fecha/comprobante de una
recepción ya confirmada. Los documentos históricos existentes conservan su ID;
las altas nuevas usan el ID canónico.

**Límite de seguridad:** esta comprobación asegura coherencia con la reserva,
no precios calculados por un servidor confiable. Booking todavía deja al cliente
crear la reserva con su total y propietario; Firestore no puede consultar SQL
Connect para verificarlos. Una validación autoritativa de disponibilidad, precio
y propietario contra el catálogo requiere coordinación con Booking/Moteles y
lógica confiable de backend; no se inventa una infraestructura nueva en esta rama.

## Configuración en Android

Payment recibe `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` mediante
`--dart-define`; no agrega valores de credenciales al código. En PowerShell,
configura primero las variables en tu terminal (reemplaza el marcador por la
clave publicable que te compartieron, sin guardarla en un archivo versionado):

```powershell
$env:SUPABASE_URL = 'https://ogrbbuwtsyezegkpwtsl.supabase.co'
$env:SUPABASE_PUBLISHABLE_KEY = 'PEGA_AQUI_LA_CLAVE_PUBLICABLE'
```

Después ejecuta con una sesión Firebase real. El flavor por defecto es dev
(`co.machuco.app.dev`); no comparte los datos de la antigua com.example.machuco.
Consulta docs/auth/android-setup.md para la firma privada de Google/GitHub:

```powershell
flutter run -d emulator-5554 "--dart-define=SUPABASE_URL=$env:SUPABASE_URL" "--dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY"
```

La URL debe ser una base HTTPS sin usuario, query ni fragmento. Tras cambiar
`--dart-define` hay que detener y volver a ejecutar la app, no solo hot reload.
La clave publicable se puede distribuir con una app cliente; no sustituye RLS
ni debe confundirse con un secreto del servidor.

### Datos reales

Payment ya no importa fixtures mediante `PAYMENT_USE_DEMO_DATA`. Al abrir
Finanzas elimina de SQLite los IDs históricos `pay-001` a `pay-003` y
`owner-pay-001` a `owner-pay-003` antes de sincronizar, evitando que datos de
presentación regresen a Firestore. Una base sin pagos reales muestra
«Sin pagos guardados». Los pendientes nuevos provienen exclusivamente de una
reserva real elegida por su cliente; no se inventan transacciones.

## Pruebas

```powershell
flutter test --no-pub test/models/payment/payment_firestore_document_test.dart test/database/payment_database_test.dart test/repositories/payment/payment_repository_test.dart test/controllers/payment/owner_view/owner_payment_controller_test.dart test/widgets/payment/owner_payment_page_test.dart
flutter test --no-pub test/repositories/payment/reservation_payment_integration_test.dart test/controllers/payment_method/payment_method_checkout_controller_test.dart test/service/booking/booking_service_test.dart
# En test_rules (solo demo-machuco, nunca el proyecto compartido):
npm run test:emulator
```

Las pruebas inyectan `http.Client`, repositorios Firebase falsos y usan SQLite
real aislado. Comprueban el contrato HTTP, la recuperación local, la conversión
de documentos Firestore y la sincronización sin escribir en Supabase ni en el
proyecto Firebase real.
Los widget tests verifican selección explícita, carga y errores del maestro,
cancelación, reintento de guardado, bloqueo del doble envío y texto al 200 %.
Por preferencia del usuario, las validaciones se ejecutan mediante un subagente
GPT-6 Luna Fast.

El usuario confirmó conservar la política de eliminación ya publicada:
administrador activo puede eliminar perfiles de clientes/propietarios, pero
no administradores. Se corrigió la expectativa contradictoria de
`users.rules.test.mjs` y se agregaron casos de denegación para otros usuarios,
administradores deshabilitados y administradores con contraseña temporal.
No se amplían permisos de eliminación ni se borran perfiles durante las pruebas.

### Publicación de reglas

La comparación previa con la versión remota detectó bloques de
`additionalServices` y `motels` que no estaban en la referencia local. Se
conservaron tal como estaban publicados y se añadieron pruebas de regresión
en `shared_collections.rules.test.mjs`. El resto de cambios remotos previstos
se limita al contrato de `payments` y `reservations`.

El despliegue autorizado es exclusivamente:

```powershell
firebase deploy --only firestore:rules --project machuco --non-interactive
```

Respaldar antes la fuente y el identificador del ruleset remoto, volver a
comprobar que ese identificador no cambió durante las pruebas y verificar
después que la versión publicada coincide con el archivo local. No probar
creando pagos o usuarios ficticios en el proyecto compartido.

#### Publicación verificada

- Proyecto `machuco`, base `(default)`, release `cloud.firestore`.
- Publicado el `2026-11-10T04:06:40Z`, exclusivamente Firestore Rules.
- Ruleset publicado: `73a9bc51-a254-4bc2-8c2c-8a70ce8b786e`.
- Ruleset anterior respaldado: `c39ba49d-ec07-497e-8356-469015cebbf2`.
- Respaldo local temporal: `Temp/opencode/machuco-rules-before-1794283410492/`
  (fuente anterior y `release.json`; no contiene credenciales).
- La versión remota no cambió entre respaldo y despliegue. La lectura posterior
  confirmó que la fuente remota coincide con `firestore.rules` local.
- Prevalidación: 125/125 pruebas en `demo-machuco`, 0 fallos; compilación del
  servicio de reglas exitosa. Se conservaron los bloques publicados de las
  otras ramas. No se desplegaron índices/SQL Connect ni se modificaron datos.
- Pendiente: prueba funcional con las cuentas reales de cliente y propietario
  en dos dispositivos; la publicación no equivale a esa prueba ni a una pasarela.

La integración posterior de `develop` (`ba5a2bc`) conserva también las reglas
de facturas y los cambios de servicios adicionales de esa rama. Este archivo
local ya no debe confundirse con la fuente de la publicación anterior: esta
sincronización de Git no vuelve a desplegar reglas ni SQL Connect.

### Comprobación manual pendiente en dos dispositivos

1. Cliente real: crear reserva y elegir «En el Local»; comprobar pendiente,
   sin método ni comprobante, incluso después de 15 minutos y reiniciar.
2. Propietario real en otro dispositivo: actualizar Finanzas del mismo motel,
   elegir el método recibido y confirmar una sola vez.
3. Reiniciar ambos: comprobar pago `paid`, `LOCAL-pay-<reserva>` y reserva
   vigente con el método recibido. Intentar una confirmación duplicada.
4. Repetir con pérdida de conexión y reintento explícito. Una recepción local
   no equivale a sincronización exitosa; los conflictos deben quedar visibles.
5. Cancelar una reserva pendiente: no debe resucitar ni admitir recibir dinero.
