# Propietarios: persistencia, Supabase y Firestore

## Alcance

El módulo de administración de propietarios (`lib/views/owner_management/`)
combina las tres capas de persistencia acordadas por el equipo:

| Necesidad | Tecnología | Dónde |
|---|---|---|
| Datos de dominio del propietario | **Cloud Firestore** | colección `users` (`role = owner`) |
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
3. Crear un propietario crea también su cuenta de acceso, así que **exige
   conexión**: el panel pide el correo, genera una contraseña temporal y crea
   `users/{uid}` con `role = owner` y el estado inicial que elija el
   administrador (activo o pendiente de aprobación). Editar o cambiar el estado
   sí es offline-first: SQLite queda con `synchronized = 0` y el envío se lanza
   en segundo plano.
4. El formulario abre el maestro de indicativos y el de tipos de documento. El
   último indicativo usado se recuerda en `shared_preferences` y se
   preselecciona en la siguiente creación.
5. Eliminar con conexión borra primero el documento remoto y después la fila
   local. Sin conexión la fila se oculta con `pendingDelete = 1` y el borrado se
   reintenta solo cuando vuelve la red.

## SQLite

- `owners` (caché local de `users/{uid}`): `id` = **uid**, `fullName`,
  `documentType` (nombre del enum), `documentNumber`, `email`, `phone` (número
  nacional), `countryCode`, `countryName`, `address`, `isActive`,
  `accountStatus`, `synchronized`, `pendingDelete`, `createdAt`, `updatedAt`.
- `document_types`: `id`, `code`, `name`, `pattern`, `example`, `isActive`,
  `sortOrder`. Se siembra con CC, CE, NIT, PAS y TI; es la fuente del selector.
- `synchronized = 0` significa «pendiente de enviar». `OwnerDao.markSynchronized`
  lo pasa a 1 cuando Firestore confirma la escritura.
- `accountStatus` guarda el estado de la cuenta tal como está en Firestore
  (`active`, `pending_approval`, `disabled`...). `isActive` se deriva de él.
- Los datos demo (ids `owner-...`) se marcan como sincronizados y **nunca** se
  envían: crearlos en Firebase implicaría cuentas de mentira.
- `pendingDelete = 1` significa «el usuario lo eliminó sin conexión y falta
  borrarlo en Firestore». La fila no se lista ni cuenta como alta; cuando la
  nube confirma el delete, se borra por completo.
- `OwnerRepository.mergeRemoteOwners` inserta lo que solo existe en la nube y
  actualiza lo ya sincronizado. Un registro local pendiente **nunca** se pisa:
  se sube en el siguiente envío. Un borrado pendiente tampoco se resucita.
- La versión local es la **18**: la 14→15 crea `owners` (con
  `countryCode`/`countryName`) y `document_types` sembrada; la 15→16 agrega
  `pendingDelete`; la 16→17 reconcilia una base v16 de esta rama antes del
  merge; y la 17→18 agrega `accountStatus`. Todas son idempotentes.

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

## Cloud Firestore: `users/{uid}`

Un propietario **es un usuario registrado**: vive en `users/{uid}` con
`role = 'owner'`, igual que clientes y administradores. No existe una colección
`owners`; la anterior quedó obsoleta y se borra a mano desde la consola.

| Campo del perfil | Origen |
|---|---|
| `role` | `'owner'` |
| `accountStatus` | lo elige el admin al crear (`active` o `pending_approval`); luego `active`/`disabled` |
| `fullName`, `email` | formulario (el correo no se edita después) |
| `phoneNumber` | indicativo + número nacional |
| `phoneCountryCodeId` | id del maestro de indicativos |
| `phone` | número nacional (solo lo usa el módulo) |
| `documentType` | enum del selector (`citizenshipCard`, `taxId`...) |
| `documentNumber` | número de documento |
| `nit`, `personType` | espejo de `documentNumber`/`documentType` (`taxId` → `juridica`) para que el documento siga siendo válido para el registro y la aprobación |
| `countryCode`, `countryName`, `address` | datos de contacto legales |
| `mustChangePassword` | `true` al crear: la cuenta nace con contraseña temporal |
| `createdBy`, `createdAt`, `updatedBy`, `updatedAt` | auditoría |

- **Crear**: `AuthAccountProvisioner` crea la cuenta en Firebase Auth (app
  secundaria, sin cerrar la sesión del administrador) con
  `TemporaryPasswordGenerator`; después se escribe `users/{uid}`. Si la
  escritura falla se hace `rollback` de la cuenta. La contraseña temporal se
  muestra **una sola vez** en el resumen del formulario.
- **Editar**: se actualizan nombre, documento, dirección y teléfono; el correo,
  el rol y el estado no se tocan desde esa pantalla.
- **Estado**: activar/desactivar escribe solo `accountStatus`. Las cuentas
  `pending_approval` se resuelven con el módulo de aprobación existente, no con
  el interruptor.
- **Listar**: `where('role', '==', 'owner')`; el orden y los filtros se aplican
  en la app (no hace falta un índice compuesto).
- **Eliminar**: borra el documento `users/{uid}`. La cuenta de Firebase Auth
  **no** se puede borrar desde el cliente (no hay Admin SDK): queda huérfana y
  su correo sigue tomado; se elimina desde la consola cuando haga falta. Es la
  misma limitación documentada para `anonymizeAdministrator`.
- `OwnerUserDocument` tolera los perfiles creados antes de este módulo (solo
  `fullName`, `email`, `phoneNumber`, `role`, `accountStatus`): quedan con
  documento vacío («Sin documento registrado») y se pueden completar al
  editarlos. Un documento realmente ilegible se omite y no tumba el listado.
- `FirestoreOwnerCloudRepository` implementa `OwnerCloudRepository` con timeout
  de 10 segundos, errores tipados (incluido `emailInUse`) y mensajes en español.
- Sincronización: borrar los `pendingDelete`, subir los `synchronized = 0`
  (update + cambio de estado), descargar `users` y mezclar en SQLite sin pisar
  cambios locales ni borrados pendientes.

### Seguridad

`firestore.rules` conserva las reglas de `users` y agrega:

- `isAdminOwnerCreation(uid)`: un admin activo crea un `role = owner` con los
  campos legales, `mustChangePassword = true`, `createdBy` y
  `createdAt == request.time`.
- `isAdminOwnerEdit()`: un admin activo edita los datos legales y de contacto;
  nunca el correo, el rol ni el estado.
- `allow delete`: un admin activo borra cuentas que no son de administrador.
  Los administradores no se borran: se anonimizan.

`nit` debe ser igual a `documentNumber` y `personType` coherente con el tipo de
documento; el resto de campos queda en la lista permitida.

Para publicarlas (y los índices):

```bash
firebase deploy --only firestore:rules,indexes
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
| Se edita sin red | Queda guardado con `synchronized = 0` y aparece el aviso |
| Se crea sin red | Se informa que hace falta conexión (la cuenta de acceso no se puede crear offline) |
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

> `flutter run` usa siempre Firebase Auth: las cuentas quemadas
> (`AUTH_USE_HARDCODED_AUTH_USERS`) se retiraron con el módulo de
> administradores. El usuario administrador necesita `role: "admin"` y
> `accountStatus: "active"` en `users/{uid}`.

## Pruebas

```bash
flutter test \
  test/models/owner/owner_user_document_test.dart \
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

> El administrador necesita `role: "admin"` y `accountStatus: "active"` en
> `users/{uid}`, y el id de ese documento debe ser igual al UID de Firebase
> Auth; si no coincide, la app cae en rol cliente.

1. ✅ Iniciar sesión como administrador con Firebase Auth.
2. ✅ Abrir Propietarios: debe verse «Sesión: correo@…» y la lista local.
3. Crear un propietario con conexión: aparece en `users` con `role = owner`,
   el resumen muestra la contraseña temporal una sola vez y la fila local queda
   `synchronized = 1`.
4. Activar modo avión y editar un propietario: el cambio queda local con aviso
   y contador de reintentos.
5. Recuperar la conexión: la sincronización se reanuda sola y el cambio llega a
   `users`.
6. Eliminar un propietario con conexión: el documento desaparece de `users` y
   de la lista local.
7. Eliminar con el modo avión activo: el propietario desaparece del listado y,
   al volver la conexión, su documento se borra de `users`.

## Por qué no hay `owners` en Supabase ni carpeta `persistencia/nube`

### Datos de dominio frente a catálogos

La decisión del 2026-10-27 (`docs/decisions_log.md`) separa **datos de dominio**
(Firestore) de **maestros o catálogos** (Supabase). Un propietario es un perfil
de usuario con datos legales, así que vive en `users/{uid}` de Firestore.
Las tablas publicadas en Supabase no incluyen propietarios: son catálogos
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
  escritura. Eso duplicaría el documento `users/{uid}` de Firestore y
  contradice la decisión vigente, por eso no se creó.
- El SQL versionado por este módulo se limita a
  `supabase/migrations/202611070001_create_document_types.sql`. Los esquemas de
  las otras 13 tablas pertenecen a sus respectivos módulos.

## Fuera de alcance

- `supabase_flutter`.
- Otros módulos (moteles, pagos, reservas, PQRS).
