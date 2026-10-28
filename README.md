# MACHUCO

Aplicación móvil multiplataforma desarrollada con Flutter para consultar, reservar y administrar moteles.

Este documento presenta el contexto general y el estado del proyecto. Las reglas de trabajo y la especificación visual se mantienen por separado:

- [Guía de buenas prácticas](GUIA_MACHUCO.md)
- [Guía de diseño e implementación visual](README_DISENO_FLUTTER.md)

## Índice

1. [Descripción](#descripción)
2. [Objetivo](#objetivo)
3. [Perfiles](#perfiles)
4. [Alcance funcional](#alcance-funcional)
5. [Tecnologías](#tecnologías)
6. [Estructura actual](#estructura-actual)
7. [Etapa actual: segunda etapa](#etapa-actual-segunda-etapa)
8. [Decisiones tomadas](#decisiones-tomadas)
9. [Estado y decisiones pendientes](#estado-y-decisiones-pendientes)
10. [Próximos pasos](#próximos-pasos)

## Descripción

Machuco centraliza la interacción entre clientes y propietarios de moteles. Busca ofrecer un proceso claro, privado y consistente para descubrir establecimientos, consultar habitaciones, seleccionar fechas, horarios y servicios, y completar una reserva. También proporciona a los propietarios herramientas para consultar y administrar su operación.

El producto debe priorizar:

- Privacidad y seguridad.
- Facilidad de uso y claridad.
- Separación de acceso por roles.
- Consistencia entre Android e iOS.
- Mantenibilidad, escalabilidad y adaptación a distintos tamaños de pantalla.

## Objetivo

Permitir que los clientes encuentren y reserven habitaciones y servicios desde una aplicación móvil, y que los propietarios gestionen establecimientos, disponibilidad, reservas y demás elementos relacionados con su operación.

## Perfiles

### Cliente

Puede consultar y utilizar los servicios de la plataforma desde la aplicación. Tiene acceso a:

- La lista de moteles y la información de cada establecimiento.
- Las habitaciones disponibles de cada motel y sus detalles.
- La creación de reservas de habitaciones.
- La lista de sus reservas y el detalle de cada una.
- La creación de PQRS y la consulta de su información y estado.
- La pasarela de pagos para completar sus transacciones.
- El historial y los detalles de los pagos realizados.
- Las facturas asociadas a sus pagos y reservas.

### Propietario

Puede administrar la operación de sus establecimientos mediante un panel diferenciado. Tiene acceso a:

- La lista de sus moteles y la información detallada de cada uno.
- La creación y eliminación de moteles.
- La lista de habitaciones de cada motel y sus detalles.
- La lista de clientes asociados a sus moteles.
- La desasociación de clientes y su desactivación dentro de la lista de clientes.
- La lista general de reservas y su consulta filtrada por cliente, motel o habitación.
- La consulta de pagos pendientes, pagos recibidos y demás información relacionada con los pagos.
- La consulta de facturas.
- La creación de recibos de caja.
- El envío de notificaciones sobre reservas canceladas desde la vista de reservas.

### Administrador del sistema

Puede supervisar y consultar la operación general de la plataforma mediante un panel administrativo. Tiene acceso a:

- La lista de propietarios y el detalle de cada uno.
- La lista de moteles y su información.
- La información financiera de la plataforma y de los moteles.
- Las reservas y los indicadores estadísticos de los moteles.
- Las PQRS, sus estados y demás información asociada.
- Los servicios adicionales disponibles.
- Las habitaciones y sus detalles.

## Alcance funcional

- Autenticación y sesiones.
- Acceso y perfiles según el rol.
- Consulta de propietarios y sus detalles por parte del administrador.
- Creación, consulta y eliminación de moteles.
- Habitaciones, clases y disponibilidad.
- Creación y administración de reservas.
- Consulta de reservas por cliente, motel o habitación.
- Administración de clientes asociados a los moteles.
- Productos y servicios adicionales.
- Finanzas e indicadores estadísticos.
- Pasarela de pagos e historial de pagos.
- Consulta de facturas.
- Creación de recibos de caja.
- Notificaciones de reservas canceladas.
- Reseñas y su gestión.
- Creación de PQRS y seguimiento de sus estados.
- Suscripciones.
- Panel del propietario.
- Panel del administrador del sistema.

Este alcance describe el producto; todavía no determina la implementación técnica de cada módulo.

## Tecnologías

- Flutter.
- Dart.
- Android Studio.
- Git.
- **Firebase** como base de datos principal en la nube (decisión del equipo, ver [docs/decisions_log.md](docs/decisions_log.md)).
- **Firebase Authentication** (`firebase_auth`) como sistema de autenticación (ver [Configuración de la autenticación](#configuración-de-la-autenticación)).
- **Supabase** para los datos maestros (catálogos y listas de referencia), consultados mediante API REST.
- `http`, para consumir las API REST (maestros de Supabase y el directorio de usuarios externo).
- Floor sobre SQLite (`floor`, `sqflite`) para los servicios SQL de almacenamiento local de datos (`lib/database/`).
- `shared_preferences`, adoptado por el equipo para guardar o compartir datos locales no sensibles, como correos recordados y preferencias de UI. Ver [docs/shared_preferences.md](docs/shared_preferences.md).

El proyecto ya incluye un sistema de diseño propio construido sobre Material 3 (`lib/core/design_system`, con tokens, tema y componentes `App*`), conforme a [README_DISENO_FLUTTER.md](README_DISENO_FLUTTER.md). Las pantallas navegan con `Navigator` y rutas nombradas centralizadas en `lib/routes/routes.dart`. Los controladores existentes manejan su estado con `ChangeNotifier` nativo de Flutter.

Aún no están definidos de forma acordada por el equipo: la pasarela de pagos, el almacenamiento de imágenes, la administración de estado (más allá del uso puntual de `ChangeNotifier`), la navegación definitiva (más allá del `Navigator` actual, sin `go_router` u otro paquete) ni la plataforma de despliegue. El código ya tomó algunas decisiones parciales en estas áreas (por ejemplo, un directorio de usuarios que puede consultar un API HTTP externo); estos hallazgos están registrados en [docs/decisions_log.md](docs/decisions_log.md) para que el equipo los confirme o los corrija. Las decisiones aprobadas deberán registrarse en la documentación correspondiente.

## Estructura actual

```text
lib/
├── core/
│   └── design_system/
├── widgets/
├── views/
├── models/
├── controllers/
├── routes/
├── service/
├── database/
│   ├── model/
│   └── repository/
├── utils/
└── main.dart
```

Esta es la estructura real de `lib/` hoy. No existe `data/`, y los repositorios descritos en [GUIA_MACHUCO.md](GUIA_MACHUCO.md#estructura-provisional-del-proyecto) viven en `lib/database/repository/` (Firestore, Supabase y SQLite) solo para algunas funcionalidades; el resto de controladores sigue usando datos de ejemplo directamente (por ejemplo `controllers/room/room_mock_data.dart`). Este desajuste se detalla en [docs/architecture.md](docs/architecture.md) y debe resolverse como parte de la arquitectura definitiva, no corregirse de forma unilateral en una rama.

La estructura es provisional hasta que el equipo defina la arquitectura definitiva. La responsabilidad y las reglas de cada directorio se detallan en [GUIA_MACHUCO.md](GUIA_MACHUCO.md#estructura-provisional-del-proyecto).

## Etapa actual: segunda etapa

Machuco está en su **segunda etapa**. La primera etapa construyó la interfaz con datos de ejemplo; en esta se implementan elementos funcionales:

- Consulta de datos maestros mediante **API REST** (Supabase).
- **Servicios SQL** para almacenar datos localmente (Floor sobre SQLite, `lib/database/`).
- **`shared_preferences`** para guardar o compartir datos locales no sensibles, como correos y preferencias.
- Persistencia en **Firebase** y autenticación con **Firebase Authentication**.

En esta etapa cada persona puede cambiar de funcionalidad; el alcance vigente de cada rama está en `contexts/people/`.

## Decisiones tomadas

- **Base de datos:** Firebase.
- **Datos maestros:** Supabase, consultado por API REST.
- **Autenticación:** Firebase Authentication (reemplaza a Auth0).
- **Perfiles de usuario y rol:** Cloud Firestore (`users/{uid}`), protegido por reglas de seguridad (`firestore.rules`).
- **Almacenamiento local de datos:** Floor (SQLite).
- **Preferencias y datos locales no sensibles:** `shared_preferences`.

Detalle y fechas en [docs/decisions_log.md](docs/decisions_log.md).

## Estado y decisiones pendientes

Machuco se encuentra en desarrollo. Antes de modificar significativamente su estructura se deben definir y documentar:

- Arquitectura y administración de estado (el código ya usa `ChangeNotifier` nativo en varios controladores, sin un paquete de estado acordado; ver [docs/decisions_log.md](docs/decisions_log.md)).
- Contratos de datos entre la app, Firebase y Supabase (colecciones, tablas y formato de las respuestas REST).
- Autorización por roles y sesiones: el rol de los usuarios ya vive en Cloud Firestore y se valida con `firestore.rules` (ver [docs/firebase.md](docs/firebase.md)); falta que cada funcionalidad agregue las reglas de sus colecciones y definir las políticas de Supabase.
- Pasarela de pagos y sistema de suscripciones.
- Almacenamiento de imágenes (aún pendiente).
- Navegación, enlaces profundos y notificaciones (hoy se usa `Navigator` con rutas nombradas centralizadas en `lib/routes/routes.dart`, no la navegación definitiva).
- Gestión de secretos y entornos.
- Analítica, monitoreo, CI/CD y alcance de las pruebas automatizadas.
- Términos de privacidad y tratamiento de datos.

## Próximos pasos

1. Acordar la arquitectura y la solución de estado global.
2. Integrar Firebase, Supabase (API REST) y Floor detrás de servicios y repositorios, y definir sus contratos de datos.
3. Desplegar `firestore.rules` y extender la autorización por roles a cada colección nueva (ver [docs/firebase.md](docs/firebase.md)).
4. Establecer navegación, entornos y gestión de secretos.
5. Configurar pruebas automatizadas y CI/CD.
6. Implementar la interfaz conforme a [README_DISENO_FLUTTER.md](README_DISENO_FLUTTER.md).

## Configuración de la autenticación

La app usa Firebase Authentication (correo y contraseña) mediante `firebase_auth`. Firebase se inicializa en `lib/main.dart` con `lib/firebase_options.dart`, generado por FlutterFire CLI (`flutterfire configure`). En la consola de Firebase debe estar habilitado el proveedor **Correo electrónico/contraseña** (`Authentication > Sign-in method`).

El perfil, el rol (`admin`, `owner` o `client`) y el estado de la cuenta se guardan en **Cloud Firestore**, en `users/{uid}`, protegidos por `firestore.rules` (referenciado en `firebase.json`). El registro público solo crea clientes (activos) y propietarios (pendientes de aprobación); los administradores se crean manualmente en la consola. Un usuario sin perfil entra como Cliente. Para que funcione hay que:

1. Crear la base de datos Cloud Firestore en la consola de Firebase.
2. Desplegar las reglas con `firebase deploy --only firestore:rules` (pendiente al 2026-10-27).

Cómo usar el usuario autenticado y agregar colecciones con sus reglas: [docs/firebase.md](docs/firebase.md).

Parámetros opcionales (`--dart-define`):

- `AUTH_USE_BACKEND_USERS=true` junto con `AUTH_USERS_API_BASE_URL` (y opcionalmente `AUTH_USERS_API_PATH`, por defecto `/users`) para que el directorio de usuarios de la app consulte un API HTTP externo en vez de los datos de ejemplo en memoria. Esta integración es parcial y no reemplaza una decisión de backend acordada por el equipo; ver [docs/decisions_log.md](docs/decisions_log.md).

El ingreso con Google y GitHub está definido pero todavía no implementado.

### Modo de usuarios de prueba (sin Firebase)

Definiendo `--dart-define=AUTH_USE_HARDCODED_AUTH_USERS=true` la app autentica contra un conjunto fijo de cuentas de prueba definidas en el código (`lib/service/auth/hardcoded_auth_service.dart`), en vez de contra Firebase. Está pensado únicamente para desarrollo local y QA; no debe activarse en builds distribuidos. Revise el archivo mencionado para conocer las credenciales de prueba disponibles; no se documentan aquí por tratarse de datos de acceso, aunque sean de prueba.
