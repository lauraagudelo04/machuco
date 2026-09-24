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
