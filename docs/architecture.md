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
├── service/auth/            # Integración con Auth0 y directorio de usuarios
├── utils/                   # Formateadores y excepciones específicas de un dominio
└── main.dart
```

Esta lista refleja los directorios que existen realmente en el repositorio.
`GUIA_MACHUCO.md#estructura-provisional-del-proyecto` también describe
`data/` y `repository/`; **ninguno de los dos existe todavía**. Ver
"Inconsistencia: capa de datos" más abajo.

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
para un backend HTTP futuro (por ejemplo `RegisteredUser`), aunque hoy solo
se usan contra datos en memoria o, en el caso del directorio de usuarios,
opcionalmente contra un API HTTP real (ver
[modules/auth.md](modules/auth.md)).

### `routes`

Un único archivo, `lib/routes/routes.dart`, centraliza todas las rutas
nombradas de la aplicación en la clase `AppRoutes` y resuelve cada nombre a
una pantalla en `AppRoutes.onGenerateRoute`. La navegación usa `Navigator`
con `MaterialPageRoute` y argumentos tipados (a menudo objetos de dominio
completos, como `Motel`), no `go_router` ni identificadores en la URL como
recomienda `README_DISENO_FLUTTER.md#11-navegación`.

### `service`

Solo existe `service/auth/`, con la integración de autenticación:
`Auth0AuthService` (Auth0 real), `HardcodedAuthService` (cuentas de prueba
locales) y el directorio de usuarios (`RegisteredUserDirectory`,
`InMemoryRegisteredUserDirectory`, `BackendRegisteredUserDirectory`). No hay
otros servicios externos implementados (pagos, imágenes, notificaciones
push, etc.). Detalle completo en [modules/auth.md](modules/auth.md).

### `data` y `repository`

**No existen como directorios en el proyecto.** La responsabilidad que
`GUIA_MACHUCO.md` les asigna (abstraer el origen de la información para que
las vistas no dependan de él directamente) hoy está cubierta de forma
parcial e inconsistente:

- En `service/auth/`, sí existe una abstracción real
  (`RegisteredUserDirectory`) con dos implementaciones intercambiables.
- En el resto de features (`booking`, `room`, `payment`, etc.), los
  controladores contienen los datos de ejemplo directamente (por ejemplo
  `controllers/room/room_mock_data.dart`, o las listas `static` dentro de
  cada `*Controller`), sin una interfaz de repositorio intermedia.

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
Controller (ChangeNotifier, datos en memoria o servicio HTTP puntual)
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

No hay una capa de red genérica ni un cliente HTTP compartido: el único uso
de `package:http` hoy es `BackendRegisteredUserDirectory` (ver
[modules/auth.md](modules/auth.md)). El resto de la aplicación opera sobre
datos de ejemplo en memoria, sin persistencia real.

## Pruebas

Existen pruebas de controlador y de widget para el feature `booking`
(`test/controllers/booking/**`, `test/widgets/booking/**`), más un
`test/widget_test.dart` genérico. No se observó una prueba por cada feature
listada en `README.md#alcance-funcional`; la cobertura real está
concentrada en reservas.
