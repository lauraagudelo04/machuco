# ADR: SQLite local con `floor` + `sqflite`

> Estado: **propuesto — pendiente de aprobación del equipo.** Este documento
> acompaña un PR que solo agrega las dependencias a `pubspec.yaml` y el
> registro de la decisión. No incluye código de persistencia; ese vendrá en un
> PR posterior, una vez aprobada esta decisión.

## 1. Contexto

`README.md#estado-y-decisiones-pendientes` y `CLAUDE.md` indican que la base
de datos y el almacenamiento de datos de dominio **no se fijan sin una decisión
documentada y acordada por el equipo**.

Hoy los datos de dominio (clientes, reservas, reseñas, etc.) viven en listas
`static` en memoria dentro de los controladores (ver
[`decisions_log.md`](decisions_log.md), entrada "Persistencia de reservas").
Esos datos se pierden al cerrar la app. `shared_preferences` quedó ratificado
solo para preferencias no sensibles y **no cubre datos de dominio**
(ver [`shared_preferences.md`](shared_preferences.md)).

En clase el profesor entregó un ejemplo de referencia (`EjemploSQLite`) que
resuelve la persistencia local con SQLite usando Floor. El ejemplo contiene:

- `@Entity` / `@PrimaryKey` / `@ColumnInfo` en el modelo
  (`attachment_model.dart`).
- `@dao` abstracto con `@Query`, `@insert`, `@update`, `@delete`
  (`attachment_dao.dart`).
- `@Database` con `part 'app_database.g.dart'`, lista de entidades, DAOs
  expuestos y migraciones versionadas (`app_database.dart`).

## 2. Decisión propuesta

Usar **SQLite como base de datos local** de la app, accedida mediante
**Floor** (capa ORM sobre `sqflite`), siguiendo el patrón del ejemplo de clase.

| Paquete | Tipo | Versión | Rol |
|---|---|---|---|
| `floor` | dependencia | `^1.5.0` | Anotaciones y runtime del ORM (`@Entity`, `@dao`, `@Database`). |
| `sqflite` | dependencia | `^2.4.4+1` | Driver SQLite para Android/iOS/macOS que usa Floor. |
| `floor_generator` | dev | `^1.5.0` | Genera el código (`*.g.dart`) a partir de las anotaciones. |
| `build_runner` | dev | `^2.4.13` | Ejecuta el generador de código. |

Generación de código:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 3. Alcance

**Cubre:** persistencia local de datos de dominio de la app (por ejemplo
`Client`, y progresivamente los demás modelos) en el dispositivo.

**No cubre:**

- El backend ni la sincronización entre dispositivos (sigue pendiente).
- Preferencias de UI (siguen en `shared_preferences`).
- Almacenamiento de imágenes/archivos.
- Autenticación y autorización: se validan en el backend; la base local no
  es fuente de verdad de credenciales.

## 4. Consecuencias

**A favor**

- Es el mismo enfoque que se vio en clase: menor curva de aprendizaje.
- Esquema tipado y consultas SQL explícitas en los DAO.
- Datos de dominio sobreviven al reinicio de la app y funcionan sin conexión.
- Encaja con la separación de capas: el DAO vive en `lib/repositories/` y los
  controladores no tocan SQL.

**En contra / riesgos**

- Exige generación de código (`build_runner`); hay que decidir si los
  `*.g.dart` se versionan o se generan en CI.
- Los modelos de dominio quedan acoplados a las anotaciones de Floor, salvo
  que se separe entidad y modelo.
- Cada cambio de esquema exige subir `version` y escribir una `Migration`.
- `sqflite` no soporta Web ni Windows/Linux sin paquetes adicionales
  (`sqflite_common_ffi`). La app apunta a Android/iOS, pero hay que tenerlo
  presente para tests y `flutter run -d chrome`.
- Los datos no se cifran por defecto: no guardar contraseñas ni secretos.

## 5. Alternativas consideradas

- **Mantener listas `static` en memoria:** no persiste; solo sirve como mock.
- **`drift`:** más potente y con soporte web, pero no es el que se enseñó en
  clase y añade curva de aprendizaje.
- **`sqflite` directo (sin Floor):** menos dependencias, pero más SQL y
  mapeo manual repetido.
- **Backend remoto como única fuente:** es la decisión de fondo y sigue
  pendiente; esta base local no la bloquea ni la reemplaza.

## 6. Plan posterior (no incluido en este PR)

1. Capa `repository` entre controlador y DAO.
2. Primer modelo persistido (`Client`) y conexión en el arranque de la app.
3. Manejo de errores explícito (sin `catch` silenciosos) y semilla única.
4. Tests del DAO y del repositorio con base en memoria.
5. Política de versionado de `*.g.dart` y de migraciones.

## 7. Qué se pide al equipo

Aprobar o rechazar esta decisión, y en particular:

- Las 4 dependencias de la sección 2.
- Si los archivos `*.g.dart` se commitean.
