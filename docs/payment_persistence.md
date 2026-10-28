# Payment: persistencia y maestro de métodos

## Alcance de esta etapa

`PaymentRepository` coordina el DAO de Payment y el maestro de Supabase.
No depende de la feature `payment_method`, no escribe en Supabase ni procesa
cobros bancarios. `OwnerPaymentController` y «Finanzas de mi motel» ya consultan
SQLite y permiten registrar el pago recibido con un método del maestro.
El administrador aún utiliza `PaymentStore` en memoria: su migración
y la integración con Reservas quedan pendientes. El historial «Mis pagos»
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
5. Solo después de guardar, el pago pasa a «Pagos realizados» y muestra el
   método, fecha y comprobante. Cancelados y reembolsados van en «Otros estados».

Ingresos, cantidad recibida, pendiente y clientes frecuentes se calculan con
los registros locales, no con los totales fijos anteriores. El resumen no se
presenta como mensual. Las comisiones se muestran como no calculadas hasta
que exista una regla acordada.

La elección «En el Local» del cliente todavía NO crea un pago de Payment:
esa conexión con Reservas no forma parte de este cambio. La única modificación
autorizada en Payment_Method sigue siendo la etiqueta de su pantalla de selección.

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

## Configuración en Android

Payment recibe `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` mediante
`--dart-define`; no agrega valores de credenciales al código. En PowerShell,
configura primero las variables en tu terminal (reemplaza el marcador por la
clave publicable que te compartieron, sin guardarla en un archivo versionado):

```powershell
$env:SUPABASE_URL = 'https://ogrbbuwtsyezegkpwtsl.supabase.co'
$env:SUPABASE_PUBLISHABLE_KEY = 'PEGA_AQUI_LA_CLAVE_PUBLICABLE'
```

Después ejecuta:

```powershell
flutter run -d emulator-5554 --dart-define=AUTH_USE_HARDCODED_AUTH_USERS=true "--dart-define=SUPABASE_URL=$env:SUPABASE_URL" "--dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY"
```

La URL debe ser una base HTTPS sin usuario, query ni fragmento. Tras cambiar
`--dart-define` hay que detener y volver a ejecutar la app, no solo hot reload.
La clave publicable se puede distribuir con una app cliente; no sustituye RLS
ni debe confundirse con un secreto del servidor.

### Probar con los pagos de Carlos y Ana

Los pagos de la captura eran ejemplos en memoria, no reservas reales.
Para cargarlos explícitamente en SQLite, añade al comando anterior:

```text
--dart-define=PAYMENT_USE_DEMO_DATA=true
```

La vista muestra un aviso de demostración. Solo importa ejemplos del motel
actual, usando INSERT OR IGNORE: volver a abrirla no revierte pagos registrados
ni cambia sus métodos. Sin esa opción no se crean ejemplos automáticamente;
una base sin pagos muestra «Sin pagos guardados». Los ejemplos ya importados
permanecen guardados aunque luego se desactive la opción.

## Pruebas

```powershell
flutter test --no-pub test/database/payment_database_test.dart test/repositories/payment/payment_repository_test.dart test/controllers/payment/owner_view/owner_payment_controller_test.dart test/widgets/payment/owner_payment_page_test.dart
```

Las pruebas del repositorio inyectan `http.Client` y usan SQLite real aislado.
Comprueban el contrato HTTP, la recuperación local y el registro de pagos sin
escribir datos en el proyecto Supabase.
Los widget tests verifican selección explícita, carga y errores del maestro,
cancelación, reintento de guardado, bloqueo del doble envío y texto al 200 %.
Por preferencia del usuario, las validaciones se ejecutan mediante un subagente
GPT-6 Luna Fast.
