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
    **Pendiente:** hoy solo exigen sesión (falta el rol como custom claim).
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

## Comportamiento offline
- Lecturas: red primero. `getMotels` reemplaza la caché; las demás la
  actualizan con `upsertAll`. Si SQL Connect falla se devuelve la caché
  (`getMyMotels` filtrada por el uid de la sesión). Sin caché se lanza
  `MotelRepositoryException`.
- Escrituras: requieren red; si salen bien actualizan la caché con `upsert`.

## Pruebas
- `test/repositories/motel/sql_connect_motel_repository_test.dart` (gateway
  falso + SQLite en memoria) y `test/repositories/motel/motel_dao_test.dart`.
- Emulador: `npx -y firebase-tools@15.34.1 emulators:start --only dataconnect --project demo-machuco`
  y `flutter run --dart-define=USE_SQL_CONNECT_EMULATOR=true`.
