# Persistencia y maestro de servicios de habitaciones

El módulo `room` usa SQLite mediante `sqflite` para almacenar habitaciones,
tipos y el último maestro de servicios descargado. `RoomDao` concentra las
operaciones CRUD y `AppDatabase` crea las tablas e índices.

La API clásica de SharedPreferences se mantiene para preferencias simples del
módulo. `RoomController` guarda la marca de tiempo de la última sincronización
con `SharedPreferencesLocalService(namespace: 'rooms')`.

El maestro remoto vive en la tabla pública `room_included_services` de
Supabase. Para crearla y cargar Jacuzzi, Luces, Mini bar y Fogata, ejecute en
el SQL Editor de Supabase:

`supabase/migrations/202610130001_create_room_included_services.sql`

Después de aplicar la migración, el endpoint de lectura es:

```text
GET <SUPABASE_URL>/rest/v1/room_included_services?select=id,name&order=id.asc
```

Ejemplo de consulta:

```bash
curl --request GET \
  "$SUPABASE_URL/rest/v1/room_included_services?select=id,name&order=id.asc" \
  --header "apikey: $SUPABASE_ANON_KEY"
```

La aplicación usa por defecto la configuración pública del proyecto definida en
`lib/service/supabase/supabase_config.dart`, compartida con moteles e indicativos.
Para usar otro entorno, se pueden sobrescribir los valores al compilar
(`SUPABASE_PUBLISHABLE_KEY` también se admite como alternativa a `SUPABASE_ANON_KEY`):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<proyecto>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<clave-publica>
```

`RoomServiceRepository` consulta el endpoint y actualiza el caché local. Si
Supabase no está disponible, devuelve el último maestro guardado. La vista
debe consumir `RoomController` y no acceder directamente a HTTP ni a
SharedPreferences.

La vista de propietario permite crear, editar y eliminar habitaciones y tipos.
Los cambios se muestran después de confirmarse en SQLite; un tipo con
habitaciones asociadas no se puede eliminar. Los nombres de tipos y números
de habitación se validan dentro del motel. Cliente y administrador consultan
los mismos datos locales. La base vacía empieza sin datos de ejemplo.
El formulario obtiene los servicios del maestro remoto o de su caché SQLite
y conserva los servicios previamente seleccionados al editar una habitación.

## Habitaciones y tipos en Firestore

`RoomSyncRepository` guarda cada cambio local y su evento pendiente en una
transacción SQLite. La cola persiste al cerrar la aplicación y separa los eventos
por UID de Firebase Auth. Solo se envían los eventos del usuario conectado.
La migración 13 → 14 agrega `room_sync_queue` sin borrar habitaciones existentes.

El controlador consulta Firestore al abrir la pantalla, después de un cambio y
cada 30 segundos mientras la pantalla está abierta. Los clientes y administradores
también actualizan su SQLite con los datos remotos. Los errores remotos no revierten
el guardado local; la vista del propietario muestra que la sincronización está
pendiente. No hay sincronización en segundo plano con la aplicación cerrada.

Colecciones remotas:

- `room_types/{id}`: campos de `RoomTypeData.toJson()`, `ownerId`, `deleted`, `updatedAt`.
- `rooms/{id}`: campos de `RoomVisualData.toJson()`, `ownerId`, `deleted`, `updatedAt`.
- `room_motels/{motelId}`: registro de autorización con el campo `ownerId`.

### Configuración en Firebase (proyecto `machuco`)

1. Habilitar Cloud Firestore si aún no existe, y usar Firebase Authentication
   para iniciar sesión. En `users/{uid}`, el propietario debe tener `role: "owner"`
   y `accountStatus: "active"` (mediante el flujo administrativo existente).
2. Para cada motel, crear desde la consola el documento
   `room_motels/<ID exacto del motel>` y agregar `ownerId` como string con el
   UID real de su propietario en Firebase Authentication. Debe coincidir con
   `ownerId` del motel en Supabase. No usar el correo ni el ID de una suscripción.
   Este registro es necesario porque los moteles se almacenan en Supabase y
   las reglas de Firestore no pueden consultar esa base.
3. Publicar **todo** el archivo `firestore.rules` en Firestore → Reglas → Publicar,
   conservando las reglas de usuarios, suscripciones y pagos. Alternativamente,
   con Firebase CLI autenticado: `firebase deploy --only firestore:rules --project machuco`.
4. Abrir Habitaciones como propietario. Los tipos y habitaciones ya existentes
   en SQLite de ese motel se agregan a la cola si no existen remotamente.
   Se envían en el siguiente ciclo (hasta 30 segundos). Las colecciones
   `rooms` y `room_types` se crean automáticamente con la primera escritura.
5. Crear o editar un tipo y una habitación y comprobar sus documentos en Datos.
   Desconectar Internet, editar, cerrar/reabrir, reconectar y comprobar que el
   cambio pendiente llega a Firestore. Abrir el mismo motel desde otro dispositivo.

Los borrados usan `deleted: true`; no eliminar documentos manualmente porque
se perdería la señal que permite borrar su copia local en otros dispositivos.
Las reglas permiten leer el catálogo a clientes/propietarios activos y administradores;
solo el propietario activo registrado para el motel puede escribirlo.
No hacen falta índices compuestos para las consultas actuales.

La resolución de ediciones simultáneas usa el último cambio recibido por Firestore.
La validación local evita números/nombres repetidos, pero no garantiza unicidad
entre dos dispositivos que crean registros diferentes a la vez. El bloqueo de
borrado de tipos con habitaciones es local; no es una restricción transaccional
entre dispositivos. Las imágenes siguen siendo URLs, no archivos subidos a Firestore.

### Autorización de Edificio UCO sin registro manual

Las reglas incluyen la relación explícita de `motel_1793753270427` con el UID
`9pojDLzLw3SL4S3VNK8JTPCUdbE2`. Para este motel basta desplegar las reglas;
no es necesario crear `room_motels`. El usuario debe seguir siendo un propietario
activo y el `ownerId` enviado debe coincidir con su UID. Si existe un documento
`room_motels` para ese motel, prevalece su propietario. Otros moteles siguen
requiriendo el registro. Al transferir Edificio UCO se debe actualizar esta
relación en las reglas o crear el registro con su nuevo propietario.
