# Persistencia de moteles

## Origen remoto
- Tabla `public.motels` en Supabase.
- Consulta REST: `GET {SUPABASE_URL}/rest/v1/motels?select=*&order=name.asc`
- Headers: `apikey` (no se usa `Authorization: Bearer` con la clave publishable).
- Escritura: `POST`/`PATCH` con `Prefer: return=representation`. `PATCH` por `?id=eq.{id}`.
- Errores: 409 por NIT duplicado -> mensaje "Ya existe un motel con ese NIT". Respuestas vacías en PATCH se tratan como error.
- No hay DELETE; la inhabilitación es con `is_available = false`.

## Tabla local (SQLite/Floor)
- Entidad: `lib/database/model/motel/motel_entity.dart` (`@Entity(tableName: 'motels')`)
- Columnas: `id`, `owner_id`, `name`, `email`, `room_count`, `nit`, `address`, `phone`, `description`, `general_location`, `payment_methods_json`, `image_urls_json`, `is_available` (INTEGER 0/1)
- DAO: `lib/database/repository/motel/motel_dao.dart` (`findAll`, `findById`, `upsert`, `upsertAll`, `deleteAll`, `replaceAll`)
- `AppDatabase` versión 10 con `MotelEntity`, `MotelDao`, `migration9To10`

## Comportamiento offline
- `MotelRepository.getMotels()`: intenta red primero, guarda en caché con `replaceAll`. Si falla o hay error de Supabase, devuelve caché. Si no hay caché, lanza `MotelRepositoryException`.
- `addMotel`/`updateMotel`/`setAvailability`: requieren red/configuración; actualizan caché con `upsert` tras respuesta exitosa.
- Decodificación con `utf8.decode(response.bodyBytes)`.

## Políticas RLS
- `SELECT`/`INSERT`/`UPDATE` permitidos para `anon` (según migración). No hay política de DELETE.

## Integración
- `MotelController` mantiene comportamiento mock por defecto (`MotelController()`). `MotelController.persistent()` usa repositorio real con credenciales desde `SupabasePhoneCountryCodeConfig`.
- Vistas del propietario usan `MotelController.persistent()` con manejo de errores (SnackBar) y restauración de estado en toggle.
