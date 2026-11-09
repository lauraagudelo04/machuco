# Propietarios: persistencia, Supabase y Firestore

## Alcance

El módulo de administración de propietarios (`lib/views/owner_management/`)
combina las tres capas de persistencia acordadas por el equipo:

| Necesidad | Tecnología | Dónde |
|---|---|---|
| Datos de dominio del propietario | **Cloud Firestore** | colección `owners` |
| Caché local y funcionamiento sin conexión | **SQLite (Floor)** | tablas `owners` y `document_types` |
| Maestro de tipos de documento | **Supabase REST** | tabla `document_types` |
| Preferencias de la interfaz | **shared_preferences** | namespace `owners` y `auth` |

La decisión está en `docs/decisions_log.md` (2026-10-27): los catálogos van a
Supabase y los datos de dominio a Firebase. El módulo usa `http` para REST y no
depende de `supabase_flutter`.

## Flujo de la pantalla

1. `OwnerPage` carga el listado desde SQLite y muestra el correo del
   administrador guardado por el login (`AuthPreferences.loadCurrentUserEmail`).
2. `OwnerController.init()` siembra los datos demo la primera vez, recarga la
   tabla local y después intenta la sincronización con Firestore. La nube nunca
   bloquea el listado: si falla, se muestra un banner con «Reintentar».
3. Crear, editar el teléfono o cambiar el estado escribe primero en SQLite; la
   fila nace con `synchronized = 0`. Al terminar, el envío a Firestore se lanza
   en segundo plano.
4. El formulario abre el maestro de indicativos y el de tipos de documento. El
   último indicativo usado se recuerda en `shared_preferences` y se
   preselecciona en la siguiente creación.
5. Eliminar con conexión borra primero el documento remoto y después la fila
   local. Sin conexión la fila se oculta con `pendingDelete = 1` y el borrado se
   reintenta solo cuando vuelve la red.

## SQLite

- `owners`: `id`, `fullName`, `documentType` (nombre del enum), `documentNumber`,
  `email`, `phone` (número nacional), `countryCode`, `countryName`, `address`,
  `isActive`, `synchronized`, `pendingDelete`, `createdAt`, `updatedAt`.
- `document_types`: `id`, `code`, `name`, `pattern`, `example`, `isActive`,
  `sortOrder`. Se siembra con CC, CE, NIT, PAS y TI; es la fuente del selector.
- `synchronized = 0` significa «pendiente de enviar». `OwnerDao.markSynchronized`
  lo pasa a 1 cuando Firestore confirma la escritura.
- `pendingDelete = 1` significa «el usuario lo eliminó sin conexión y falta
  borrarlo en Firestore». La fila no se lista ni cuenta como alta; cuando la
  nube confirma el delete, se borra por completo.
- `OwnerRepository.mergeRemoteOwners` inserta lo que solo existe en la nube y
  actualiza lo ya sincronizado. Un registro local pendiente **nunca** se pisa:
  se sube en el siguiente envío. Un borrado pendiente tampoco se resucita.
- La versión local es la **16**: `document_types` viaja en la 15 y la 15→16
  agrega `pendingDelete` a `owners` con `DEFAULT 0`.

## Supabase: maestro de tipos de documento

La tabla remota se crea con
`supabase/migrations/202611070001_create_document_types.sql`, que se aplica a
mano desde el SQL Editor de Supabase; el archivo no se ejecuta desde la app.

### Estado de aplicación

- Aplicada el **2026-11-08** en el proyecto `ogrbbuwtsyezegkpwtsl`.
- Tabla `public.document_types`: 7 columnas y 5 filas (CC, CE, NIT, PAS y TI),
  con RLS activo y política de solo lectura para `anon` y `authenticated`.
- Verificada con `curl` contra el endpoint REST: responde `200` con los cinco
  tipos ordenados por `sort_order`.
- El maestro de indicativos que consume el formulario es
  `country_phone_codes` (10 filas). `phone_country_codes` es el maestro antiguo
  y quedó vacío; ambos endpoints responden `200`.

```http
GET <SUPABASE_URL>/rest/v1/document_types?select=id,code,name,pattern,example,is_active,sort_order&is_active=eq.true&order=sort_order.asc
apikey: <SUPABASE_ANON_KEY>
Accept: application/json
```

- La clave viaja en el header, nunca en la URL. RLS permite solo lectura pública.
- `DocumentTypeRepository.getActiveDocumentTypes(forceRefresh: true)` consulta
  Supabase, valida las filas, descarta códigos que ya no existen en el enum y
  reemplaza la caché local.
- Sin `forceRefresh` responde con la caché de SQLite.
- Si la red falla o el catálogo llega vacío se conserva la caché; solo se lanza
  `DocumentTypeRepositoryException` cuando no hay ninguna fila local.
- El formulario consulta el refresco al abrirse en segundo plano: pinta la
  caché local de inmediato y conserva el enum como último respaldo.

## Cloud Firestore

- Colección: `owners`, declarada en `FirestoreCollections.owners`.
- El id del documento es el mismo id de la fila SQLite, así que subir dos veces
  el mismo propietario es idempotente.
- Campos: `fullName`, `documentType` (nombre del enum), `documentNumber`,
  `email`, `phone`, `countryCode?`, `countryName?`, `address?`, `isActive`,
  `updatedBy` (uid del administrador) y `updatedAt` asignado por el servidor.
- `OwnerFirestoreDocument` valida tipos, cadenas no vacías y el tipo de
  documento. Un documento inválido se reporta como error de datos, no se
  importa a medias.
- `OwnerCloudRepository` es la interfaz que consume el controlador;
  `FirestoreOwnerCloudRepository` es la implementación real, con timeout de
  10 segundos, errores tipados y mensajes en español.
- Sincronización:
  1. Borrar en Firestore los pendientes de eliminar (`pendingDelete = 1`) y
     quitar la fila local cuando la nube confirma.
  2. Subir los registros con `synchronized = 0` y marcarlos.
  3. Descargar la colección completa.
  4. Mezclar en SQLite sin pisar cambios locales pendientes ni borrados
     pendientes.
- Firestore mantiene su propia cola de escrituras sin conexión. La app agrega
  el tombstone local `pendingDelete` para que el borrado también se reintente.

### Seguridad

`firestore.rules` restringe `/owners/{ownerId}` al rol `admin`. El propietario
no se autogestiona desde la app, por eso la colección no se expone a
`isActiveOwner()`. Las reglas exigen que `updatedBy` sea el uid de la sesión y
que las claves del documento estén en la lista permitida.

Para publicarlas:

```bash
firebase deploy --only firestore:rules
```

## shared_preferences

- `OwnerPreferences` (namespace `owners`) guarda `lastCountryCodeId`: el último
  indicativo elegido. El formulario lo preselecciona al crear un propietario.
- La pantalla de propietarios lee el correo de la sesión con
  `AuthPreferences().loadCurrentUserEmail()` (namespace `auth`) y lo muestra
  como «Sesión: correo@…».
- Ninguna vista importa `shared_preferences` directamente; usan
  `LocalPreferencesService`.

## Comportamiento sin conexión

| Situación | Resultado |
|---|---|
| Se abre la lista sin red | Se muestran los propietarios de SQLite |
| Se crea o edita sin red | Queda guardado con `synchronized = 0` y aparece el aviso |
| Firestore rechaza la escritura | El registro local se conserva y el aviso permite reintentar |
| Se elimina sin red | Se oculta con `pendingDelete = 1`; el borrado se envía solo al volver la red |
| Firestore rechaza un borrado por permisos | El registro local se conserva y se informa; no se reintenta solo |
| Supabase no responde | El formulario usa la caché local de tipos de documento |
| No hay sesión de Firebase | No se sincroniza; el listado local sigue operativo |

## Reintentos automáticos

`OwnerSyncRetryScheduler` (`lib/service/owner/owner_sync_scheduler.dart`) vuelve
a sincronizar sin que el usuario pulse «Reintentar»:

- Solo se activa con fallos de red (`OwnerCloudFailureType.network`). Un
  `permission-denied` o un dato inválido no se reintenta.
- Retroceso de **8 intentos**: 2 s, 5 s, 10 s, 30 s y 60 s desde el quinto.
  Agotados los intentos queda el botón manual.
- Cada intento ejecuta el ciclo completo: borrados pendientes, altas/cambios
  pendientes y pull con merge.
- Se cancela al primer éxito, al `dispose` del controlador y cuando no hay
  sesión de Firebase.
- Además de los timers, la pantalla (`owner_page.dart`) escucha
  `didChangeAppLifecycleState`: al volver del segundo plano intenta sincronizar
  de inmediato.
- El banner muestra el número de intento en curso
  (`autoRetryAttempt`/`autoRetryMaxAttempts`).
- No se agregó ninguna dependencia: se usa `Timer` de Dart; `Math.random` no
  interviene (el retroceso es determinista).

## Configuración

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<proyecto>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<clave-publicable>
```

Los valores por defecto de `SupabaseRoomConfig` apuntan al proyecto de
desarrollo y permiten `flutter run` sin argumentos. Firebase se configura con
los archivos de `firebase_options.dart` / `.firebaserc` que ya usa la app.

> `flutter run` sin argumentos usa las cuentas de prueba quemadas
> (`AUTH_USE_HARDCODED_AUTH_USERS` vale `true` por defecto). Para entrar con
> Firebase Auth hay que agregar
> `--dart-define=AUTH_USE_HARDCODED_AUTH_USERS=false`.

## Pruebas

```bash
flutter test \
  test/models/owner/owner_firestore_document_test.dart \
  test/repositories/document_type/document_type_repository_test.dart \
  test/service/owner/owner_preferences_test.dart \
  test/service/owner/owner_sync_scheduler_test.dart \
  test/database/owner_database_test.dart \
  test/controllers/owner_management/owner_controller_test.dart
```

Las pruebas usan SQLite real aislado, `http.Client` simulado para Supabase y un
doble en memoria de `OwnerCloudRepository`; no escriben en el proyecto Firebase
real.

## Verificación manual

Completada el **2026-11-09** con la app real, en línea y en modo avión.

> Para usar Firebase Auth hay que arrancar sin los usuarios de prueba:
> `flutter run --dart-define=AUTH_USE_HARDCODED_AUTH_USERS=false`. El
> administrador necesita `role: "admin"` y `accountStatus: "active"` en
> `users/{uid}`, y el id de ese documento debe ser igual al UID de Firebase
> Auth; si no coincide, la app cae en rol cliente.

1. ✅ Iniciar sesión como administrador con Firebase Auth.
2. ✅ Abrir Propietarios: debe verse «Sesión: correo@…» y la lista local.
3. ✅ Crear un propietario con conexión: revisar en la consola de Firestore que
   el documento aparece en `owners` y que la fila local queda
   `synchronized = 1`.
4. ✅ Activar modo avión, crear otro propietario: debe guardarse localmente y
   mostrarse el aviso de sincronización con el contador de reintentos.
5. ✅ Recuperar la conexión: la sincronización debe reanudarse sola (sin pulsar
   «Reintentar») y el documento pendiente debe aparecer en Firestore.
6. ✅ Eliminar un propietario con conexión: el documento debe desaparecer de
   Firestore y de la lista local.
7. ✅ Eliminar con el modo avión activo: el propietario desaparece del listado y,
   al volver la conexión, su documento se borra de Firestore.

## Por qué no hay `owners` en Supabase ni carpeta `persistencia/nube`

### Datos de dominio frente a catálogos

La decisión del 2026-10-27 (`docs/decisions_log.md`) separa **datos de dominio**
(Firestore) de **maestros o catálogos** (Supabase). Un propietario es dato de
dominio, igual que el perfil del usuario, así que vive en la colección `owners`.
Las 14 tablas publicadas en Supabase no incluyen `owners`: son catálogos
(`document_types`, `country_phone_codes`, `phone_country_codes`, `review_types`,
`reservation_categories`, `room_included_services`, …) y tablas de otros módulos
(`motels`, `clients`, `invoices`, `subscription_plans`, …).

### Convención de carpetas

La convención vigente del repositorio es `lib/database/repository/<entidad>/`
para el acceso local y `lib/repositories/<entidad>/` para los clientes de nube;
la decisión del 2026-10-20 lo deja escrito para los maestros. El cliente de
Firestore de propietarios vive en `lib/repositories/owner/`. La carpeta
`lib/database/persistencia_nube/` solo aparece en instantáneas locales
abandonadas (commits «untracked files on cline checkpoint» del 2026-11-06, con
un `supabase_sync_service.dart` que nunca se versionó); en `HEAD` estaba vacía y
se eliminó en el commit `7aab56e`.

### Llaves foráneas y esquema SQL completo

- `document_types` es un catálogo independiente: no referencia otras tablas, así
  que no necesita llaves foráneas.
- Un esquema de propietarios en Supabase exigiría una tabla `owners` con
  `document_type_id → document_types(id)` y
  `country_code_id → country_phone_codes(id)`, además de RLS y políticas de
  escritura. Eso duplicaría la colección `owners` de Firestore y contradice la
  decisión vigente, por eso no se creó.
- El SQL versionado por este módulo se limita a
  `supabase/migrations/202611070001_create_document_types.sql`. Los esquemas de
  las otras 13 tablas pertenecen a sus respectivos módulos.

## Fuera de alcance

- `supabase_flutter`.
- Otros módulos (moteles, pagos, reservas, PQRS).
