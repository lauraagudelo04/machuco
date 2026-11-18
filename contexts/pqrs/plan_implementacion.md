# Plan de implementación PQRS (rama feature_josemanuelpavas)

Spec: `contexts/people/feature_josemanuelpavas.feature.md` (se cita por título de sección).
Verificado el 2026-11-11. Flutter 3.44.8, Firebase CLI 15.34.1.

## Reglas comunes
- Sin commit, add, push, stash ni cambio de rama. Sin desplegar reglas ni ejecutar SQL en Supabase.
- Solo planes gratuitos: Firebase Spark (sin Storage, sin Cloud Functions), Supabase gratuito por REST con `http`.
- Única dependencia nueva permitida: image_picker. Nada de supabase_flutter, connectivity, workmanager ni gestores de estado.
- ChangeNotifier + ListenableBuilder. Vistas sin llamadas a Firestore ni Supabase. Nombres técnicos en inglés y textos visibles en español. Sin hex, radios ni duraciones sueltos: tokens del tema.
- No reorganizar lib/. No tocar moteles, auth ni reservas; si hace falta, DETENTE y pregunta.
- Leer solo el plan, progreso.md y las secciones de la spec indicadas para la etapa.
- Cierre de etapa: flutter analyze de lo tocado sin avisos nuevos, pruebas de la etapa en verde y entrada de 15 líneas o menos en progreso.md.

## Hallazgos que contradicen la spec
| # | Spec dice | Realidad verificada |
|---|---|---|
| H1 | AppDatabase v17; crear `migration17To18` | `lib/database/app_database.dart:49` es **version 20**. `migration17To18` (propietarios y tipos de documento), `18To19` y `19To20` YA existen (líneas 557-585). La nueva es **migration20To21**, versión 21. BLOQUEO (D12). |
| H2 | `docs/decisions_log.md` dice "la próxima es la 16" | Obsoleto; la próxima libre es la 21 (confirmar con el equipo). |
| H3 | Checkbox "solucionada" del cliente | No existe. El cliente solo tiene "Confirmar solución y cerrar" (`client_view/pqrs_detail_page.dart:65`). Nada que borrar. |
| H4 | Propietario comenta sobre `resolved` | Confirmado: `_mutable` solo bloquea finales (`pqrs_controller.dart:182`) y la vista del propietario muestra el composer en `resolved` (`owner_view/pqrs_detail_page.dart:84-97`). |
| H5 | No hay pruebas de PQRS | Confirmado: no hay `test/**/pqrs`. `flutter test` global pasa completo. |
| H6 | Sin `pqrs` en `FirestoreCollections` ni en reglas | Confirmado. Deny-all en `firestore.rules:1094`; el bloque nuevo va encima de la línea 1092. |
| H7 | `image_picker` pendiente | Confirmado ausente. `http ^1.2.2` existe, `package:http/testing.dart` se usa en 3 pruebas y `sqflite_common_ffi ^2.4.4` está en dev_dependencies. |
| H8 | Migración Supabase con 3 tablas | Confirmado: `supabase/migrations/202611100001_create_pqrs_config.sql` (allowed_image_formats, pqrs_settings, pqrs_types, RLS solo lectura). |
| H9 | Llamada a MotelController desde la vista | Confirmado en `client_view/pqrs_page.dart:33,81` y también en el controlador (`pqrs_controller.dart:17-24`). |
| H10 | `SyncedBookingRepository` guarda lo no sincronizado en memoria | Confirmado (`_unsynced`, línea 47). |
| H11 | Sesión (uid, rol, nombre, accountStatus) | No hay singleton de sesión. uid: `CurrentUser.uidOrNull` (`lib/service/firebase/current_user.dart`). Rol, nombre y estado: `FirestoreUserProfileRepository.getProfile(uid)` (`lib/database/repository/auth/user_profile_repository.dart`, modelo `lib/models/auth/user_profile.dart`). `AuthSession` vive en `LoginController.session`. |

## Referencias de patrones (rutas reales)
- `SyncedBookingRepository`: `lib/repositories/booking/synced_booking_repository.dart` (ctor con `local`, `cloud`, `currentUid`, `roleOf`, `ownerIdForMotel`). Composición: `BookingRepositoryProvider.useDatabase()` en `lib/repositories/booking/booking_repository.dart:206`, llamada desde `main`.
- Dueño del motel: `SqlConnectMotelRepository.getMotelById(id)?.ownerId`; `MotelController.getMotelsByOwnerId(ownerId)`; en Firestore `motels/{id}.ownerId`.
- `PhoneCountryCodeRepository`: `lib/database/repository/phone_country_code/supabase_phone_country_code_repository.dart` (ctor `baseUrl`, `apiKey`, `daoProvider`, `httpClient`; REST `/rest/v1/<tabla>`, header `apikey`).
- `MotelDao.replaceAll` (`@transaction`, deleteAll + upsertAll): `lib/database/repository/motel/motel_dao.dart`.
- `LocalPreferencesService` (interfaz abstracta con `namespace`): `lib/service/storage/local_preferences_service.dart`; usar namespace `pqrs`.
- `SupabaseConfig.baseUrl/apiKey/isConfigured`: `lib/service/supabase/supabase_config.dart`.
- `FirestoreCollections` (`abstract final class`, `static const`): `lib/service/firebase/firestore_collections.dart`.
- Reglas: `isValidReservationTransition(previous, next)` en `firestore.rules:274`; helpers `isActiveClient()`, `isActiveOwner()`, `isAdmin()`; reservas en 806-830.
- Tokens: `AppSpacing` s1..s12, `AppRadius` sm/md/lg/xl/xxl/pill, `AppMotion` fast/normal/slow/feedback, `AppOpacity` softFill/selectedFill, `AppColors` (violet, purple, rose, available, reserved, occupied, surface, textPrimary/Secondary/Muted, border), `app_text_styles`, `app_shadows`, `status_badge.dart`, `app_feedback.dart`, `app_dialog.dart`, `app_skeleton.dart`.

## Etapa 1: modelo y utilidades puras
- Modificar `lib/models/pqrs/pqrs.dart` (ownerId, resolvedAt, closedBy, authorId en traza, cierre por vencimiento, `closureRate`). Crear `lib/models/pqrs/pqrs_settings.dart`, `lib/utils/pqrs_image_validator.dart`, `lib/utils/pqrs_response_date.dart`.
- Pruebas: `test/models/pqrs/`, `test/utils/pqrs_image_validator_test.dart`, `test/utils/pqrs_response_date_test.dart`.
- Patrón: `test/models/booking/` y `lib/utils/`. Verificar que `lib/views/pqrs/system_admin_view/` compile.
- Leer: Estado actual; Inconsistencias 8, 9, 10; Máquina de estados; Reglas de validación; Cierre por vencimiento; Validación de imágenes (Qué valida la app, por foto); Catálogo de tipos.

## Etapa 2: contrato de repositorio y controlador
- Crear `lib/database/repository/pqrs/pqrs_repository.dart` y `lib/database/model/pqrs/pqrs_firestore_document.dart`. Modificar `lib/controllers/pqrs/pqrs_controller.dart` (repositorio por constructor, uid/rol/nombre inyectados, estados cargando/error, sin singleton ni `MotelController`). Alinear la matriz de roles (propietario no comenta en `resolved`; comentario del cliente en `resolved` reabre).
- Repositorio falso en memoria en `test/controllers/pqrs/` (patrón: `test/controllers/booking/`, `test/controllers/review/`).
- Leer: Modelo de datos; Máquina de estados; Reglas de validación; Mapa de archivos; Errores (Gherkin).

## Etapa 3: Firestore y reglas
- Modificar `lib/service/firebase/firestore_collections.dart` (pqrs, traces, photos). Crear `lib/database/repository/pqrs/firestore_pqrs_repository.dart` (un `WriteBatch` por acción). Modificar `firestore.rules`: bloques `pqrs`, `traces`, `photos` encima de la línea 1092, `isValidPqrsTransition(prev, next, role)` y plazo `duration.value(7, 'd')`. Sin desplegar.
- Patrón: `FirestoreReservationCloudRepository` y reglas de `reservations`.
- Leer: Modelo de datos; Máquina de estados; Reglas de validación; Almacenamiento de imágenes; Cierre por vencimiento.

## Etapa 4: Supabase, Floor y migración
- Crear entidades y DAOs de las 6 tablas locales de la spec, `lib/database/repository/image_format/supabase_pqrs_validation_repository.dart` y `lib/database/repository/pqrs_type/supabase_pqrs_type_repository.dart`. Modificar `lib/database/app_database.dart` (+ `.g.dart`): `migration20To21`, versión 21 (NO la 18). Agregar `image_picker` a pubspec.yaml.
- Patrón: `PhoneCountryCodeRepository` (pero network first); `MotelDao.replaceAll`; migraciones idempotentes `CREATE TABLE IF NOT EXISTS`; pruebas estilo `test/database/owner_database_test.dart` (sqflite_common_ffi) y `MockClient` de `http/testing.dart`.
- Leer: Persistencia local (Tablas Floor propuestas, Migración de base); Validación de imágenes (toda); Decisiones del módulo D10 a D17.

## Etapa 5: repositorio sincronizado y cola
- Crear `lib/database/repository/pqrs/synced_pqrs_repository.dart` y `pqrs_dao.dart`. Cola en SQLite (no en memoria); estados `pending_sync/synced/failed`; Firestore manda; reintento al abrir, pull-to-refresh y tras cada acción. Composición en un provider propio de PQRS (ver Q3).
- Patrón: `SyncedBookingRepository` (constructor, `_pull`, push en segundo plano).
- Pruebas: `test/repositories/pqrs/`.
- Leer: Persistencia local (Estados de sincronización, Estrategia de lectura, Escritura sin conexión, Conflictos).

## Etapa 6: vistas
- Modificar `lib/views/pqrs/pqrs_page.dart`, `client_view/*`, `owner_view/*` y `lib/widgets/pqrs/*` (adjuntos reales con image_picker, aviso de fecha límite, botón "Cerrar por falta de respuesta", estados vacío/cargando/error, marca "Pendiente de envío"). `system_admin_view/` solo debe compilar. Tocar `lib/routes/routes.dart` solo si cambia la construcción de la página.
- Patrón: `lib/controllers/booking/client_view/client_booking_controller.dart` y `app_feedback.dart`/`app_skeleton.dart`.
- Leer: Escenarios (Gherkin) de las cuatro features; Criterios de aceptación; Estados finales y timeline.

## Eliminar
- `pqrsCurrentClientId` y `pqrsCurrentMotelId` (`lib/models/pqrs/pqrs_store.dart:8,14`; importados en `pqrs_controller.dart:8`, `client_view/pqrs_page.dart`, `owner_view/pqrs_page.dart:18`).
- `lib/widgets/pqrs/pqrs_profile_picker.dart` (PqrsProfilePicker) y su uso en `lib/views/pqrs/pqrs_page.dart:26`.
- `PqrsStore` como fuente: queda solo como semilla de pruebas.
- `PqrsAttachment.simulated` (`pqrs.dart:32`, `pqrs_update_composer.dart:62`, `client_view/pqrs_page.dart:66`, `pqrs_store.dart`).
- Singleton `PqrsController.instance` en vistas: `views/pqrs/pqrs_page.dart:23`, `client_view/pqrs_page.dart:35`, `client_view/pqrs_detail_page.dart:20`, `owner_view/pqrs_page.dart:31`, `owner_view/pqrs_detail_page.dart:20`, `system_admin_view/pqrs_page.dart:28`, `system_admin_view/pqrs_detail_page.dart:21`.
- `MotelController` en la vista (`client_view/pqrs_page.dart:33,81`) y en el controlador (`pqrs_controller.dart:17-24`).
- Comentario del propietario sobre `resolved` (`owner_view/pqrs_detail_page.dart:84-97,184`; permiso en `_mutable`).
- Checkbox "solucionada" del cliente: no existe, nada que borrar.

## Línea base (antes de tocar código)
- `flutter analyze lib/models/pqrs lib/controllers/pqrs lib/views/pqrs lib/widgets/pqrs`: 1 aviso preexistente, info `unrelated_type_equality_checks` en `lib/models/pqrs/pqrs_store.dart:22:19`.
- `flutter test`: 1062 pruebas, todas pasan. Los mensajes "No Firebase App" de `test/widget_test.dart` son ruido esperado.

## Preguntas resueltas (2026-11-16)
- Q1 (Etapa 4): RESUELTA. El número de versión no se fija ahora. Al empezar la Etapa 4: merge de `develop`, leer la versión de `app_database.dart` y usar la siguiente libre (hoy sería 21, `migration20To21`). La migración va en su propio archivo con `from`/`to` como constantes y con `CREATE TABLE IF NOT EXISTS`. Al abrir el PR: merge de `develop` otra vez; si el número fue tomado, renumerar (constantes, `@Database(version)`, lista de migraciones), regenerar `app_database.g.dart` con `build_runner` (no resolver a mano) y hacer un commit nuevo. Anotar el número tomado en `docs/decisions_log.md` y corregir D12.
- Q2 (Etapas 2 y 6): RESUELTA. `ownerId` se lee de Firestore `motels/{id}.ownerId`, no de `MotelController` ni de `SqlConnectMotelRepository`. Reemplaza el `?? ''` provisional de `client_view/pqrs_page.dart`.
- Q3 (Etapa 5): RESUELTA. Se autoriza tocar `main.dart` solo para componer el repositorio de PQRS.
- Q4 (Etapa 4): RESUELTA. `202611100001_create_pqrs_config.sql` ya está aplicado en Supabase (confirmado por el equipo).

## Preguntas abiertas que bloquean
- Ninguna.
