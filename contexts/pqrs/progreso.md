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
