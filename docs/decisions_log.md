# Registro de decisiones técnicas a confirmar

`README.md#estado-y-decisiones-pendientes` marca varias decisiones de
arquitectura como pendientes de acuerdo del equipo. Este documento registra
hallazgos del código que **ya tomaron un camino de facto** en algunas de esas
áreas, sin que exista un acuerdo documentado al respecto. No se trata de
decisiones cerradas: el equipo debe revisarlas y decidir si se confirman,
se generalizan o se revierten.

No se edita `README.md` para declarar estas decisiones como resueltas; ese
documento solo referencia este registro.

## 2026-09-15 — Gestión de estado: `ChangeNotifier` nativo, sin paquete de terceros

**Hallazgo:** 18 controladores en `lib/controllers/**` extienden
`ChangeNotifier` de Flutter (`package:flutter/foundation.dart`). Las vistas
crean su propia instancia del controlador en `initState`, se suscriben con
`addListener` y llaman `setState` manualmente en el callback (ver
`views/booking/client_view/client_reservations_page.dart` como ejemplo
representativo). No se encontró ningún uso de `flutter_riverpod`,
`provider`, `bloc` ni paquete equivalente en `pubspec.yaml` ni en el código.

**Por qué importa:** `README_DISENO_FLUTTER.md#3-tecnología-y-librerías-recomendadas`
recomienda `flutter_riverpod` para el estado de presentación, pero aclara
"si el proyecto ya adoptó otra solución, no migrar solo por diseño". El
código no adoptó Riverpod; adoptó `ChangeNotifier` puro y manual, sin
compartir estado entre pantallas mediante un árbol de providers.

**A confirmar:** ¿se estandariza `ChangeNotifier` + `addListener` manual
como la solución de estado del proyecto, se introduce un paquete que
formalice este patrón (por ejemplo exponiendo los controladores mediante
`ListenableBuilder`/`InheritedNotifier` en vez de `addListener` manual en
cada `State`), o se migra a Riverpod como sugiere la guía de diseño?

## 2026-09-15 — Persistencia de reservas: estado compartido en memoria vía variables `static`

**Hallazgo:** Varios controladores (por ejemplo `ClientBookingController`)
guardan su colección de datos en un campo `static`, para que distintas
instancias del mismo controlador (una por pantalla) lean y escriban la
misma "base de datos" en memoria sin backend. Esto está documentado en el
propio archivo como una decisión deliberada y temporal.

**Por qué importa:** es un patrón de persistencia de facto (memoria de
proceso compartida vía `static`) que no aparece en `README.md` ni en
`GUIA_MACHUCO.md`, y que no sobrevive a un reinicio de la app ni se
sincroniza entre dispositivos.

**A confirmar:** si este patrón se mantiene como convención temporal
explícita para todos los controladores mock del proyecto (documentarlo en
`GUIA_MACHUCO.md`), o si se reemplaza pronto por una capa `repository`/`data`
real, tal como esos directorios están previstos en la estructura del
proyecto pero no implementados (ver [architecture.md](architecture.md)).

## 2026-09-15 — Backend parcial: API HTTP externa para el directorio de usuarios

**Hallazgo:** `lib/service/auth/backend_registered_user_directory.dart`
usa `package:http` para consultar un API externo de usuarios
(`GET {baseUrl}{usersPath}`), activable con
`--dart-define=AUTH_USE_BACKEND_USERS=true` y
`--dart-define=AUTH_USERS_API_BASE_URL=...`. Es la única dependencia de red
genérica (`http`) en todo el proyecto fuera de `auth0_flutter`. La URL base
no está hardcodeada en el repositorio: se inyecta por variable de entorno,
lo cual es correcto según `GUIA_MACHUCO.md#seguridad-y-privacidad`.

**Por qué importa:** `README.md` presenta "Backend, base de datos y
contratos de API" como completamente pendiente, pero ya existe un contrato
de API real (forma de request/response) para al menos un recurso (`users`),
y una implementación funcional que lo consume.

**A confirmar:** si este contrato de `users` es el punto de partida para el
backend definitivo, o si se descarta al momento de tomar la decisión de
backend con el equipo completo. Mientras no se confirme, `useBackendUsers`
permanece apagado por defecto (`AUTH_USE_BACKEND_USERS=false`).

## 2026-09-15 — Proveedor de autenticación: Auth0 ya integrado (documentado, pero no reflejado como decisión tomada en la lista de pendientes)

**Hallazgo:** `auth0_flutter` está en `pubspec.yaml` y `Auth0AuthService`
implementa login, login con Google, registro y recuperación de contraseña
contra Auth0. Esto ya está documentado al final de `README.md`
("Configuración de Auth0 para login y registro"), pero la sección
"Estado y decisiones pendientes" seguía listando "Autenticación,
autorización por roles y sesiones" como un bloque completamente abierto.

**Por qué importa:** el proveedor de autenticación de cliente ya es una
decisión tomada y en uso, no una decisión pendiente. Lo que sigue sin
resolver es la **autorización por rol en el backend**: el rol viaja hoy
como claim del ID token de Auth0 y se interpreta en el cliente
(`Auth0AuthService._extractRole`), pero no hay evidencia en este
repositorio de que un backend valide ese rol de forma independiente antes
de autorizar una operación, como exige
`GUIA_MACHUCO.md#seguridad-y-privacidad`.

**A confirmar:** que el equipo trate "Auth0 como proveedor" como decisión
cerrada en `README.md`, y que la autorización por rol en backend se agregue
explícitamente como pendiente (hoy queda implícita dentro del mismo punto).

*(Superado el 2026-10-27: Auth0 se retiró y lo reemplazó Firebase
Authentication; ver "Retiro del código de Auth0".)*

## 2026-09-15 — Modo de autenticación con usuarios de prueba embebidos en el código

**Hallazgo:** `lib/service/auth/hardcoded_auth_service.dart` define una
lista fija de cuentas de prueba (correo, contraseña, nombre y rol) y un
`HardcodedAuthService` que autentica contra ellas cuando
`AUTH_USE_HARDCODED_AUTH_USERS=true`. La bandera está apagada por defecto.

**Por qué importa (seguridad):** son credenciales de prueba, identificadas
como tales por el nombre del archivo y la clase, y protegidas detrás de una
bandera apagada por defecto, lo cual mitiga el riesgo. Aun así,
`GUIA_MACHUCO.md#seguridad-y-privacidad` pide no incluir credenciales en el
repositorio; este documento no las reproduce, y se recomienda que el
equipo evalúe si esas cuentas deberían moverse a un archivo ignorado por
Git o a variables de entorno en vez de vivir como código fuente versionado,
incluso siendo datos de prueba.

**A confirmar:** si este mecanismo se conserva para QA/desarrollo o se
retira antes de acercarse a producción, y si las credenciales de prueba
deben dejar de estar en el código fuente versionado.

## 2026-09-15 — Sistema de diseño (`core/design_system`) ya implementado en buena parte

**Hallazgo:** `lib/core/design_system` ya contiene tokens, tema
claro/oscuro y varios componentes `App*` (`AppButton`, `AppCard`,
`AppDialog`, `AppFeedback`, `AppIconButton`, `AppNavigationBar`,
`AppSkeleton`, `AppTextField`, `StatusBadge`), correspondientes a la Fase 1
y buena parte de la Fase 2 de
`README_DISENO_FLUTTER.md#17-plan-de-implementación`. `README.md` no
mencionaba este directorio en su "Estructura actual" antes de esta
actualización.

**Por qué importa:** no es una decisión pendiente ni contradictoria, sino
progreso real que `README.md` no reflejaba. Se corrigió en la sección
"Estructura actual" y "Tecnologías" de `README.md` como parte de esta
actualización.

**A confirmar:** ninguna acción pendiente del equipo; se deja registrado
para trazabilidad de cuándo se documentó por primera vez en `README.md`.

## 2026-09-15 — El feature file de Bookings dice "pendiente/vacío" sobre código de Propietario y Administrador que ya está implementado

**Hallazgo:** `contexts/people/feature-juan_pablo.feature.md`, sección
"Alcance técnico", marca como **pendiente (archivo actualmente vacío, a
reconstruir)** los directorios `lib/views/booking/owner_view/`,
`lib/controllers/booking/owner_view/owner_booking_controller.dart`,
`lib/views/booking/system_admin_view/` y
`lib/controllers/booking/system_admin_view/system_admin_booking_controller.dart`.
Esto ya no es cierto: hoy existen y están implementados con datos mock
funcionales:

- Propietario: `owner_reservations_page.dart`,
  `owner_reservation_detail_page.dart`, `owner_cash_payment_page.dart` +
  `owner_booking_controller.dart` (460 líneas), con tests en
  `test/controllers/booking/owner_view/owner_booking_controller_test.dart`
  y `test/widgets/booking/owner_reservations_page_test.dart`,
  `owner_reservation_detail_page_test.dart`.
- Administrador: `admin_motel_reservations_list_page.dart`,
  `admin_motel_reservation_dashboard_page.dart` +
  `system_admin_booking_controller.dart` (500 líneas), con tests en
  `test/controllers/booking/system_admin_view/system_admin_booking_controller_test.dart`
  y `test/widgets/booking/admin_motel_reservations_list_page_test.dart`,
  `admin_motel_reservation_dashboard_page_test.dart`.

Se verificaron como ya implementadas varias reglas que el feature file
describe como si estuvieran por construir: el filtro de historial de
reservas por cliente (`OwnerBookingController.reservationsForClient`,
reutilizado tanto por el filtro de "Reservas generales" como por el futuro
módulo de Clientes), "Pagar en efectivo" que deja la factura en
`InvoiceAccessStatus.pending` en vez de generarla de inmediato, y la
cancelación con motivo obligatorio a través del mismo widget compartido
`lib/widgets/booking/cancellation_reason_sheet.dart` que usa también el
Cliente.

**Por qué importa (es el hallazgo más grave del reporte de QA):** el propio
feature file explica en "Notas para el agente" que estas vistas existieron
antes, se borraron deliberadamente en un commit previo a `dd71f74` para
"reconstruirlas ahora vía agentes/skills", y que el código viejo usaba un
modelo `Booking`/`BookingStatus` distinto al vigente. Si un agente confía en
la sección "Alcance técnico" sin releer el árbol real de `lib/`, hay riesgo
real de que reconstruya (o sobrescriba) código funcional, probado y ya
migrado al modelo `Reservation`/`ReservationStatus` vigente, perdiendo
trabajo válido.

**A confirmar:** que la persona dueña de `feature-juan_pablo.feature.md`
actualice la sección "Alcance técnico" para reflejar que Propietario y
Administrador ya están implementados (no vacíos), y que documente ahí mismo
los bugs reales pendientes (ver
[`docs/booking_handoff.md`](booking_handoff.md#3-bugs-conocidos-y-su-impacto))
en vez de la nota de "a reconstruir". Este documento no edita el feature
file directamente porque no es de este agente.

## 2026-09-23 — Ratificado: `shared_preferences` para persistencia local de preferencias no sensibles

**Hallazgo:** la rama `feature-juan_pablo` (módulo Bookings) adoptó
`shared_preferences: ^2.3.0` en `pubspec.yaml` para persistir preferencias de
UI locales (por ejemplo, el último motel usado para filtrar una lista de
reservas), usando la API `SharedPreferencesAsync` en vez de la API legada
`getInstance()`. Se creó `lib/service/storage/` con la interfaz
`LocalPreferencesService` y la implementación `SharedPreferencesLocalService`,
siguiendo el mismo patrón de interfaz + implementación ya usado en
`lib/service/auth/` (`RegisteredUserDirectory`). Detalle completo,
justificación y advertencias en [`shared_preferences.md`](shared_preferences.md).

**Por qué importa:** `README.md#tecnologías` y `CLAUDE.md` listan
"almacenamiento" como una decisión que no se debe fijar sin acuerdo del
equipo completo. Esta adopción resolvió la necesidad puntual de la rama de
Bookings y quedó, además, **ratificada por el equipo completo** como
convención transversal (paquete, API y ubicación de la capa de acceso) para
el resto de las 17 ramas, en lugar de que cada rama resuelva "almacenamiento
local" de forma distinta. Se refleja como decisión cerrada en
[`README.md#tecnologías`](../README.md#tecnologías).

**Estado:** cerrado. `shared_preferences` + `SharedPreferencesAsync` +
`lib/service/storage/` es la convención acordada de persistencia local no
sensible para todo el proyecto. Esto no cubre almacenamiento de imágenes ni
persistencia de datos de dominio, que siguen dependiendo de la decisión de
backend/base de datos, todavía pendiente.

## 2026-09-23 — Cambio: `shared_preferences` pasa a la API clásica y el servicio se vuelve genérico

**Cambio:** se reemplaza `SharedPreferencesAsync` por la **API clásica
`SharedPreferences.getInstance()`**. No se usan `SharedPreferencesAsync` ni
`SharedPreferencesWithCache` en ninguna parte del proyecto. Se elimina la
dev-dependency `shared_preferences_platform_interface`, que solo existía para
probar la API async; las pruebas usan ahora
`SharedPreferences.setMockInitialValues`.

Además, `LocalPreferencesService` deja de tener métodos propios de Bookings
(`getLastFilterMotelId`, etc.) y pasa a ser un contrato clave-valor genérico
(`getString`/`setString`, `getBool`/`setBool`, `getInt`/`setInt`,
`getDouble`/`setDouble`, `getStringList`/`setStringList`, `containsKey`,
`remove`, `clear`). Cada módulo crea su instancia con un namespace de
funcionalidad: `SharedPreferencesLocalService(namespace: 'bookings')`.

**Por qué importa:** las ramas están asociadas a personas, no a
funcionalidades, y en la segunda etapa cada persona cambia de funcionalidad.
Un servicio genérico con namespace por funcionalidad permite que cualquier
rama lo use sin editar un archivo compartido y sin que las claves queden
atadas a quien las creó. Detalle en
[`shared_preferences.md`](shared_preferences.md).

**Estado:** cerrado. Reemplaza el punto "API `SharedPreferencesAsync`" de la
entrada anterior; el resto de esa decisión (paquete y ubicación en
`lib/service/storage/`) sigue vigente.

## 2026-10-06 — Floor (SQLite) para persistencia local de datos de dominio

**Hallazgo:** el profesor pidió una base de datos local con esta estructura:
`lib/database/app_database.dart`, la entidad en `lib/models/`, el DAO en
`lib/repositories/` y el controlador conectado al repositorio. Su ejemplo
(`EjemploSQLite`) usa Floor sobre `sqflite`.

**Por qué importa:** `CLAUDE.md` pide una decisión documentada antes de fijar
la base de datos. Las 17 ramas comparten `AppDatabase`.

**A confirmar:** si el equipo adopta Floor (`floor`, `floor_generator` y
`build_runner`) para los datos de dominio locales. No cubre el backend
remoto, las preferencias de interfaz (`shared_preferences`) ni las
credenciales.

**Estado:** confirmado el 2026-10-27 como parte de la segunda etapa (ver la
entrada "El proyecto entra en la segunda etapa").

## 2026-10-27 — Decisión tomada: Firebase, Supabase y Firebase Authentication

**Decisión del equipo (cerrada):**

| Necesidad | Tecnología acordada |
|---|---|
| Base de datos principal (datos de dominio en la nube: reservas, moteles, habitaciones, pagos, PQRS, etc.) | **Firebase** |
| Datos maestros (catálogos y listas de referencia, por ejemplo indicativos telefónicos, tipos de documento, ciudades) | **Supabase**, consultado mediante **API REST** |
| Sistema de autenticación | **Firebase Authentication** (`firebase_auth`) |

**Por qué importa:** `CLAUDE.md` y `README.md#estado-y-decisiones-pendientes`
exigían una decisión documentada antes de fijar base de datos y
autenticación. Con esta entrada esas dos decisiones dejan de estar
pendientes para las 17 ramas.

**Consecuencias:**

- Firebase Authentication reemplaza a Auth0 como proveedor de autenticación
  acordado. `auth0_flutter` y `Auth0AuthService` siguen en el código hasta
  que se complete la migración; no se debe construir funcionalidad nueva
  sobre Auth0. *(Completado el mismo día: ver "Retiro del código de
  Auth0".)*
- El acceso a Firebase y a Supabase va siempre detrás de servicios en
  `lib/service/` y repositorios; ninguna vista los consulta directamente.
- Las URL, llaves y configuración de Firebase/Supabase se inyectan por
  entorno (`--dart-define` o archivos de configuración ignorados por Git);
  nunca se versionan secretos.
- La autorización por rol sigue validándose en el backend (reglas de
  seguridad de Firebase / políticas de Supabase), no solo en la UI.

**Estado:** cerrado. Siguen pendientes la pasarela de pagos, el
almacenamiento de imágenes y la plataforma de despliegue.

## 2026-10-27 — El proyecto entra en la segunda etapa

**Cambio:** el proyecto pasa de la primera etapa (interfaz y datos mock) a la
**segunda etapa**, en la que se implementan elementos funcionales:

- **Consulta de maestros por API REST** contra Supabase.
- **Servicios SQL** para almacenar datos localmente (Floor sobre SQLite,
  `lib/database/app_database.dart`), lo que confirma la entrada
  "2026-10-06 — Floor (SQLite)" de este registro.
- **`shared_preferences`** para guardar o compartir datos locales no
  sensibles, como el último correo usado, preferencias y otros valores
  simples (ver [`shared_preferences.md`](shared_preferences.md)).

Como se anticipó en la entrada del 2026-09-23, en esta etapa cada persona
puede cambiar de funcionalidad; cada rama debe revisar su archivo en
`contexts/people/`.

**Estado:** cerrado.

## 2026-10-27 — Retiro del código de Auth0 (rama `feature-juan_pablo`)

**Cambio:** el login quedó conectado a Firebase Authentication
(`FirebaseAuthService`) y se eliminó el código de Auth0:
`auth0_auth_service.dart`, `auth0_config.dart`, la dependencia
`auth0_flutter` y los `manifestPlaceholders` de Auth0 en
`android/app/build.gradle.kts`. El contrato transitorio `AuthService` pasó a
`lib/service/auth/auth_service.dart` y los flags que no eran de Auth0
(`AUTH_USE_HARDCODED_AUTH_USERS`, `AUTH_USE_BACKEND_USERS`,
`AUTH_USERS_API_*`) a `AuthConfig` (`auth_config.dart`), con los mismos
nombres de `--dart-define`.

**Verificación:** `git grep` sobre todas las ramas remotas no encontró
imports de Auth0 fuera de los archivos propios del módulo de autenticación.

**Pendiente:** asignar el custom claim `role` desde el backend (hoy todo
usuario entra como Cliente) y definir dónde se guarda el perfil del usuario.
*(Superado por la entrada siguiente: el rol y el perfil viven en Cloud
Firestore; ya no se usa custom claim.)*

**Estado:** cerrado.

## 2026-10-27 — Cloud Firestore para perfiles de usuario y rol (rama `feature-juan_pablo`)

**Decisión:** el perfil del usuario se guarda en **Cloud Firestore**, en
`users/{uid}` (uid de Firebase Auth), y esa es la fuente del rol y del estado
de la cuenta (reemplaza el custom claim `role`, que exigiría Cloud
Functions). La autorización se valida en el backend con **reglas de
seguridad** (`firestore.rules`, referenciadas en `firebase.json`), no en la
UI.

**Esquema de `users/{uid}`:** `fullName`, `email` (normalizado),
`phoneNumber` (con indicativo), `role` (`client` | `owner` | `admin`),
`accountStatus` (`active` | `pending_approval` | `rejected` | `disabled`) y
`createdAt` (timestamp de servidor). No se guarda documento de identidad.

**Estado inicial por rol:** el registro público solo crea `client`
(`active`) u `owner` (`pending_approval`); nunca `admin`. El inicio de sesión
se bloquea con mensaje claro si la cuenta está pendiente, rechazada o
deshabilitada. Sin documento de perfil se asume cliente (mínimo privilegio).
Si falla la escritura del perfil al registrarse, se elimina la cuenta recién
creada. Un error de red al leer el perfil **no** cierra la sesión (el
usuario puede reintentar). En las reglas, `create` exige
`keys().hasOnly([...])` sobre los seis campos del esquema, `email` igual al
del token y `createdAt == request.time`; el `update` propio solo admite
`affectedKeys().hasOnly(['fullName', 'phoneNumber'])`, de modo que el usuario
no puede modificar `role`, `accountStatus`, `email` ni `createdAt`. Un admin
solo puede cambiar `accountStatus` (a `active`, `pending_approval`,
`rejected` o `disabled`), nunca el rol. `fullName` (3 a 100 caracteres) y
`phoneNumber` (4 a 20) se validan como texto al crear y al actualizar;
`delete` está denegado y todo lo demás se deniega por
defecto (cada rama agrega sus colecciones explícitamente, ver
[firebase.md](firebase.md)). Los nombres de colecciones están en
`lib/service/firebase/firestore_collections.dart`.

**Pendiente:** pantalla "Cuenta en revisión" para propietarios; creación de
administradores (manual en la consola o script, nunca desde la app);
flujo de aprobación/rechazo de propietarios por el admin. Las reglas se
desplegaron el 2026-10-27 (`firebase deploy --only firestore:rules`) y la
base de datos Firestore ya existe; cada cambio en `firestore.rules` debe
volver a desplegarse.

**Estado:** cerrado.

## 2026-10-20 — Maestro `phone_country_codes` (Supabase → caché SQLite)

**Contexto:** la funcionalidad de administración de moteles necesita el
maestro de códigos telefónicos de país. Se sigue el mismo patrón que el
maestro de servicios incluidos de habitaciones (`room_included_services`).

**Decisión:**
- La tabla remota vive en Supabase y se consulta por REST
  (`/rest/v1/phone_country_codes?select=*`) con el header `apikey`.
- Las credenciales se inyectan con `--dart-define`
  (`SUPABASE_URL`, `SUPABASE_ANON_KEY`), no se escriben en el repositorio.
- El resultado se cachea en la tabla local `phone_country_codes` (SQLite) y,
  si falla la red, se devuelve la caché.
- Se usa `sqflite` con DAO manual (sin `@entity` ni codegen nuevo) y el DAO
  se expone desde `AppDatabase` junto a los demás, con la migración `6 → 7`.
- Las carpetas siguen la convención ya usada por el módulo de habitaciones
  (`lib/database/repository/motel/`), no `lib/repositories/`.

**Nota:** el maestro en Supabase puede estar vacío; en ese caso la lista se
verá vacía hasta que se inserten filas en la tabla remota.

**Estado:** implementado en `lib/models/phone_country_code/`,
`lib/service/phone_country_code/`, `lib/database/repository/motel/` y
`lib/controllers/motel/phone_country_code_controller.dart`.

## 2026-10-28 — Moteles: Supabase + caché SQLite (Floor)

**Decisión:**
- Tabla remota `public.motels` con RLS (SELECT/INSERT/UPDATE para `anon`), sin DELETE (inhabilitación con `is_available = false`).
- Credenciales por `--dart-define` vía `SupabasePhoneCountryCodeConfig` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
- Caché local con Floor: `MotelEntity` (listas como JSON, booleano como INTEGER), `MotelDao` con `replaceAll`, `AppDatabase` v10 + `migration9To10` (la versión actual es 11; ver la entrada "Versión 11 de la base local").
- `MotelRepository`: red primero con `apikey`, `Prefer: return=representation`, decodificación UTF-8, fallback a caché en errores, excepción clara sin red/caché, 409 por NIT duplicado -> "Ya existe un motel con ese NIT", mapeo snake_case sin modificar `Motel`.
- `MotelController`: constructor opcional con `MotelRepository`, factory `MotelController.persistent()`; comportamiento mock por defecto preservado para otros módulos y tests.

**Estado:** implementado en `lib/database/model/motel/`, `lib/database/repository/motel/`, `lib/controllers/motel/`, vistas del propietario actualizadas con manejo de errores. Tests en `test/repositories/motel/`. Documentado en `docs/motels_persistence.md`.

## 2026-10-28 — Versión 11 de la base local y ajustes del registro (rama `feature-juan_pablo`)

**Base local:** la rama de moteles (PR #123) y esta rama publicaron cada una
una migración `9 → 10` distinta (`motels` y `country_phone_codes`). Al
fusionar se conservó la `9 → 10` de develop sin cambios y se agregó
`migration10To11`, que crea `country_phone_codes` y completa `motels` con
`IF NOT EXISTS`, de modo que ninguna base pierde datos venga de una rama o de
la otra. Versión actual: **11**. Para evitar repetirlo, las ramas deben
acordar el siguiente número de versión antes de crear una migración.

**Registro público:** se retiró la opción "Administrador" del selector de
tipo de cuenta (los administradores se crean en la consola de Firebase y las
reglas ya rechazaban ese registro).

**Contraseña:** login y registro exigen un mínimo de **8 caracteres**, sin
reglas de complejidad, mientras el proyecto esté en desarrollo
(`_passwordMinLength` en `lib/views/login/login_page.dart`). Endurecer antes
de producción.

**Firebase:** la base Firestore `(default)` existe (ubicación `nam5`), las
reglas se desplegaron el 2026-10-27 y `.firebaserc` fija el proyecto
`machuco`.

**Estado:** cerrado.

## 2026-11-04 — Retiro de las credenciales de prueba e indicativos con bandera (rama `feature-juan_pablo`)

**Credenciales de prueba:** se eliminó `HardcodedAuthService`, el flag
`AUTH_USE_HARDCODED_AUTH_USERS` (que estaba **encendido por defecto**) y el
aviso con los usuarios de prueba del login. Firebase Authentication es el
único proveedor; los integrantes crean sus cuentas con su correo. Las pruebas
usan servicios falsos inyectados. Las contraseñas antiguas siguen en el
historial de git: no deben reutilizarse en cuentas reales.

**Indicativos:** la tabla real de Supabase es `phone_country_codes`
(`country_code` ISO, `calling_code`); `country_phone_codes`, que consultaba
el registro, no existe en Supabase, por lo que el selector siempre caía a la
caché o a la semilla. `AuthCatalogRepository` ahora consulta
`phone_country_codes` siguiendo el patrón de `ClientRepository` y cachea con
el DAO compartido `PhoneCountryCodeDao`. La tabla local `country_phone_codes`
queda sin uso; se retira en una migración coordinada.

**Dependencia nueva:** `country_flags: ^4.1.2` (solicitada por la rama) para
pintar la bandera desde el código ISO. Solo se usa a través de
`AppCountryFlag`.

**Estado:** implementado.

## 2026-11-04 — Plan de autenticación social v1.0 y entorno Android (rama `feature-juan_pablo`)

**Aprobación:** el responsable de la rama aprobó el "Plan de autenticación
social v1.0" (`docs/auth/plan-auth-social.md`) el 2026-11-04, con las
decisiones D1-D5 y D7-D11. D6 no se decidió explícitamente.

**Implementado (etapa 7):**
- `applicationId` de producción `co.machuco.app` y flavor `dev`
  (`co.machuco.app.dev`), ambos en el proyecto Firebase `machuco`, con sus
  apps Android registradas.
- `google-services.json` único con los tres paquetes.
- Firma de desarrollo compartida mediante `android/key.properties` (no
  versionado), reutilizando `android/debug.keystore`
  (SHA-1 `8F:EE:77:0B:B3:26:19:EF:C3:7A:A1:99:C6:98:58:92:79:D2:8A:FE`).
- Se descartaron la ruta local de Java en `gradle.properties` y el bloque de
  firma roto de `build.gradle.kts`; `google-services` sigue en 4.4.4.
- `lib/firebase_options.dart` elige la app por `appFlavor`.
- Pruebas de `firestore.rules` con Emulator Suite + Node (`test_rules/`).
- Reglas e índice de `users` desplegados.

**Pendiente:** registrar el SHA-1/SHA-256 compartido en las apps
`co.machuco.app` y `co.machuco.app.dev`, el keystore de release, la OAuth
App de GitHub y habilitar los proveedores. Ver la sección 7 del plan y
`docs/auth/android-setup.md`.

**Estado:** etapa 7 implementada; etapas 1-6 y 8 pendientes.

## 2026-11-05 — Flavor por defecto `dev` (rama `feature-juan_pablo`)

`pubspec.yaml` declara `flutter: default-flavor: dev` para que `flutter run`
sin `--flavor` siga funcionando en Android en todas las ramas (sin él, Gradle
compila todas las variantes y Flutter no encuentra el APK). Producción se
compila siempre con `--flavor prod`. Aprobado por el responsable de la rama.


## 2026-11-09 — Gestión de administradores sin Cloud Functions (rama `feature-juan_pablo`)

**Contexto:** es un proyecto universitario y todo debe funcionar sin costos
(plan Spark de Firebase). Cloud Functions y el Admin SDK exigen el plan
Blaze, así que no se usan. Tampoco se agregan dependencias ni proveedores de
correo.

**Decisión (la autoridad son las reglas de Firestore, sin backend propio):**
- **Crear un administrador:** la app lo crea con una instancia secundaria de
  Firebase (`Firebase.initializeApp(name: ...)`), para no cerrar la sesión de
  quien lo crea, y escribe `users/{uid}` con la sesión del administrador
  principal. Genera una contraseña temporal (`Random.secure()`, 16
  caracteres) que quien crea ve una sola vez y entrega por su cuenta; nunca
  se guarda ni se registra. **No se envían correos ni SMS.** Si falla la
  escritura del perfil, se borra el usuario recién creado (reversión).
- **Primer ingreso:** el perfil nace con `mustChangePassword: true`. El
  nuevo administrador va directo a cambiar su contraseña
  (`AuthRoutes.adminChangePassword`); mientras tanto las reglas no lo tratan
  como administrador activo. Si pierde la contraseña, usa "¿Olvidaste tu
  contraseña?".
- **Eliminar a otro administrador:** se anonimiza `users/{uid}` (queda
  `fullName: 'Administrador eliminado'`, `accountStatus: 'anonymized'` y la
  auditoría) y pierde el acceso. **Eliminar la propia cuenta:** anonimiza y
  además borra su usuario con `User.delete()`. Los administradores ya no
  pueden borrar su `users/{uid}` (las reglas lo niegan).
- **Siempre debe existir un administrador activo:** `system/adminRegistry`
  guarda `activeAdminCount`. Crear suma 1 y anonimizar resta 1, en una
  transacción que lee el conteo; las reglas exigen ese cambio con `getAfter`
  y que el resultado sea >= 1. Cuenta todo administrador con
  `accountStatus == 'active'`, incluso con contraseña temporal pendiente
  (reemplaza la definición anterior "ya definió su contraseña").

**Limitación aceptada:** al eliminar a OTRO administrador su usuario sigue
existiendo en Firebase Auth (solo el Admin SDK puede borrarlo): su correo
queda ocupado y no se puede volver a crear un administrador con ese correo.
Mientras `isAdmin()` en `firestore.rules` solo compruebe el rol, esa cuenta
anonimizada conserva los accesos que dependan de `isAdmin()`; debe
endurecerse con la rama dueña de esas reglas. El conteo de `adminRegistry`
también puede desviarse si un administrador malintencionado escribe el
registro directamente (las reglas solo limitan el cambio a +-1).

**Estado:** implementado en cliente y reglas; las reglas se despliegan antes
que la nueva versión de la app.

## 2026-11-09 — Distribución privada del keystore compartido (rama `feature-juan_pablo`)

**Contexto:** el equipo debe poder entrar con Google y GitHub sin registrar
huellas propias en Firebase. El repositorio es público.

**Decisión:** `android/debug.keystore` y `android/key.properties` no se
versionan. El responsable de la rama los comparte de forma privada, solo con
los integrantes. Quien solo instala la app recibe un APK ya firmado y no
necesita el keystore.

**Motivo:** con el keystore en un repositorio público, cualquiera podría firmar
una app que Firebase aceptaría como `co.machuco.app`. Retirarlo después no
bastaría, porque quedaría en el historial de Git.

**Actualiza el pendiente del 2026-11-04:** el SHA-1/SHA-256 compartido está
registrado (2026-11-05) y el responsable de la rama confirmó que Google y GitHub
están habilitados en Firebase. Sigue pendiente el keystore de release.

## 2026-11-09 — `auth_user_profile` pasa a la versión 14 de SQLite (rama `feature-juan_pablo`)

**Contexto:** al fusionar `develop`, la versión 13 ya estaba ocupada por la
limpieza de ejemplos de room (riesgo R10 del plan de autenticación).

**Decisión:** se conserva el 12 -> 13 de `develop` y `auth_user_profile` se crea
en un 13 -> 14 con `CREATE TABLE IF NOT EXISTS`. Así migran tanto las bases v13
de `develop`, que no tienen la tabla, como las v13 de esta rama, que la conservan
con su fila. Estas últimas no ejecutan el 12 -> 13: sus ejemplos de room los
limpia `RoomDao.removeLegacyMockData`.

La próxima migración de cualquier rama usa la versión 15.

<<<<<<< HEAD
## 2026-11-09 — Propietarios ocupa las versiones 15, 16 y 17 de SQLite (rama `feature_juliang`)

**Contexto:** al fusionar `develop` en `feature_juliang`, la base compartida
quedó en la versión 14 (`auth_user_profile`) y el merge eliminó las migraciones
del módulo de propietarios. Algunas instalaciones de esta rama ya estaban en la
versión 16 (sus propias 12→13 `owners`, 13→14 indicativo, 14→15
`document_types` y 15→16 `pendingDelete`), de modo que se saltaron los pasos de
`develop`.

**Decisión:** se conservan el 12→13 y el 13→14 de `develop` y las migraciones de
propietarios se re-apilan por encima, todas idempotentes:

- `14→15`: crea `owners` con `countryCode`/`countryName` y `document_types` con
  sus cinco semillas.
- `15→16`: agrega `pendingDelete` a `owners`.
- `16→17`: reconciliación. Crea `auth_user_profile`, repite la limpieza de los
  ejemplos de room (sólo si existen las tablas de habitaciones) y reasegura el
  esquema de propietarios. Cubre las bases v16 de esta rama, que nunca
  ejecutaron el 13→14 de `develop`.

La versión local queda en **17**; la próxima rama que migre usa la 18.

## 2026-11-09 — Los propietarios viven en `users/{uid}` (rama `feature_juliang`)

**Contexto:** el módulo de propietarios escribía en una colección `owners`
propia, separada de los usuarios registrados. Eso duplicaba identidades: un
propietario que se registraba desde la app quedaba en `users` y otro creado por
el administrador quedaba en `owners`, sin cuenta de acceso.

**Decisión:** un propietario **es un usuario registrado**. El módulo lee
`users` con `role == 'owner'` y el panel de administración hace el CRUD ahí:

- Crear crea la cuenta en Firebase Auth con `AuthAccountProvisioner` y una
  contraseña temporal (se muestra una sola vez), y escribe `users/{uid}` con
  `role = owner`, `mustChangePassword = true` y el estado inicial que elija el
  administrador (`active` o `pending_approval`).
- Los datos legales se guardan en `documentType`/`documentNumber`/`address` y
  se mantienen sincronizados con `nit`/`personType` (NIT → `juridica`) para no
  romper el registro público ni las reglas de aprobación existentes.
- Editar solo toca datos legales y de contacto (nunca correo, rol ni estado).
- Eliminar borra el documento `users/{uid}`. La cuenta de Firebase Auth no se
  puede borrar desde el cliente (no hay Admin SDK); queda huérfana y su correo
  sigue tomado, igual que en `anonymizeAdministrator`.
- La colección `owners` queda obsoleta y se borra a mano desde la consola.
- El estado local de SQLite sube a la versión **18** (`accountStatus`); la
  próxima rama que migre usa la 19.

## 2026-11-09 — Se retiran los datos demo de propietarios

**Contexto:** el módulo sembraba tres propietarios de demostración en SQLite y
la versión anterior guardaba ids temporales `owner-...` para documentos que
vivían en la colección `owners`. Al pasar el listado a `users`, esas filas
aparecían como propietarios que no existen en Firebase.

**Decisión:** ya no se siembran datos demo; el listado refleja únicamente los
usuarios con `role = owner`. La migración **18→19** borra del dispositivo las
filas con id `owner-...` (idempotente: un uid de Firebase Auth nunca empieza
por ese prefijo). La próxima rama que migre usa la 20.

## 2026-11-09 — Perfil del propietario y bloqueo de eliminación con moteles

**Contexto:** la vista de moteles del propietario usaba un id y nombres
quemados (`owner-1020304050`, «Laura Gómez») y no existía una pantalla para que
el propietario viera o ajustara sus datos. Además, borrar un propietario con
moteles dejaba los moteles huérfanos.

**Decisión:**

- La vista toma el uid de `CurrentUser` y el nombre de `users/{uid}`; se retira
  el selector de propietarios de ejemplo.
- Se agrega «Mi perfil» (`/motels/owner/profile`): el propietario ve sus datos
  y edita solo nombre y teléfono, que es lo que las reglas permiten
  autoeditar. El documento, el rol y el estado siguen siendo del administrador.
- `deleteOwner` se bloquea si el propietario tiene moteles: se listan los
  nombres y se pide reasignarlos o eliminarlos. Si no se puede verificar por
  falta de red, también se bloquea. No se elige transferencia automática para
  no reasignar moteles sin que un humano lo confirme.

## 2026-11-09 — Cambio de contraseña del propietario y nombre completo

**Contexto:** las cuentas de propietario creadas por el panel nacen con
`mustChangePassword = true`, pero no había forma de que el propietario
reemplazara esa contraseña. Además, algunos chips partían `fullName` y mostraban
solo el primer nombre.

**Decisión:**

- «Mi perfil» incluye **Cambiar contraseña** (`/motels/owner/profile/password`):
  valida con `AuthValidators`, usa `PasswordChangeService` y limpia
  `mustChangePassword` si estaba activo. Las reglas actuales ya lo permiten.
- El nombre se muestra siempre como `fullName` completo; no se parte ni se
  abrevian los chips (el avatar conserva las iniciales por estética).
- Quedan como tareas futuras la transferencia automática de moteles al
  eliminar un propietario y el guard que obligue a cambiar la contraseña
  temporal al iniciar sesión.

## 2026-11-09 — Transferencia de moteles al eliminar un propietario

**Contexto:** el borrado de un propietario con moteles se bloqueaba con un
mensaje, obligando a reasignar los moteles a mano por fuera de la app.

**Decisión:** el mismo flujo de eliminación reasigna los moteles. El controlador
expone `OwnerDeletionBlocker` (moteles + demás propietarios como candidatos) y
la pantalla abre un cuadro con la lista de moteles y un selector de destino. Al
confirmar se ejecuta `MotelRepository.reassignMoteles` (un `PATCH` a Supabase
más la caché local) y solo entonces se borra `users/{uid}`. Si la reasignación
falla no se elimina nada. Queda como tarea futura poder **eliminar** los
moteles desde ese mismo cuadro.

Además, las acciones de «Mi perfil» pasan a una barra inferior fija: el botón
de cambiar contraseña quedaba al final del listado y no siempre era visible.

## 2026-11-09 — Acceso a solicitudes de propietarios y perfil del administrador

**Contexto:** el módulo de aprobación de propietarios (`OwnerApprovalsPage`,
`AdminAccessController`) existía pero solo se llegaba por un acceso directo de
desarrollo. El administrador tampoco tenía una pantalla de perfil.

**Decisión:**

- El panel de Propietarios estrena menú lateral con **Solicitudes de
  propietarios** (contador de `pending_approval`), **Mi perfil** y **Cerrar
  sesión**. Además, con pendientes se muestra una tarjeta «N solicitudes» con
  acción «Revisar».
- Se agrega el perfil del administrador (`/auth/admin/profile`) para ver sus
  datos y editar nombre y teléfono (lo que `isAdminContactEdit` permite) y
  cambiar la contraseña. Con `mustChangePassword` la edición queda bloqueada
  hasta cambiar la temporal.
- Las piezas comunes se renombran a nombres neutrales: `UserProfileController`,
  `UserEditProfilePage`, `ChangePasswordPage` y `AccountStatusChip`, de modo que
  propietario y administrador compartan el mismo código.
- Sin cambios en `firestore.rules`.
=======
## 2026-11-07 — Reservas en Firestore y propietarios por uid (rama `feature_daniel`)

**Decisión:** las reservas se sincronizan con la colección `reservations` de
Cloud Firestore (SQLite queda como caché local), aplicando la decisión del
2026-10-27 de que los datos de dominio van en Firebase. Supabase guarda solo
los maestros `reservation_categories` y `country_phone_codes`
(`supabase/migrations/202611070001_*` y `202611070002_*`).

**Propiedad de moteles:** `motels.owner_id` debe ser el uid de Firebase del
propietario. Antes tenía ids de demostración (`owner-1020304050`) porque
`OwnerMotelsPage` y `MotelController.getMyMotels` los fijaban en el código, y
ninguna regla basada en `request.auth.uid` (reservas ni pagos) podía
autorizar a un propietario real. Ahora usan `CurrentUser.uidOrNull` y solo sin
sesión el propietario de demostración.

**Versión SQLite:** al fusionar `develop` (v13 y v14 ya ocupadas), las
tablas de reservas se crean en la migración 14 -> 15 con `CREATE TABLE IF NOT
EXISTS`. La próxima migración de cualquier rama usa la versión 16.

**Pendiente:** reasignar en Supabase los moteles de demostración a cuentas de
propietario reales y desplegar `firestore.rules`.

## 2026-11-09 — Firebase Analytics para toda la app (rama `feature_daniel`)

**Contexto:** el profesor pidió conectar la app con Firebase, en especial con
el módulo de Analytics. Firebase ya es la plataforma decidida (2026-10-27),
así que no se evaluaron alternativas.

**Decisión:** se agrega `firebase_analytics: ^13.0.1` (compatible con
`firebase_core ^5.1.0`) detrás de un único `AnalyticsService`
(`lib/service/analytics/`), con el mismo patrón de proveedor estático que los
repositorios: no-op por defecto y Firebase desde `main`. Las pantallas se
reportan solas con `AnalyticsRouteObserver`; los eventos de autenticación y
de reservas, desde sus controllers y servicios. El detalle de eventos y cómo
agregar uno está en [firebase.md](firebase.md#5-analytics-firebase-analytics).

**Privacidad:** solo se envían identificadores técnicos (uid, ids de motel),
montos y estados; nunca nombres, correos, celulares ni NIT. La analítica es
best effort: un error al reportar nunca interrumpe el flujo.

**Pendiente:** registrar `user_role` como dimensión personalizada en la
consola y que cada rama agregue los eventos de su módulo.

## 2026-11-09 — Reglas de Firestore restauradas tras un despliegue incompleto (rama `feature_daniel`)

**Problema:** las reglas publicadas en `machuco` se desplegaron desde una copia
local que no estaba en ninguna rama de GitHub. Traían cambios nuevos de
`users` (creación y edición de propietarios por un admin, `isAdminOwnerCreation`
e `isAdminOwnerEdit`), pero no los bloques `match /reservations` ni
`match /owners`, así que la regla por defecto negaba esas colecciones: las
reservas de todos los integrantes dejaron de sincronizarse
(`PERMISSION_DENIED`).

**Decisión:** `firestore.rules` pasa a ser exactamente lo publicado más los
bloques de `reservations` (y sus funciones) y `owners`, sin quitar nada de lo
publicado. Se desplegó el 2026-11-09 y se verificó con una reserva real.
`test_rules/reservations.rules.test.mjs` cubre la colección para que un
despliegue sin ella falle en las pruebas.

**Pendiente:** quien hizo el despliegue debe subir sus cambios de reglas y de
app a su rama. El test existente "nadie elimina el perfil de otro, ni siquiera
un admin" falla con las reglas publicadas, porque ahora un admin activo puede
borrar cuentas que no son de administrador; su dueño decide si actualiza el
test o la regla. Antes de cada despliegue hay que partir de las reglas
publicadas o de `develop` actualizado, nunca de una copia local vieja.

## 2026-11-09 — Moteles pasan a Firebase SQL Connect (rama `feature_marco`)

**Contexto:** la decisión del 2026-10-27 fija Firebase como base de datos
principal y Supabase solo para datos maestros. Los moteles estaban en
Supabase (entrada del 2026-10-28) y a la rama de moteles se le asignó
implementar Firebase SQL Connect (antes Data Connect).

**Decisión:**

- Los moteles se guardan en **Firebase SQL Connect** (PostgreSQL), servicio
  `machuco-service` en `us-east4`, instancia `machuco-instance`, base
  `machuco-database` (prueba gratuita del plan Spark, activada el
  2026-11-09; dura 90 días). Esquema y conector `motel` desplegados el
  2026-11-09 con la CLI 15.34.1.
- Tabla `motels` en `dataconnect/schema/motel.gql`, conector `motel` en
  `dataconnect/motel/`. Código generado en `lib/service/sql_connect/motel_connector/`.
- El dueño lo fija el backend con el uid del token de Firebase Auth
  (`auth.uid`): un propietario solo lista, crea y edita sus moteles.
- Se conserva la caché local en Floor (`MotelDao`) para lectura sin red.
- Se retira el repositorio de moteles de Supabase. Los indicativos
  telefónicos siguen en Supabase (son un maestro).
- Convención para el equipo: un archivo de esquema y una carpeta de
  conector por funcionalidad. Ver `docs/sql_connect.md`.

**Pendiente:**

- Las operaciones de administrador (`ListAllMotels`, `AdminCreateMotel`,
  `AdminUpdateMotel`) exigen el custom claim `role: 'admin'` en el token de
  Firebase Auth. Hasta que la rama de autenticación lo agregue, nadie puede
  usarlas.
- Antes de que terminen los 90 días hay que decidir si se pasa a Blaze.

**Actualización (2026-11-09):** cada motel se copia también en Firestore
(`motels/{motelId}`, mismo UUID, colección propia de esta rama) para que
otros módulos lo consulten desde sus reglas. Lo escriben el administrador y
el propietario activo con su propio `ownerId`. La regla `room_motels` de la
rama de habitaciones no se modificó.
>>>>>>> 5146107eb4335446d3972278be0976fe9942f220
