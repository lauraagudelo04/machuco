# Persistencia de moteles

> Desde el 2026-11-09 los moteles están en **Firebase SQL Connect**. La
> versión anterior en Supabase se retiró (ver `docs/decisions_log.md`).
> Guía general para el equipo: `docs/sql_connect.md`.

## Origen remoto (Firebase SQL Connect)
- Servicio `machuco-service` (`us-east4`), base `machuco-database`.
- Tabla `motels`: `dataconnect/schema/motel.gql`. `id` UUID generado por la
  base; `nit` único (`motels_nit_uidx`); `isAvailable` por defecto `true`;
  `createdAt`/`updatedAt` con la hora del servidor.
- Conector `motel` (`dataconnect/motel/`):
  - Propietario: `ListMyMotels`, `CreateMyMotel`, `UpdateMyMotel`,
    `SetMyMotelAvailability`. El dueño sale de `auth.uid`; un motel ajeno
    devuelve 0 filas actualizadas.
  - Administrador: `ListAllMotels`, `AdminCreateMotel`, `AdminUpdateMotel`.
    Exigen el custom claim `role: 'admin'`; sigue pendiente que autenticación
    lo aprovisione. No utilizar ListAllMotels para el catálogo del cliente.
  - Otros módulos: `GetMotelById`, `ListAvailableMotels`.
- No hay borrado; la inhabilitación es con `isAvailable = false`.
- Código generado: `lib/service/sql_connect/motel_connector/` (no editar a
  mano; lo regenera el emulador).

## Capas
- `MotelRepository` (`lib/database/repository/motel/motel_repository.dart`):
  contrato y `MotelRepositoryException`.
- `MotelSqlConnectGateway` / `GeneratedMotelSqlConnectGateway`: aíslan el
  código generado y lo convierten a `Motel`. `sqlConnectErrorMessage`
  traduce errores (NIT duplicado -> "Ya existe un motel con ese NIT"; sin
  sesión -> "Debes iniciar sesión para administrar moteles").
- `SqlConnectMotelRepository`: implementación con caché Floor.
- `MotelController.persistent()` arma el repositorio con `CurrentUser.uid`.
  `MotelController()` sin repositorio conserva los datos de ejemplo para
  otros módulos y pruebas.

## Tabla local (SQLite/Floor)
- Entidad: `lib/database/model/motel/motel_entity.dart` (`@Entity(tableName: 'motels')`)
- Columnas: `id`, `owner_id`, `name`, `email`, `room_count`, `nit`, `address`, `phone`, `description`, `general_location`, `payment_methods_json`, `image_urls_json`, `is_available` (INTEGER 0/1)
- DAO: `lib/database/repository/motel/motel_dao.dart` (`findAll`, `findById`, `upsert`, `upsertAll`, `deleteAll`, `replaceAll`)

## Catálogo real del cliente

- `ClientMotelsPage` utiliza `MotelController.persistent()` por defecto:
  `getRecommendedMotels` delega en `ListAvailableMotels`, que devuelve los
  moteles habilitados de cualquier propietario para un usuario autenticado.
  El controlador solo se sustituye explícitamente en pruebas.
- El botón «Actualizar moteles», el gesto de arrastrar hacia abajo, volver
  del detalle o regresar a la pestaña Moteles vuelven a consultar el catálogo.
  Hay estados de carga, vacío y error con reintento; no se muestran ejemplos
  como sustituto de un error. Las pestañas secundarias se montan al visitarlas
  para no lanzar sus consultas mientras solo se consulta el catálogo.
- La búsqueda incluye nombre, dirección y ubicación general. Las rutas de
  detalle y habitaciones reciben el mismo `Motel` con el UUID del servidor.
  `RoomClientPage` filtra habitaciones/tipos por ese ID y pasa su habitación
  seleccionada al formulario de reserva sin cambiar `motelId`.
- `CreateBookingPage` resuelve el UUID con `GetMotelById` y usa el nombre del
  catálogo. Si la consulta falla o el motel no está disponible, no inventa un
  nombre para registrar la reserva: muestra error/reintento y bloquea el envío.
- El número `roomCount` no crea habitaciones automáticamente. La aparición
  de tipos/habitaciones depende de los registros reales y de su sincronización
  entre dispositivos (Firestore/SQLite), separada del catálogo SQL Connect.
- Este cambio no modifica permisos, esquema SQL Connect ni la sincronización
  de productos o servicios. Una caché sin conexión puede estar desactualizada;
  para verificar un motel recién creado, ambos dispositivos necesitan red.

## Comportamiento offline
- Lecturas: red primero. `getMotels` reemplaza la caché; las demás la
  actualizan con `upsertAll`. Si SQL Connect falla se devuelve la caché
  (`getMyMotels` filtrada por el uid de la sesión). Sin caché se lanza
  `MotelRepositoryException`.
- Escrituras: requieren red; si salen bien actualizan la caché con `upsert`.

## Copia en Firestore (`motels`)
- Las reglas de Firestore no pueden consultar SQL Connect. Cada motel se
  copia en `motels/{motelId}` (mismo UUID) para que otros módulos, como
  habitaciones, lo verifiquen desde Firestore.
- `FirestoreMotelRegistry` (`lib/database/repository/motel/motel_firestore_registry.dart`)
  escribe todos los campos del motel más `updatedAt` después de cada
  creación, edición o cambio de disponibilidad en SQL Connect.
- Regla (bloque propio en `firestore.rules`): leen los usuarios con sesión;
  escriben el administrador y el propietario activo (este solo con su
  propio `ownerId`); no se borran.
- Si Firestore falla, el motel queda guardado en SQL Connect y se muestra
  "El motel se guardó, pero no se pudo registrar para las habitaciones.
  Vuelve a guardarlo para reintentar."
- La regla `room_motels` de habitaciones no se modificó; si esa rama quiere
  usar esta copia, el cambio es suyo.

## Pruebas
- `test/repositories/motel/sql_connect_motel_repository_test.dart` (gateway
  falso + SQLite en memoria) y `test/repositories/motel/motel_dao_test.dart`.
- `test/widgets/motel/client_motels_page_test.dart`: carga, consulta sin
  ejemplos, actualización, búsqueda, error/reintento y UUID al abrir detalle.
- `test/widgets/booking/create_booking_page_test.dart`: resolución del motel
  por el UUID de la habitación y recuperación de un fallo de consulta.
- Validación de esta conexión: 27 pruebas focalizadas y 918 pruebas Flutter
  completas aprobadas, con concurrencia 1 para el entorno de dos emuladores.
  Las pruebas usan repositorios inyectados y no crean datos en Firebase.
- La compilación se instaló en el emulador cliente conservando la sesión y se
  verificó visualmente la aparición del motel creado por el usuario. No se
  modificó la app del propietario ni se crearon reservas durante esa revisión.
- Emulador: `npx -y firebase-tools@15.34.1 emulators:start --only dataconnect --project demo-machuco`
  y `flutter run --dart-define=USE_SQL_CONNECT_EMULATOR=true`.
