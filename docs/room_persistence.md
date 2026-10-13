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

La aplicación recibe esos valores sin guardar configuración en el código:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<proyecto>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<clave-publica>
```

`RoomServiceRepository` consulta el endpoint y actualiza el caché local. Si
Supabase no está disponible, devuelve el último maestro guardado. La vista
debe consumir `RoomController` y no acceder directamente a HTTP ni a
SharedPreferences.
