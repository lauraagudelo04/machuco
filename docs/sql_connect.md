# Firebase SQL Connect en MACHUCO: guía para las ramas

Firebase SQL Connect (antes Data Connect) guarda datos en PostgreSQL y los
expone con consultas GraphQL que el SDK convierte en código Dart. Los
moteles ya lo usan (rama `feature_marco`). Decisión en
`docs/decisions_log.md` (2026-11-09).

## 1. Datos del servicio

| Dato | Valor |
| --- | --- |
| Proyecto | `machuco` |
| Servicio | `machuco-service` |
| Región | `us-east4` |
| Instancia Cloud SQL | `machuco-instance` (prueba gratuita Spark, 90 días desde 2026-11-09) |
| Base de datos | `machuco-database` |
| Configuración | `dataconnect/dataconnect.yaml` |

Hay **un solo servicio y una sola base para todo el equipo**. Todo lo que se
despliega comparte la misma instancia y el mismo límite gratuito.

## 2. Estructura: un archivo por funcionalidad

```
dataconnect/
  dataconnect.yaml        # servicio y lista de conectores (connectorDirs)
  schema/
    motel.gql             # tabla motels (feature_marco)
    <feature>.gql         # tu tabla, en tu propio archivo
  motel/                  # conector de moteles
    connector.yaml
    queries.gql
    mutations.gql
  <feature>/              # tu conector, en tu propia carpeta
```

- No edites el archivo ni el conector de otra rama. Si necesitas algo de
  ellos, pídeselo.
- Las relaciones funcionan entre archivos: por ejemplo, una habitación puede
  declarar `motel: Motel!` y SQL Connect crea la llave foránea `motelId`.
- Para agregar tu conector, añade su carpeta a `connectorDirs` en
  `dataconnect/dataconnect.yaml` (solo agregar, no quitar los existentes).

## 3. Agregar una tabla y su conector

1. Crea `dataconnect/schema/<feature>.gql` con tu `type ... @table`.
2. Crea `dataconnect/<feature>/connector.yaml`:

   ```yaml
   connectorId: <feature>
   generate:
     dartSdk:
       outputDir: ../../lib/service/sql_connect/<feature>_connector
       package: <feature>_connector
   ```

3. Escribe `queries.gql` y `mutations.gql`. **Toda operación lleva
   `@auth`**. Para datos de un usuario, usa el uid del token
   (`ownerId_expr: "auth.uid"`, `eq_expr: "auth.uid"`) en lugar de recibirlo
   desde la app. Ejemplos en `dataconnect/motel/`.
4. Genera el código Dart (siguiente sección).
5. Envuelve el código generado en un repositorio de
   `lib/database/repository/<feature>/`, como
   `SqlConnectMotelRepository` + `MotelSqlConnectGateway`. Las vistas nunca
   importan el código generado.

## 4. Emulador y código generado

Usa siempre la misma versión de la CLI para que el código salga igual:

```
npx -y firebase-tools@15.34.1 emulators:start --only dataconnect --project demo-machuco
```

- `demo-machuco` es un proyecto de prueba: la CLI no llama a la nube ni
  gasta el límite gratuito.
- Al arrancar, el emulador valida el esquema, crea las tablas en un
  PostgreSQL local y **regenera el código Dart** de todos los conectores.
- El código generado se sube al repositorio. Así quien no toca el esquema
  solo necesita `flutter pub get`.

Para que la app use el emulador en vez de la nube:

```
flutter run --dart-define=USE_SQL_CONNECT_EMULATOR=true
```

En un celular físico agrega `--dart-define=SQL_CONNECT_EMULATOR_HOST=<ip del computador>`.
Ver `lib/service/sql_connect/sql_connect_config.dart`.

## 5. Desplegar a la nube

- Solo desde `develop`, cuando el esquema funcione en el emulador, y
  avisando al equipo: un despliegue sube el esquema y los conectores de
  todos.
- Usa la CLI 15.34.1. La 14.x exige Blaze para desplegar aunque exista la
  prueba gratuita; la 15.x despliega en Spark sobre `machuco-instance`.

  ```
  npx -y firebase-tools@15.34.1 deploy --only dataconnect --project machuco
  ```

- Si el esquema agrega o cambia tablas, el despliegue muestra el SQL de la
  migración y pide confirmación. Léelo antes de aceptar: **nunca apliques
  una migración que borre tablas o columnas de otra rama** sin acordarlo.
- `dataconnect:services:list` y otros comandos de la 14.x intentan activar
  `compute.googleapis.com`, que exige Blaze; no los uses.
- No actualices a Blaze sin acuerdo del equipo.

## 6. Pendientes conocidos

- El rol de usuario vive en Firestore (`users/{uid}`); SQL Connect solo ve
  el token. Las operaciones de administrador exigen el custom claim
  `role: 'admin'`; hasta que la rama de autenticación lo agregue, nadie
  puede usarlas.
- La prueba gratuita dura 90 días (hasta aprox. 2027-02-07).
