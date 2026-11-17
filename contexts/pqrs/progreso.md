# Progreso del módulo PQRS (rama feature_josemanuelpavas)

Plan: `contexts/pqrs/plan_implementacion.md`. Una entrada por etapa, máximo 15 líneas.

## Etapa 0 - Verificación y línea base (2026-11-11)
- Estado: completada, sin cambios de código.
- AppDatabase está en la versión 20; `migration17To18` a `19To20` ya existen. PQRS debe usar `migration20To21` (bloqueo Q1 en el plan).
- Migración Supabase `202611100001_create_pqrs_config.sql` presente con las 3 tablas.
- `image_picker` ausente; `http`, `http/testing.dart` y `sqflite_common_ffi` disponibles.
- Línea base analyze: 1 info preexistente (`pqrs_store.dart:22`, unrelated_type_equality_checks).
- Línea base test: 1062 pruebas en verde.
- Flutter 3.44.8, Firebase CLI 15.34.1.
- Pendiente: responder Q1 a Q4 del plan antes de Etapas 2, 4 y 5. La Etapa 1 no depende de ellas.

## Etapa 1 - Modelo y utilidades puras (2026-11-11)
- Estado: completada. Sin commit ni dependencias nuevas.
- `pqrs.dart`: ownerId, resolvedAt, closedBy (PqrsClosedBy client/owner_timeout), authorId en traza, `pqrsConfirmationDeadline` (7 dias), `confirmationDeadline`, `canBeClosedByOwnerTimeout(now)`.
- `PqrsStats`: closedByTimeoutCount, `solutionRate` (renombra resolutionRate), `closureRate` sin cierres por vencimiento; 0 si denominador 0.
- Nuevos: `pqrs_image_format.dart` (formatos por defecto JPEG/PNG/WebP, `pqrsDefaultImageMaxBytes`=921600), `pqrs_settings.dart`, `utils/pqrs_image_validator.dart`, `utils/pqrs_response_date.dart` (`addBusinessDays`).
- Ajustes de compilacion: PqrsStore (semilla con ownerId/authorId/resolvedAt/closedBy), PqrsController (authorId, closedBy, resolvedAt), client_view/pqrs_page (ownerId del motel), timeline, stats panel y system_admin_view/pqrs_page.
- Pruebas nuevas (pqrs_stats, image_validator, response_date): 46 en verde en test/models y test/utils.
- Analyze de lo tocado: solo la info preexistente pqrs_store.dart:22; flutter analyze lib test sin errores.
- La validacion de imagenes en cliente no sustituye las reglas de Firestore (Etapa 3).
- Pendiente de Etapa 2: el controlador aun no reabre (limpia resolvedAt) ni cierra por vencimiento.

## Auditoría Etapas 0 y 1 y respuestas Q1-Q4 (2026-11-16)
- Auditoría: todos los entregables de Etapas 0 y 1 en Hecho. Analyze: solo la info preexistente `pqrs_store.dart:22`. Pruebas en test/models/pqrs y test/utils: 46 en verde.
- Fuera de alcance: `macos/Flutter/GeneratedPluginRegistrant.swift` (autogenerado, firebase_crashlytics); no incluirlo en los commits de PQRS.
- Q1: versión de base = siguiente libre al iniciar la Etapa 4 (hoy 21); renumerar al abrir el PR si hace falta. Detalle en el plan.
- Q2: `ownerId` se lee de Firestore `motels/{id}`; quitar el `?? ''` de `client_view/pqrs_page.dart` en Etapa 2/6.
- Q3: se autoriza tocar `main.dart` para componer el repositorio (Etapa 5).
- Q4: migración de Supabase ya aplicada.
- Sin preguntas abiertas. Siguiente: Etapa 2.

## Etapa 2 - Contrato de repositorio y controlador (2026-11-16)
- Estado: completada. Sin commit ni dependencias nuevas.
- Nuevos: `database/repository/pqrs/pqrs_repository.dart` (contrato, `PqrsSyncState` synced/pendingSync/failed+reason, `PqrsRecord`, `PqrsTraceAppend` atomico, `PqrsFailure` con tipo); `models/pqrs/pqrs_session.dart`; `utils/pqrs_validator.dart` (limites centralizados).
- `PqrsController`: repositorio, sesion y reloj por constructor; sin singleton ni MotelController; carga/error/vacio/reintento; tabla de transiciones completa (reapertura limpia resolvedAt, `closeByTimeout` con plazo de 7 dias). Cada avance = una llamada `appendTrace`.
- Fabrica temporal `legacyShared(role)` + `legacy_in_memory_pqrs_repository.dart`, marcados `TODO(etapa-6): borrar`. Vistas: solo cambio de fabrica, quitar `author`/`clientId` y mover la consulta de moteles del admin a la vista.
- `pqrs_firestore_document.dart` NO se creo: no hace falta para el contrato; queda para la Etapa 3. Se anadio `listAll()` al contrato para el administrador.
- Pruebas: 39 nuevas en `test/controllers/pqrs` (fake en `test/fakes`). pqrs+utils: 85 en verde; `flutter test` completo: 1122 en verde.
- Analyze de lo tocado: solo la info preexistente `pqrs_store.dart:22`.
- Validacion de cliente y roles solo simulan las reglas de Firestore (Etapa 3).
- Pendiente: `ownerId ?? ''` de `client_view/pqrs_page.dart` (Q2) y vistas con estados de carga/error en Etapa 6; la fabrica legacy cambia el rol de una sola sesion compartida.

## Etapa 3 - Firestore y reglas (2026-11-16)
- Estado: completada, sin commit, sin desplegar y sin dependencias nuevas. `FirestoreCollections`: pqrs, traces, photos.
- Nuevos: `database/model/pqrs/pqrs_firestore_document.dart` (mapeo, `in_progress`, closedBy ausente = null, Blob) y `database/repository/pqrs/firestore_pqrs_repository.dart` (un `WriteBatch` por accion, ids `<traceId>_1.._3`, apertura = traza `<id>-open`, `pqrsFailureFromError`).
- `PqrsAttachment` gana `bytes`/`mimeType`/`hasImage`; `PqrsTraceEntry` gana `authorName` (el controlador lo rellena). Las fotos simuladas no se envian.
- `ownerId`: `FirestoreMotelRegistry` solo escribe, asi que el repositorio lee `motels/{id}` con el Firestore inyectado (moteles sin cambios).
- `firestore.rules`: bloque pqrs/traces/photos sobre el deny-all, `isValidPqrsTransition(prev,next,role)`, plazo 7 dias, D14/D17 comentados. `firestore.indexes.json`: 2 indices (clientId y ownerId + createdAt desc), a desplegar.
- Reglas probadas en el emulador (firebase 15.34.1, JDK 21 de Android Studio, deps npm en carpeta temporal fuera del repo): 31/31 en `test_rules/pqrs.rules.test.mjs` (aun no esta en el script `npm test`).
- Pruebas Dart: 26 nuevas en `test/database/pqrs`; `flutter test` completo 1148 (base 1122). Analyze de lo tocado: solo `pqrs_store.dart:22`.
- Sin fake_cloud_firestore: el repositorio no se prueba contra Firestore, solo mapeo y clasificacion de errores.
- Limites: listados sin trazas (el tiempo de primera respuesta del panel necesita `getDetail`); un update de pqrs no puede exigir su traza en el lote; sin conexion Firestore deja el lote en su cache y el commit expira como `connection`: la cola de la Etapa 5 debe usar los mismos ids.

## Etapa 4 - Supabase, Floor y migracion (2026-11-16)
- Estado: completada, sin commit, sin SQL ejecutado y sin dependencias nuevas (image_picker no se agrego). El SQL `202611100001_create_pqrs_config.sql` se reviso y no necesito cambios.
- Version de base: 22 -> 23 con `migration22To23` (solo `CREATE ... IF NOT EXISTS` de las 6 tablas), en `lib/database/pqrs_migration.dart` con constantes from/to. Puede renumerarse al abrir el PR: cambiar las constantes, `@Database(version)` y la lista de migraciones (y regenerar con build_runner).
- Entidades: `PqrsCacheEntry`, `PqrsTraceCacheEntry`, `PqrsOutboxEntry`, `PqrsOutboxPhotoEntry` (una foto por fila, BLOB, FK en cascada), `AllowedImageFormatEntry`, `PqrsTypeEntry`. DAOs: `PqrsDao` (replaceAll, cola: enqueue/removeOutbox/estados/intentos), `AllowedImageFormatDao`, `PqrsTypeDao`.
- Contratos `PqrsValidationRepository` y `PqrsTypeRepository`; implementaciones Supabase network first sobre `SupabaseJsonReader` (nuevo, `http`); resultado `PqrsConfigResult` con origen remote/cache/defaults y mensaje en espanol. Settings en `shared_preferences` clave `pqrsSettings`.
- `app_database.g.dart`: solo se agregaron entidades/DAOs y la version; se anadio `import 'dart:typed_data'` en app_database.dart (Uint8List).
- Decisiones: tipos sin ninguna fila utilizable cuentan como fallo (cache o defaults); formatos vacios si se aceptan; code desconocido se ignora y no se cachea.
- Pruebas: 33 nuevas en test/database/pqrs (59 en la carpeta); se subio de 22 a 23 el numero esperado en 5 pruebas ajenas de migracion. `flutter test` completo 1226 en verde.
- Analyze: sin avisos nuevos; quedan preexistentes (p. ej. `pqrs_store.dart:22`).

## Etapa 5 - Repositorio sincronizado y cola (2026-11-17)
- Estado: completada, sin commit ni dependencias nuevas. Base sigue en version 23.
- Nuevos: `database/repository/pqrs/synced_pqrs_repository.dart` (PqrsDao + repositorio remoto inyectados), `database/model/pqrs/pqrs_outbox_codec.dart` y `pqrs_cache_mapper.dart`, `repositories/pqrs/pqrs_repository_provider.dart`.
- Escritura: primero `pqrs_outbox` (+ fotos) en pending_sync, luego envio. Orden por PQRS; una `failed` bloquea las siguientes de esa PQRS. Red/timeout = sigue pending_sync (cuenta intento); permission/validation/notFound = failed con motivo ("La solicitud cambio de estado mientras estabas sin conexion" en acciones de traza).
- Idempotencia: ids fijos (traceId, fotos `_1.._3`) y antes de enviar se consulta `getDetail`; si ya llego se borra la fila sin reenviar (respuesta perdida). Un solo flush por instancia; llamadas concurrentes se unen.
- Lectura: red primero; Firestore reemplaza la cache (replaceAll conservando trazas) y la cola se aplica encima marcada pendiente (los estados solo si no hay una `failed` antes). Sin red con cache: `notice` "Datos guardados, sin conexion"; sin cache: error con reintento. Decision: no es cache-primero con refresco en segundo plano (el contrato es Future, sin stream); la vista lo ve en Etapa 6.
- Extras: `retryAction`/`discardAction` por accion; `retryPending`/`discardPending` por PQRS. Reintentos al leer, en retry y tras cada accion.
- Composicion: `main.dart` agrega `await PqrsRepositoryProvider.useDatabase();` (+ import). `PqrsController.legacyShared` usa el repositorio compuesto (sesion = uid real) y cae al legacy en memoria si no existe; `notice` y descarte de creacion en el controlador.
- Pruebas: 18 nuevas en `test/repositories/pqrs` (DAO real sobre sqflite_ffi + remoto falso). `flutter test` 1244 en verde (base 1226). Analyze de lo tocado: sin avisos.
- Limite: sin red el commit/lectura espera hasta `requestTimeout` (10 s) en el primer intento; el flush offline corta al primer fallo de red.

## Etapa 6 - Vistas y widgets (2026-11-17)
- Estado: completada, sin commit. Unica dependencia nueva: `image_picker ^1.2.4` (pubspec, lock). iOS: `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription` en `ios/Runner/Info.plist`; Android no exige nada. `pub add` regenero registrants de linux, windows y macos (no incluirlos).
- Sesion real: `PqrsController.forCurrentUser()` (uid + perfil de Firestore, solo cuentas activas) y `PqrsControllerGate`; `PqrsPage` enruta por rol; sin sesion "Debes iniciar sesion". Borrados: legacyShared, legacy_in_memory_pqrs_repository, pqrs_store, PqrsProfilePicker, pqrsCurrent*, PqrsAttachment.simulated. Ninguna vista importa Firestore, Supabase ni MotelController.
- Provider ampliado (no se toco main): validacion, tipos, moteles (`getRecommendedMotels` persistente), selector de fotos y resolvedor de sesion.
- Nuevos controladores: `PqrsFormController`, `PqrsPhotoController` (valida con pqrs_image_validator y la configuracion), `PqrsTypeCatalog` (fecha estimada). `service/media/pqrs_photo_picker.dart` envuelve image_picker (calidad y tamano de pqrs_settings).
- Cliente: lista con vacio "Aun no tienes solicitudes", formulario en pagina propia (tipos con description, fotos ocultas si allows_photos=false), detalle con plazo "Si no confirmas antes del <fecha>" y "Confirmar solucion y cerrar". Propietario: bandeja, filtro, "Mi desempeno", plazo vencido, rechazo (min 10), "Cerrar por falta de respuesta" solo vencido. Comunes: aviso final, timeline con fotos reales, marcas Pendiente/No se pudo enviar con Reintentar/Descartar, aviso sin conexion, error con Reintentar, pull-to-refresh y carga al abrir.
- `loadPhotos` ya no marca error de pantalla si falla (las fotos son opcionales). Se corrigio un bug de estado: el composer lleva key para no perder el texto cuando aparece un banner de error.
- Pruebas: 26 nuevas (test/views/pqrs 15, test/controllers/pqrs/pqrs_photo_controller_test 11); `flutter test` 1270 en verde (base 1244). Analyze de lo tocado: sin avisos.
- Pendiente / prueba manual en dispositivo: camara y galeria (permisos, compresion real), flujo offline con cola, plazo de 7 dias con hora del servidor, carga de fotos desde Firestore, 200 % de texto, `createRequest` valida maximo 3 fotos fijo (PqrsValidator.maxPhotos) aunque pqrs_settings permita mas.

## Auditoría final y ajustes previos al commit (2026-11-17)
- Moteles del formulario: ahora salen de las reservas del cliente (`BookingRepositoryProvider.instance`, estados active/upcoming/completed, sin repetir, por nombre) en `pqrs_repository_provider.dart`. No se tocó código de moteles ni de reservas. `PqrsMotelOption.ownerId` es opcional: lo resuelve el repositorio desde Firestore.
- Máximo de fotos: lo manda `pqrs_settings.max_photos` (Supabase). `PqrsController(maxPhotos)` lo valida; `forCurrentUser` lo lee. Tope duro 10 (`PqrsValidator.hardMaxPhotos`, también en `PqrsSettings.fromJson` y en las reglas, ids `<traceId>_1` a `_10`).
- Al arrancar, `useDatabase()` lanza `refreshConfiguration()` (sin esperar) para refrescar formatos, ajustes y tipos en caché; si Supabase falla se usan caché y defaults.
- `pqrs.rules.test.mjs` agregado a `npm test` de `test_rules`; suite completa en emulador: 193/193. Comentario de `motelName` en `pqrs.dart` actualizado.
- Reglas e índices DESPLEGADOS a `machuco` el 2026-11-17 (solo líneas añadidas respecto a develop). `flutter test`: 1278 en verde.
- Pendiente: pruebas en dispositivo (ver Etapa 6) y revisar versión de base 23 al abrir el PR.

## Etapa 8 - Revisión final (2026-11-17)
- Sin hallazgos críticos; no se corrigió código. `flutter analyze`: 104 info, 0 en PQRS. Pruebas PQRS (controllers, views, repositories, database): 150 en verde.
- Importante: no incluir en el commit los registrants regenerados (linux, windows, macos). Menor: `firestore.rules` no ata `photoCount` de la traza al número real de fotos; el tope por foto (900 KB) y tipos coinciden con el SQL.
