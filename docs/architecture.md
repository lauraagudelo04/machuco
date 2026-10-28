# Arquitectura actual

Este documento describe cómo está construido MACHUCO **hoy**, capa por capa,
a partir del código en `lib/`. No es una propuesta ni un objetivo: si algo
aquí contradice `GUIA_MACHUCO.md` o `README_DISENO_FLUTTER.md`, es porque el
código todavía no llegó a la arquitectura definitiva que esos documentos
describen. Las decisiones de arquitectura pendientes están en
[README.md#estado-y-decisiones-pendientes](../README.md#estado-y-decisiones-pendientes)
y su seguimiento en [decisions_log.md](decisions_log.md).

## Estructura de `lib/`

```text
lib/
├── core/design_system/   # Tokens, tema y componentes App* (ver README_DISENO_FLUTTER.md)
├── widgets/               # Widgets compartidos por feature (booking, pqrs, review, ...)
├── views/                 # Pantallas, organizadas por feature y luego por rol
├── models/                 # Entidades de dominio, por feature
├── controllers/            # Estado de presentación (ChangeNotifier), por feature y rol
├── routes/routes.dart      # Registro único de rutas nombradas
├── service/
│   ├── auth/                # Firebase Authentication, preferencias y directorio de usuarios
│   ├── firebase/            # Nombres de colecciones Firestore y usuario actual
│   ├── room/                # Configuración de Supabase (--dart-define)
│   └── storage/             # Preferencias locales (shared_preferences)
├── database/
│   ├── app_database.dart    # Base Floor/SQLite común (+ .g.dart generado)
│   ├── model/               # Entidades Floor (notification, suscripcion)
│   └── repository/          # Repositorios y DAO por feature (auth, notification, room, suscripcion)
├── utils/                   # Formateadores y excepciones específicas de un dominio
├── firebase_options.dart    # Generado por FlutterFire CLI
└── main.dart                # Inicializa Firebase y la base SQLite antes de runApp
```

Esta lista refleja los directorios que existen realmente en el repositorio.
`GUIA_MACHUCO.md#estructura-provisional-del-proyecto` describe `data/` y
`repository/` como directorios de primer nivel; en el código la capa de
acceso a datos vive en `lib/database/` (con `repository/` dentro) y no existe
`data/`. Ver "`data` y `repository`" más abajo.

## Qué hay implementado en cada capa

### `core/design_system`

Sistema de diseño ya implementado sobre Material 3: tokens (`tokens/`), tema
claro/oscuro (`theme/app_theme.dart`, `app_color_scheme.dart`,
`app_theme_extensions.dart`) y un catálogo de componentes (`AppButton`,
`AppCard`, `AppDialog`, `AppFeedback`, `AppIconButton`, `AppNavigationBar`,
`AppSkeleton`, `AppTextField`, `StatusBadge`) exportados desde
`design_system.dart`. Corresponde a la Fase 1 y buena parte de la Fase 2 de
`README_DISENO_FLUTTER.md#17-plan-de-implementación`.

### `views`

Pantallas Flutter organizadas por feature (`booking`, `motel`, `room`,
`payment`, `pqrs`, `review`, `subscription`, etc.) y, dentro de cada
feature, por rol (`client_view`, `owner_view`, `system_admin_view`) cuando
aplica. El patrón típico observado (por ejemplo en
`views/booking/client_view/client_reservations_page.dart`) es:

1. Un `StatefulWidget` crea su propio controlador en `initState`.
2. Se suscribe con `controller.addListener(...)` y llama `setState` en el
   callback.
3. Libera la suscripción y el controlador en `dispose`.

No se usa `Provider`, `flutter_riverpod`, `InheritedWidget` propio, ni
ningún mecanismo de inyección de dependencias: cada pantalla instancia su
controlador de forma directa.

### `controllers`

Todos los controladores revisados extienden `ChangeNotifier` (18 clases en
`lib/controllers/**`). No usan ningún paquete de gestión de estado de
terceros. Varios controladores (por ejemplo
`ClientBookingController`) mantienen su "base de datos" en una colección
`static` en memoria para que varias instancias del controlador (una por
pantalla) compartan los mismos datos sin backend ni paquete de estado
compartido; esto está documentado explícitamente en el propio archivo como
una decisión deliberada mientras no exista backend.

### `models`

Entidades de dominio por feature (`booking/booking.dart`,
`auth/registered_user.dart`, `room/room_models.dart`, etc.), en línea con
`GUIA_MACHUCO.md`. Algunos modelos incluyen `fromJson`/`toJson` pensados
para un backend HTTP (por ejemplo `RegisteredUser`, usado en memoria o,
opcionalmente, contra un API HTTP externo). `UserProfile` usa
`fromFirestore`/`toFirestore` para `users/{uid}` y `CountryPhoneCode`
acepta tanto la respuesta REST de Supabase como una fila SQLite (ver
[modules/auth.md](modules/auth.md)).

### `routes`

Un único archivo, `lib/routes/routes.dart`, centraliza todas las rutas
nombradas de la aplicación en la clase `AppRoutes` y resuelve cada nombre a
una pantalla en `AppRoutes.onGenerateRoute`. La navegación usa `Navigator`
con `MaterialPageRoute` y argumentos tipados (a menudo objetos de dominio
completos, como `Motel`), no `go_router` ni identificadores en la URL como
recomienda `README_DISENO_FLUTTER.md#11-navegación`.

### `service`

- `service/auth/`: `FirebaseAuthService` (Firebase Authentication + perfil en
  Firestore), `HardcodedAuthService` (cuentas de prueba locales, apagado por
  defecto), el contrato transitorio `AuthService`, `AuthConfig`
  (`--dart-define`), `AuthPreferences` (correo actual y otros datos no
  sensibles) y el directorio de usuarios (`RegisteredUserDirectory`,
  `InMemoryRegisteredUserDirectory`, `BackendRegisteredUserDirectory`).
  Detalle en [modules/auth.md](modules/auth.md).
- `service/firebase/`: `FirestoreCollections` (nombres de colecciones) y
  `CurrentUser` (uid/correo de la sesión; identifica, no autoriza). Guía de uso
  para otras ramas en [firebase.md](firebase.md).
- `service/room/`: `SupabaseRoomConfig` (URL y clave anónima de Supabase por
  `--dart-define`).
- `service/storage/`: `LocalPreferencesService` y su implementación sobre
  `shared_preferences` (ver [shared_preferences.md](shared_preferences.md)).

No hay servicios de pagos, imágenes ni notificaciones push.

### `data` y `repository`

No existe `lib/data/` ni `lib/repository/` de primer nivel. La capa de acceso
a datos vive en `lib/database/`:

- `app_database.dart`: base Floor/SQLite común (`AppDatabase`,
  `AppDatabaseProvider`, versión 7) con DAO de suscripción, notificaciones,
  habitaciones y maestros de autenticación.
- `database/model/`: entidades Floor de `notification` y `suscripcion`.
- `database/repository/auth/`: `AuthCatalogRepository` + `AuthCatalogDao`
  (indicativos telefónicos desde Supabase REST con caché SQLite) y
  `UserProfileRepository` (interfaz) + `FirestoreUserProfileRepository`
  (perfiles en Cloud Firestore, `users/{uid}`).
- `database/repository/room/`: `RoomServiceRepository` (Supabase) y
  `RoomDao`.
- `database/repository/notification/` y `database/repository/suscripcion/`:
  repositorios sobre SQLite (suscripción también consulta un catálogo en
  Supabase).

Fuera de estas features, los controladores (`booking`, `payment`, `pqrs`,
etc.) siguen conteniendo datos de ejemplo directamente (por ejemplo
`controllers/room/room_mock_data.dart`, o listas `static` en cada
`*Controller`), sin repositorio intermedio. `UserProfileRepository` es la
única interfaz de repositorio con implementación intercambiable; los demás
repositorios son clases concretas. El directorio de usuarios
(`RegisteredUserDirectory`) sigue en `service/auth/`.

### `utils`

Utilidades pequeñas y específicas, sin archivos genéricos tipo
`helpers.dart`: `currency_formatter.dart`, `date_formatter.dart`,
`booking/reservation_cancellation_exception.dart`.

### `widgets`

Componentes reutilizables organizados por feature (`booking`, `pqrs`,
`review`, `subscription`, `notification`, `layout`). Son distintos de los
componentes `App*` del design system: estos son específicos de dominio
(`ReservationCard`, `PqrsTimeline`, `SubscriptionDetailCard`, etc.), en
línea con la convención de nombres de
`README_DISENO_FLUTTER.md#15-convenciones-de-desarrollo`.

## Flujo real de datos

```text
Firebase Auth / Cloud Firestore / Supabase REST / SQLite (Floor) / shared_preferences
    │  (FirebaseAuthService, *Repository, AuthPreferences)
    ▼
Controller (ChangeNotifier; en features sin persistencia, datos en memoria)
    │  notifyListeners()
    ▼
View (StatefulWidget: addListener + setState)
    │  usa
    ▼
Widgets de dominio (widgets/<feature>) y componentes App* (core/design_system)
    │  navega vía
    ▼
AppRoutes.onGenerateRoute (Navigator, argumentos tipados)
```

`main.dart` inicializa Firebase (`Firebase.initializeApp` con
`DefaultFirebaseOptions.currentPlatform`) y abre la base SQLite antes de
`runApp`. En autenticación, la sesión la mantiene Firebase Auth y el rol y el
estado de la cuenta se leen de Cloud Firestore (`users/{uid}`), cuya
autorización real vive en `firestore.rules` (ver [firebase.md](firebase.md)).
Los maestros (indicativos, servicios de habitación, planes) se consultan por
REST a Supabase con caché en SQLite.

No hay un cliente HTTP compartido: `package:http` se usa en los repositorios
de Supabase y en `BackendRegisteredUserDirectory`. Las features sin
repositorio (reservas, pagos, PQRS, etc.) siguen operando sobre datos de
ejemplo en memoria.

Las dependencias se construyen en la vista: `LoginPage` crea el
`FirebaseAuthService` (o `HardcodedAuthService`), el directorio de usuarios y
`AuthCatalogRepository.fromEnvironment` y se los pasa al `LoginController`.
La vista no consulta datos por sí misma, pero sí decide las implementaciones;
no hay inyección de dependencias.

## Pruebas

- Reservas: `test/controllers/booking/**`, `test/widgets/booking/**`.
- Autenticación: `test/controllers/auth/` (preferencias del
  `LoginController`), `test/repositories/auth/` (`AuthCatalogRepository`,
  `UserProfile`, reglas puras de registro y un fake de
  `UserProfileRepository` sin red) y `test/widget_test.dart` (rol al
  registrar, redirección por rol, logout, usuarios quemados; con servicios
  falsos, sin Firebase real).
- Persistencia y servicios: `test/database/` (notificaciones, suscripción),
  `test/repositories/room/`, `test/service/storage/`.
- Widgets de suscripción: `test/widgets/subscription/`.

No hay pruebas de `FirebaseAuthService` ni de `FirestoreUserProfileRepository`
contra Firebase (ni emulador), ni pruebas de `firestore.rules`. No hay una
prueba por cada feature de `README.md#alcance-funcional`.
