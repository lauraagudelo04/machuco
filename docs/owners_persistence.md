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
5. Eliminar exige borrar el documento remoto antes que la fila local, para que
   el siguiente pull no lo vuelva a insertar.

## SQLite

- `owners`: `id`, `fullName`, `documentType` (nombre del enum), `documentNumber`,
  `email`, `phone` (número nacional), `countryCode`, `countryName`, `address`,
  `isActive`, `synchronized`, `createdAt`, `updatedAt`.
- `document_types`: `id`, `code`, `name`, `pattern`, `example`, `isActive`,
  `sortOrder`. Se siembra con CC, CE, NIT, PAS y TI; es la fuente del selector.
- `synchronized = 0` significa «pendiente de enviar». `OwnerDao.markSynchronized`
  lo pasa a 1 cuando Firestore confirma la escritura.
- `OwnerRepository.mergeRemoteOwners` inserta lo que solo existe en la nube y
  actualiza lo ya sincronizado. Un registro local pendiente **nunca** se pisa:
  se sube en el siguiente envío.
- No se agregó ninguna migración: `document_types` viaja en la versión 15 y
  `markSynchronized` es solo una consulta `@Query`.

## Supabase: maestro de tipos de documento

La tabla remota se crea con
`supabase/migrations/202611070001_create_document_types.sql`. El profesor o el
administrador del proyecto debe aplicarla en el panel de Supabase; el archivo no
se ejecuta desde la app.

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
- El formulario pide el refresco al abrirse y mantiene el enum como último
  respaldo.

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
  1. Subir los registros con `synchronized = 0` y marcarlos.
  2. Descargar la colección completa.
  3. Mezclar en SQLite sin pisar cambios locales pendientes.
- Firestore mantiene su propia cola de escrituras sin conexión. La app no
  agrega otra tabla ni cambia la versión de la base.

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
| Se elimina sin red | Se conserva el registro y se informa; se reintenta cuando haya conexión |
| Supabase no responde | El formulario usa la caché local de tipos de documento |
| No hay sesión de Firebase | No se sincroniza; el listado local sigue operativo |

## Configuración

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<proyecto>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<clave-publicable>
```

Los valores por defecto de `SupabaseRoomConfig` apuntan al proyecto de
desarrollo y permiten `flutter run` sin argumentos. Firebase se configura con
los archivos de `firebase_options.dart` / `.firebaserc` que ya usa la app.

## Pruebas

```bash
flutter test \
  test/models/owner/owner_firestore_document_test.dart \
  test/repositories/document_type/document_type_repository_test.dart \
  test/service/owner/owner_preferences_test.dart \
  test/database/owner_database_test.dart \
  test/controllers/owner_management/owner_controller_test.dart
```

Las pruebas usan SQLite real aislado, `http.Client` simulado para Supabase y un
doble en memoria de `OwnerCloudRepository`; no escriben en el proyecto Firebase
real.

## Verificación manual

1. Iniciar sesión como administrador con Firebase Auth.
2. Abrir Propietarios: debe verse «Sesión: correo@…» y la lista local.
3. Crear un propietario con conexión: revisar en la consola de Firestore que el
   documento aparece en `owners` y que la fila local queda `synchronized = 1`.
4. Activar modo avión, crear otro propietario: debe guardarse localmente y
   mostrarse el aviso de sincronización.
5. Recuperar la conexión y pulsar «Reintentar»: el documento pendiente debe
   aparecer en Firestore.
6. Eliminar un propietario con conexión: el documento debe desaparecer de
   Firestore y de la lista local.

## Fuera de alcance

- La tabla `owners` en Supabase: los propietarios son datos de dominio y van a
  Firestore.
- `supabase_flutter`.
- Otros módulos (moteles, pagos, reservas, PQRS).
