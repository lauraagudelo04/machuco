# Maestro de códigos telefónicos de país

La funcionalidad de administración de moteles consume el maestro
`phone_country_codes` publicado en Supabase. Este documento describe cómo se
consulta, dónde se cachea y cómo configurarlo.

## Origen remoto

- URL base: `https://ogrbbuwtsyezegkpwtsl.supabase.co`
- Endpoint: `GET /rest/v1/phone_country_codes?select=*&order=id.asc`
- Header requerido: `apikey: <SUPABASE_ANON_KEY>`

Verificación rápida desde PowerShell:

```powershell
Invoke-WebRequest `
  -Uri 'https://ogrbbuwtsyezegkpwtsl.supabase.co/rest/v1/phone_country_codes?select=*' `
  -Headers @{ apikey = '<SUPABASE_ANON_KEY>' } -UseBasicParsing
```

> Hoy la tabla remota responde `[]`. La lista se verá vacía hasta que se
> inserten filas en Supabase. El código ya está preparado para mostrarlas.

## Configuración

Las credenciales no se guardan en el repositorio; se inyectan en tiempo de
compilación (`lib/service/phone_country_code/supabase_phone_country_code_config.dart`):

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://ogrbbuwtsyezegkpwtsl.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_Wv16MVxsTzA89lBeocarLQ_YL33Ya_E
```

## Arquitectura

| Capa | Archivo | Responsabilidad |
|---|---|---|
| Entidad | `lib/models/phone_country_code/phone_country_code.dart` | `PhoneCountryCode` (`id`, `country`, `code`) con `fromJson`/`toJson` |
| Config | `lib/service/phone_country_code/supabase_phone_country_code_config.dart` | URL y `apikey` vía `--dart-define` |
| DAO | `lib/database/repository/motel/phone_country_code_dao.dart` | Lee y escribe la tabla local `phone_country_codes` |
| Repositorio | `lib/database/repository/motel/phone_country_code_repository.dart` | Consulta Supabase, cachea y hace fallback a la caché |
| Controlador | `lib/controllers/motel/phone_country_code_controller.dart` | Expone la lista, `isLoading` y `error` a la vista |

## Comportamiento

1. Si hay caché local y no se pide refresco forzado, se devuelve la caché.
2. Si no hay caché, se consulta Supabase con el header `apikey`.
3. La respuesta se guarda en la tabla local `phone_country_codes`.
4. Si la red o Supabase fallan, se devuelve la caché; si tampoco hay caché,
   se lanza `PhoneCountryCodeRepositoryException`.

## Base de datos local

La tabla se crea en `lib/database/app_database.dart`:

- Instalaciones nuevas: `Callback(onCreate: ...)`.
- Bases existentes: `migration6To7` (`ALTER`/`CREATE TABLE`).
- Se expone desde `AppDatabase` como `phoneCountryCodeDao`.

Al cambiar la versión del esquema hay que regenerar el código de Floor:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## Pruebas

```powershell
flutter test test/repositories/motel/
```
