# Contexto - Funcionalidad de autenticación: login y registro (rama: feature-juan_pablo)

> **Cambio de funcionalidad**: esta rama dejó de ser dueña del módulo
> "Bookings". Ahora es dueña del **módulo de autenticación** (inicio de
> sesión, registro, recuperación de contraseña, sesión persistente, caché del
> perfil del usuario autenticado en SQLite, cierre de sesión y eliminación de
> la propia cuenta), de la **creación de administradores** y de la
> **aprobación de propietarios** desde la vista del administrador. El código de bookings ya
> construido permanece en el repositorio pero no debe modificarse desde esta
> rama salvo para corregir una ruptura causada por cambios de autenticación.

## Rol del usuario

Visitante no autenticado (antes del login) y, después de autenticarse,
Cliente, Propietario o Administrador del sistema.

Es una sola funcionalidad ("acceso a la aplicación") que sirve a los tres
roles: todos usan la misma pantalla de login y el mismo `LoginController`; lo
único que cambia por rol es la ruta de destino después de autenticarse. El
Administrador además tiene dos vistas propias de esta rama: "Administradores"
(crear otros administradores) y "Solicitudes de propietarios" (aprobar o
rechazar cuentas `pending_approval`).

## Decisiones de esta rama

- **Proveedor de seguridad: exclusivamente Firebase Authentication**
  (identidad, sesión, correo/contraseña y recuperación de contraseña).
- **Proveedor de almacenamiento: Firebase**. El perfil del usuario (incluidos
  NIT y tipo de persona), las solicitudes de propietarios y los archivos se
  guardan en Firebase (Cloud Firestore y/o Cloud Storage, pendiente de
  confirmar cuál) protegidos por reglas de seguridad. Los **maestros** siguen
  en Supabase.
- **Proveedores externos (Google/Gmail y GitHub): implementados** a través de
  Firebase Auth (`FirebaseSocialAuthService`, `SocialAuthButtons`, "Completar
  perfil"; ver `docs/auth/plan-auth-social.md`). *(Texto anterior: "solo
  definidos, no implementados".)*
- **Credenciales de prueba retiradas (decisión 2026-11-04)**: los
  integrantes del proyecto ya crean sus propios usuarios con correo en
  Firebase Auth, así que se **elimina** el login quemado: el
  `HardcodedAuthService`, el flag `AUTH_USE_HARDCODED_AUTH_USERS`, el aviso
  de modo desarrollo, la lista de usuarios de prueba y los escenarios
  **[Temporal]**. Ver la feature "Retiro de las credenciales de prueba".
  Las cuentas `admin` de prueba se crean a mano en la consola de Firebase
  (`users/{uid}` con `role: admin`) hasta que exista "Creación de
  administradores".
- **Contrato `AuthService` reducido**: sin login quemado, el contrato deja de
  ser una abstracción multiproveedor. Solo se conserva (si se conserva) como
  costura para inyectar un servicio falso en las pruebas; Firebase Auth es
  el único proveedor real. No se agregan implementaciones alternativas.
- **Registro público solo para Cliente y Propietario**. Los administradores
  **no se registran desde la pantalla principal**: solo otro administrador
  puede crearlos desde la vista "Administradores". Se descarta el mecanismo
  de código de invitación.
- **SharedPreferences**: preferencias locales no sensibles del login y el
  **correo del usuario autenticado**, que se comparte entre pantallas y
  funcionalidades, a través de `LocalPreferencesService` con namespace
  `auth`.
- **SQLite (Floor / `AppDatabase`)**: caché local de los maestros de Supabase
  y del perfil básico del usuario autenticado (tabla `auth_user_profile`, una
  sola fila; ver "Perfil del usuario autenticado en SQLite"). Firestore
  (`users/{uid}`) sigue siendo la fuente de verdad.
- **Eliminación de cuenta**: el usuario autenticado puede eliminar su propia
  cuenta tras reautenticarse. Se borran su perfil en Firestore, su usuario en
  Firebase Auth y todos sus datos locales (SQLite y SharedPreferences).
- **Supabase**: fuente de los maestros de **indicativo telefónico por país**
  y de **planes de suscripción para propietarios**, consumidos por REST
  (`/rest/v1/...`) con el mismo patrón de `RoomServiceRepository` (caché
  primero, red después). El maestro de planes reutiliza la tabla
  `subscription_plans` que ya consume la rama de suscripciones; se amplía en
  coordinación con ella, no se duplica.
- **Sin documento de identidad**: ningún perfil (Cliente, Propietario ni
  Administrador) solicita tipo ni número de documento. Se retira el maestro
  `identification_types` del alcance de esta rama.
- **NIT y tipo de persona del Propietario**: todo propietario, sea persona
  **natural** o **jurídica**, debe indicar su tipo de persona y su **NIT**
  (dato tributario, no documento de identidad). La razón social solo se pide
  a la persona jurídica.

> **Estado de la dependencia de Firebase (verificado 2026-10-27)**:
> integrada. `pubspec.yaml` incluye `firebase_core`, `firebase_auth` y
> `cloud_firestore`; existen `android/app/google-services.json`,
> `lib/firebase_options.dart` (FlutterFire) y `firebase.json`, y
> `lib/main.dart` inicializa Firebase. No existe
> `ios/Runner/GoogleService-Info.plist`. Auth0 fue retirado. El login usa
> `FirebaseAuthService` y el perfil, rol y estado viven en
> Cloud Firestore (`users/{uid}`) protegidos por `firestore.rules`. Las
> decisiones están en `docs/decisions_log.md` (2026-10-27 y 2026-10-28).
> Al 2026-10-28 la base Firestore existe (`nam5`), las reglas están
> desplegadas y `.firebaserc` fija el proyecto `machuco`. Pendiente solo
> confirmar en la consola que Correo/contraseña está habilitado. Ver
> `docs/firebase.md`.
>
> **Revisión del código (2026-11-04)**:
> - Recuperar contraseña: implementado en
>   `FirebaseAuthService.requestPasswordReset` (trata `user-not-found` como
>   éxito para no revelar el correo).
> - Eliminar cuenta: **no implementado**. Solo existe `_rollbackAccount`
>   (borra la cuenta huérfana si falla el registro); no hay operación ni vista
>   para que el usuario elimine su cuenta.
> - Perfil en SQLite: **no implementado**. `AppDatabase` (versión 12) no tiene
>   tabla del perfil del usuario; el perfil solo se lee de Firestore con
>   `UserProfileRepository`.
> - Credenciales de prueba: **retiradas (2026-11-04)**. Se borró
>   `hardcoded_auth_service.dart`, el flag `AUTH_USE_HARDCODED_AUTH_USERS`
>   (estaba encendido por defecto) y el aviso del login; `test/widget_test.dart`
>   usa un servicio falso por rol.
> - Indicativos: la tabla real de Supabase es `phone_country_codes`; la que se
>   consultaba (`country_phone_codes`) no existía. **Corregido (2026-11-04)**
>   con banderas de `country_flags` (ver "Lista de indicativos con bandera").

## Feature: Inicio de sesión

> Los escenarios se escriben contra Firebase Auth, que es el único
> proveedor (las credenciales de prueba se retiran, ver "Retiro de las
> credenciales de prueba").

Scenario: Usuario inicia sesión con correo y contraseña (camino feliz)
Given un usuario registrado en la pantalla de login
When ingresa un correo válido y su contraseña
And presiona "Ingresar"
Then el sistema autentica al usuario con Firebase Auth
And obtiene su rol (Cliente, Propietario o Administrador)
And guarda el perfil básico del usuario en SQLite
And guarda el correo del usuario autenticado en SharedPreferences para compartirlo con el resto de la app
And navega a la ruta inicial correspondiente a su rol mediante `resolvePostLoginRoute`
But si la cuenta está en `pending_approval`, navega a "Cuenta en revisión" sin importar el rol

Scenario: Credenciales inválidas
Given un usuario en la pantalla de login
When ingresa un correo o una contraseña incorrectos y presiona "Ingresar"
Then el sistema muestra un mensaje genérico "Correo o contraseña incorrectos"
And no indica cuál de los dos campos falló
And el usuario permanece en la pantalla de login con el correo conservado

Scenario: Validación local de campos antes de enviar
Given un usuario en la pantalla de login
When deja el correo o la contraseña vacíos, o escribe un correo con formato inválido
And presiona "Ingresar"
Then el sistema no llama al servicio de autenticación
And señala junto a cada campo inválido el motivo del error

Scenario: Prevención de doble envío
Given un usuario que acaba de presionar "Ingresar"
When la autenticación todavía está en curso
Then el botón muestra un estado de carga y queda deshabilitado
And un segundo toque no genera una segunda petición

Scenario: Error de red al iniciar sesión
Given un usuario con credenciales válidas
When presiona "Ingresar" y la conexión falla antes de recibir respuesta
Then el sistema muestra un error de conexión comprensible con opción de reintentar
And no lo trata como credenciales inválidas

Scenario: Cuenta deshabilitada
Given un usuario cuya cuenta fue deshabilitada por un administrador
When intenta iniciar sesión con credenciales correctas
Then el sistema rechaza el acceso indicando que la cuenta está deshabilitada
And no crea sesión ni guarda el perfil en SQLite ni el correo de sesión en SharedPreferences

Scenario: Propietario rechazado intenta iniciar sesión
Given un propietario cuya solicitud fue rechazada por un administrador (estado `rejected`)
When inicia sesión con credenciales correctas
Then el sistema muestra que su solicitud fue rechazada y el motivo registrado
And no le da acceso a las vistas del propietario

Scenario: Recordar correo electrónico
Given un usuario que marca la opción "Recordar mi correo" e inicia sesión con éxito
When vuelve a abrir la pantalla de login en otro momento
Then el campo de correo aparece precargado con el último correo usado (leído de SharedPreferences)
But si desmarca la opción, el correo recordado se elimina de SharedPreferences

Scenario: Restauración automática de la sesión al abrir la app
Given un usuario que inició sesión previamente y no cerró sesión
When abre la aplicación
Then el sistema restaura la sesión con Firebase Auth
And carga desde SharedPreferences el correo del usuario autenticado
And navega directamente a la ruta de su rol sin mostrar el formulario de login
But si la sesión expiró o no puede restaurarse, borra el correo de sesión y muestra la pantalla de login

Scenario: Cierre de sesión
Given un usuario autenticado en cualquier vista de su rol
When selecciona "Cerrar sesión"
Then el sistema cierra la sesión en Firebase Auth
And elimina el perfil del usuario guardado en SQLite, el correo de sesión y las preferencias de sesión
But conserva el correo recordado si el usuario tenía activa la opción "Recordar mi correo"
And conserva la caché de maestros (no es información personal)
And navega a la pantalla de login sin permitir volver atrás a una vista protegida

## Feature: Recuperación de contraseña

> Implementada con `FirebaseAuth.sendPasswordResetEmail`. El enlace del
> correo abre la página de restablecimiento alojada por Firebase; la app no
> recibe ni define la nueva contraseña.

Scenario: Solicitar el restablecimiento (camino feliz)
Given un usuario en la pantalla de login
When presiona "¿Olvidaste tu contraseña?"
Then se abre un AppBottomSheet con el campo de correo precargado con lo que ya escribió en el login
When confirma con "Enviar instrucciones"
Then el sistema solicita a Firebase Auth el envío del correo de restablecimiento
And muestra un mensaje neutro: "Si el correo está registrado, recibirás instrucciones"
And no revela si el correo existe o no

Scenario: Correo no registrado
Given un usuario que ingresa un correo con formato válido que no tiene cuenta
When confirma "Enviar instrucciones"
Then el sistema muestra exactamente el mismo mensaje neutro y el mismo tiempo de respuesta percibido que en el camino feliz
And no se envía ningún correo

Scenario: Correo vacío o con formato inválido
Given un usuario en el panel de recuperación
When deja el correo vacío o escribe un formato inválido y confirma
Then el sistema no llama a Firebase Auth
And señala el error junto al campo

Scenario: Prevención de doble envío y límite de intentos
Given un usuario que acaba de presionar "Enviar instrucciones"
When la petición sigue en curso
Then el botón muestra estado de carga y queda deshabilitado
And tras una respuesta exitosa el botón queda deshabilitado 60 segundos con una cuenta regresiva
But si Firebase responde `too-many-requests`, muestra "Demasiados intentos. Intenta más tarde" sin revelar si el correo existe

Scenario: Error de red al solicitar el restablecimiento
Given un usuario sin conexión
When confirma "Enviar instrucciones"
Then el sistema muestra un error de conexión con opción de reintentar
And no muestra el mensaje neutro de éxito

Scenario: Restablecer la contraseña desde el enlace
Given un usuario que recibió el correo de restablecimiento
When abre el enlace y define una nueva contraseña que cumple la política
Then puede iniciar sesión con la nueva contraseña
And la contraseña anterior deja de funcionar
But si el enlace expiró o ya se usó, la página de Firebase informa que debe solicitar uno nuevo

Scenario: Sesiones abiertas después de restablecer la contraseña
Given un usuario con sesión iniciada en otro dispositivo
When restablece su contraseña
Then al expirar el token, la restauración automática de la sesión en ese dispositivo falla
And la app borra el correo de sesión y el perfil en SQLite y muestra la pantalla de login

Scenario: Correo de restablecimiento en español
Given el proyecto de Firebase `machuco`
When se envía un correo de restablecimiento
Then la plantilla está en español, con el nombre "Machuco" y sin datos personales distintos del correo

### Casos de prueba

| ID | Tipo | Caso | Resultado esperado |
| --- | --- | --- | --- |
| PR-01 | Unitaria (servicio) | `requestPasswordReset` con correo válido | Llama a `sendPasswordResetEmail` con el correo recortado y en minúsculas |
| PR-02 | Unitaria (servicio) | Firebase lanza `user-not-found` | Completa sin error (mismo resultado que PR-01) |
| PR-03 | Unitaria (servicio) | Firebase lanza `invalid-email` | `AuthFailure` con mensaje de correo inválido |
| PR-04 | Unitaria (servicio) | Firebase lanza `network-request-failed` | `AuthFailure` de tipo `network` |
| PR-05 | Unitaria (servicio) | Firebase lanza `too-many-requests` | `AuthFailure` con mensaje de demasiados intentos |
| PR-06 | Unitaria (controller) | Correo vacío, `usuario@`, `' OR '1'='1' --` | No llama al servicio; error de validación |
| PR-07 | Unitaria (controller) | Dos llamadas seguidas mientras la primera está en curso | Una sola petición al servicio |
| PR-08 | Widget | Abrir el panel con correo escrito en el login | Campo precargado; mensaje neutro tras confirmar |
| PR-09 | Widget | Éxito seguido de nuevo toque | Botón deshabilitado con cuenta regresiva |
| PR-10 | Manual | Flujo real con un correo del equipo | Llega el correo en español; el enlace permite cambiar la contraseña; el enlace usado no sirve dos veces |

### Riesgos

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| Enumeración de correos (mensajes o tiempos distintos según exista la cuenta) | Exposición de qué correos están registrados | Mensaje y flujo idénticos; mapear `user-not-found` a éxito; activar "Email enumeration protection" en la consola de Firebase |
| Abuso del envío (spam a terceros) | Bloqueo del proyecto por cuota o reputación del remitente | Enfriamiento de 60 s en la app; límites propios de Firebase; considerar App Check |
| El correo llega a spam o en inglés | El usuario no puede recuperar su cuenta | Configurar la plantilla en español y el dominio del remitente en la consola; probarlo con PR-10 |
| Phishing que imita el correo de restablecimiento | Robo de credenciales | Plantilla con remitente y dominio consistentes; nunca pedir la contraseña por otro canal |
| Política de contraseña de la página de Firebase distinta a la de la app | Contraseñas que la app rechazaría | Configurar la política de contraseñas en Firebase Auth igual a la de la app |

## Feature: Perfil del usuario autenticado en SQLite

> Caché local de **una sola fila** con el perfil básico del usuario que
> inició sesión, en la tabla `auth_user_profile` de `AppDatabase` (migración
> 12 → 13, coordinar el número con las otras ramas). Firestore
> (`users/{uid}`) es la fuente de verdad; SQLite solo sirve para mostrar
> datos sin esperar a la red. **No autoriza nada.**

### Tabla `auth_user_profile`

| Columna | Tipo | Notas |
| --- | --- | --- |
| `uid` | `TEXT` PK | uid de Firebase Auth |
| `email` | `TEXT` | Normalizado en minúsculas |
| `first_names` | `TEXT` | |
| `last_names` | `TEXT` | |
| `role` | `TEXT` | `client` / `owner` / `admin` (solo para mostrar) |
| `account_status` | `TEXT` | `active` / `pending_approval` / `rejected` / `disabled` |
| `phone_country_code_id` | `INTEGER` nullable | id del maestro `country_phone_codes` |
| `phone_number` | `TEXT` nullable | |
| `company_name` | `TEXT` nullable | Solo propietario jurídico |
| `synced_at` | `TEXT` | ISO-8601 de la última sincronización con Firestore |

No se guardan contraseñas, tokens, NIT ni fecha de nacimiento en SQLite.

Scenario: Guardar el perfil al iniciar sesión o registrarse
Given un usuario que inicia sesión o se registra con éxito
When el sistema obtiene su perfil de Firestore
Then guarda el perfil básico en `auth_user_profile` con `synced_at` actual
And reemplaza cualquier fila anterior (solo existe el perfil del usuario actual)

Scenario: Otro usuario inicia sesión en el mismo dispositivo
Given un dispositivo con el perfil guardado del usuario A
When el usuario B inicia sesión
Then la fila de A se elimina y se guarda solo la de B
And ninguna vista muestra datos de A

Scenario: Mostrar el perfil desde SQLite al abrir la app
Given un usuario con sesión válida y perfil guardado en SQLite
When abre la aplicación
Then las vistas muestran nombre, correo y rol desde SQLite sin esperar a la red
And el sistema refresca el perfil desde Firestore en segundo plano y actualiza la fila

Scenario: El perfil cambió en Firestore
Given un perfil en SQLite con `account_status: pending_approval`
When al refrescar, Firestore indica `active` (o `disabled`, o un rol distinto)
Then el sistema actualiza la fila de SQLite
And recalcula la ruta con `resolvePostLoginRoute` usando el dato de Firestore, no el de la caché

Scenario: Sin conexión al abrir la app
Given un usuario con sesión válida, perfil en SQLite y sin conexión
When abre la aplicación
Then puede ver los datos de su perfil desde la caché
And las operaciones que requieren backend muestran error de conexión con opción de reintentar

Scenario: Eliminar el perfil local
Given un usuario con perfil guardado en SQLite
When cierra sesión, elimina su cuenta, su cuenta resulta `disabled` o la sesión no se puede restaurar
Then el sistema elimina la fila de `auth_user_profile`
And conserva la caché de maestros

Scenario: Otra funcionalidad consulta el perfil local
Given un usuario autenticado
When otra pantalla (perfil de cliente, PQRS, reservas) necesita su nombre o correo
Then lo obtiene a través del repositorio de esta rama (p. ej. `AuthUserProfileRepository.loadCurrent()`), nunca consultando la tabla directamente
And si no hay perfil guardado recibe `null`

### Casos de prueba

| ID | Tipo | Caso | Resultado esperado |
| --- | --- | --- | --- |
| SQ-01 | Unitaria (DAO, SQLite en memoria) | Insertar perfil y leerlo por `uid` | Mismos valores; `synced_at` guardado |
| SQ-02 | Unitaria (DAO) | Guardar A y luego B | La tabla tiene solo B |
| SQ-03 | Unitaria (DAO) | Borrar el perfil | La lectura devuelve `null` |
| SQ-04 | Unitaria (DAO) | Nombres con `'; DROP TABLE auth_user_profile; --` | Se guarda como texto literal; la tabla sigue existiendo |
| SQ-05 | Migración | Abrir una base en versión 12 y migrar a 13 | La tabla existe; los datos de las demás tablas se conservan |
| SQ-06 | Unitaria (controller) | Login exitoso | Llama a guardar el perfil una vez |
| SQ-07 | Unitaria (controller) | Login con cuenta `disabled` | No guarda el perfil |
| SQ-08 | Unitaria (controller) | Logout | Borra el perfil y conserva los maestros |
| SQ-09 | Unitaria (controller) | Caché dice `pending_approval`, Firestore dice `active` | Ruta resuelta con `active`; fila actualizada |
| SQ-10 | Unitaria (repositorio) | Leer sin perfil guardado | Devuelve `null`, sin excepción |

### Riesgos

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| Datos personales en claro en el dispositivo (la base de SQLite no está cifrada) | Exposición en dispositivos con root o respaldos | Guardar solo datos básicos; nunca NIT, fecha de nacimiento, tokens ni contraseñas; borrar al cerrar sesión |
| Usar la caché para decidir accesos | Un usuario deshabilitado o con rol cambiado sigue entrando | La ruta y la autorización se deciden con Firestore y las reglas; la caché solo se muestra |
| Datos de un usuario anterior visibles al siguiente | Fuga de información entre usuarios del mismo dispositivo | Una sola fila; borrar antes de guardar; SQ-02 |
| Choque de versión de migración con otras ramas | La app falla al abrir en dispositivos actualizados | Coordinar el número de versión antes del merge; prueba SQ-05 |
| Caché desactualizada | El usuario ve datos viejos | Refrescar en segundo plano en cada arranque y tras cada login |

## Feature: Eliminación de la cuenta

> Cualquier usuario autenticado (Cliente, Propietario o Administrador) puede
> eliminar **su propia** cuenta desde su perfil o menú. Firebase exige un
> inicio de sesión reciente para `User.delete()`, por eso se pide la
> contraseña antes de eliminar. Destino: una operación de backend (Cloud
> Function con Admin SDK) que borre perfil y usuario de forma atómica;
> mientras no exista, la app lo hace en el orden indicado abajo. Respaldo
> legal: derecho de supresión de la Ley 1581 de 2012.

> **Qué pasa con los datos según el rol (decisión 2026-11-08)**: las cuentas
> de **Cliente y Propietario se eliminan** con sus datos personales. Las de
> **Administrador se anonimizan**, porque sus decisiones (aprobaciones,
> rechazos, creación de otros administradores) deben seguir siendo auditables;
> ver "Gestión de administradores". **Desde 2026-11-09** el administrador
> anonimiza su `users/{uid}` (falla con `lastAdministrator`, sin cambios, si es
> el último activo) y luego se borra su usuario de Auth; Cliente y Propietario
> siguen borrando su perfil como antes. Sin Cloud Functions (plan Spark): la
> eliminación se hace desde la app en el orden indicado, y las reglas de
> Firestore impiden que un administrador borre su `users/{uid}`.

Scenario: La opción de eliminar está disponible en todos los perfiles
Given un Cliente, un Propietario (activo, pendiente o rechazado) o un Administrador autenticado
When abre su perfil o menú
Then encuentra la acción "Eliminar cuenta" al final, como acción de peligro
And todos los perfiles usan el mismo panel de confirmación, a través de esta rama
And el panel indica qué datos se eliminan o, si es Administrador, cuáles se anonimizan

Scenario: El usuario elimina su cuenta (camino feliz)
Given un Cliente o Propietario autenticado en su perfil
When selecciona "Eliminar cuenta"
Then el sistema muestra un AppBottomSheet que explica que la acción es permanente y qué datos se borran
And pide su contraseña actual y escribir "ELIMINAR" para confirmar
When confirma
Then el sistema lo reautentica con Firebase Auth
And elimina su documento `users/{uid}` de Firestore
And elimina su usuario de Firebase Auth
And borra su perfil de SQLite y todas las claves del namespace `auth` en SharedPreferences, incluido el correo recordado
And navega a la pantalla de login con el mensaje "Tu cuenta fue eliminada" sin permitir volver atrás

Scenario: Contraseña incorrecta al confirmar la eliminación
Given un usuario en el panel de eliminación
When ingresa una contraseña incorrecta
Then el sistema muestra "La contraseña no es correcta"
And no elimina nada y mantiene la sesión

Scenario: Cancelar la eliminación
Given un usuario en el panel de eliminación
When lo cierra o presiona "Cancelar"
Then no se elimina nada y vuelve a su perfil

Scenario: Error de red durante la eliminación
Given un usuario que confirmó la eliminación
When la conexión falla antes de completar todos los pasos
Then el sistema muestra un error con opción de reintentar
And no borra los datos locales mientras la cuenta siga existiendo en Firebase Auth
But si el perfil de Firestore ya se borró y falla el borrado del usuario de Auth, al reintentar continúa desde el paso pendiente

Scenario: Propietario con moteles o cliente con reservas activas
Given un propietario con moteles registrados o un cliente con reservas futuras o en curso
When intenta eliminar su cuenta
Then el sistema le informa qué debe resolver antes (cancelar reservas, dar de baja moteles o la suscripción)
And no elimina la cuenta hasta que esas dependencias queden resueltas
And la verificación la hace el backend, no solo la vista

Scenario: El último administrador intenta eliminar su cuenta
Given un administrador que es el único con estado `active`
When intenta eliminar su cuenta
Then el sistema lo impide e indica que primero debe existir otro administrador activo

Scenario: Propietario pendiente o rechazado elimina su cuenta
Given un propietario en `pending_approval` o `rejected`
When elimina su cuenta desde "Cuenta en revisión"
Then se elimina igual que en el camino feliz
And su solicitud desaparece de "Solicitudes de propietarios"

Scenario: Volver a registrarse con el mismo correo
Given un correo cuya cuenta fue eliminada
When se registra de nuevo
Then el sistema crea una cuenta nueva sin datos de la anterior

Scenario: Un usuario intenta eliminar la cuenta de otro
Given un usuario autenticado o una petición manipulada
When intenta borrar `users/{uid}` de otro usuario
Then las reglas de Firestore lo rechazan (solo `request.auth.uid == uid` puede borrar su documento)

Scenario: Eliminar una cuenta que solo entra con Google o GitHub
Given un usuario sin contraseña que ingresó con Google o GitHub
When confirma "Eliminar cuenta"
Then el sistema no le pide contraseña
And lo reautentica con su proveedor antes de eliminar
But si cancela la confirmación del proveedor, no se elimina nada y mantiene la sesión

Scenario: Qué datos personales se eliminan
Given un Cliente o Propietario que confirmó la eliminación
When el sistema termina el proceso
Then ya no existen su documento `users/{uid}` (nombres, apellidos, correo, celular, fecha de nacimiento, tipo de persona, NIT, razón social y plan de interés) ni su usuario de Firebase Auth
And tampoco sus subcolecciones de `users/{uid}`, que Firestore no borra en cascada
And se borran su perfil de SQLite y el namespace `auth` de SharedPreferences
And quedan desvinculados sus proveedores de ingreso

Scenario: Datos de la cuenta en otras funcionalidades
Given un usuario eliminado con registros en reservas, reseñas, PQRS o pagos
When el backend procesa la eliminación
Then borra los registros que no deben conservarse
And los que se conservan por obligación legal o contable quedan sin nombre, correo, celular ni otro dato que lo identifique
And cada rama dueña de esos datos define el tratamiento de los suyos

Scenario: Un Administrador elimina su propia cuenta
Given un Administrador autenticado que no es el último administrador activo
When confirma "Eliminar cuenta"
Then el sistema anonimiza su cuenta en lugar de borrar su documento `users/{uid}`
And aplica la feature "Gestión de administradores"
And navega a la pantalla de login con el mensaje "Tu cuenta fue eliminada" sin permitir volver atrás

Scenario: Sesión abierta en otro dispositivo al eliminar la cuenta
Given un usuario con sesión abierta en otro dispositivo
When elimina su cuenta
Then esa sesión deja de tener acceso al backend, a más tardar al vencer su token
And al detectarlo, la app de ese dispositivo borra sus datos locales y muestra el login
And la app lo revisa al abrirse, al volver a primer plano y cada 15 minutos en primer plano (`AccountSessionWatcher`)
But sin conexión, o si el usuario no tiene perfil porque está en "Completar perfil", conserva la sesión
But si la sesión solo venció, p. ej. por un cambio de contraseña, conserva el correo recordado

Scenario: Prevención de doble envío al eliminar
Given un usuario que acaba de confirmar la eliminación
When la operación sigue en curso
Then el botón muestra estado de carga y queda deshabilitado
And un segundo toque no repite la operación

### Casos de prueba

| ID | Tipo | Caso | Resultado esperado |
| --- | --- | --- | --- |
| DA-01 | Unitaria (servicio) | Contraseña correcta | Reautentica, borra `users/{uid}`, llama a `User.delete()`, en ese orden |
| DA-02 | Unitaria (servicio) | Reautenticación con `wrong-password` / `invalid-credential` | `AuthFailure` de credenciales; no borra nada |
| DA-03 | Unitaria (servicio) | `User.delete()` lanza `requires-recent-login` | `AuthFailure` que pide volver a ingresar la contraseña |
| DA-04 | Unitaria (servicio) | Falla de red al borrar en Firestore | `AuthFailure` de red; el usuario de Auth sigue existiendo |
| DA-05 | Unitaria (servicio) | Firestore borrado, `User.delete()` falla | Reintento solo ejecuta `User.delete()` |
| DA-06 | Unitaria (controller) | Eliminación exitosa | Borra SQLite y todo el namespace `auth` (incluido `remembered_email`); conserva maestros |
| DA-07 | Unitaria (controller) | Texto de confirmación distinto a "ELIMINAR" | No llama al servicio |
| DA-08 | Unitaria (controller) | Dos confirmaciones seguidas | Una sola operación |
| DA-09 | Reglas (emulador de Firestore) | Usuario A borra `users/{B}` | Denegado |
| DA-10 | Reglas (emulador) | Usuario A borra `users/{A}` | Permitido |
| DA-11 | Widget | Flujo completo con servicio falso | Navega al login con el mensaje y sin ruta para volver atrás |
| DA-12 | Manual | Eliminar una cuenta real del equipo y volver a registrarse | El registro nuevo funciona; el perfil anterior no existe en Firestore |
| DA-13 | Widget | Perfiles de Cliente, Propietario y Administrador | Los tres muestran "Eliminar cuenta" |
| DA-14 | Unitaria (servicio) | Cuenta solo de Google o GitHub | Reautentica con el proveedor, sin pedir contraseña |
| DA-15 | Unitaria (servicio) | Cliente con subcolecciones en `users/{uid}` | No quedan documentos bajo `users/{uid}` |
| DA-16 | Unitaria (servicio) | Administrador elimina su cuenta | Anonimiza; no borra `users/{uid}` |
| DA-17 | Manual | Eliminar con sesión abierta en otro dispositivo | Ese dispositivo pierde acceso y borra sus datos locales |

### Riesgos

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| Borrado parcial (Firestore sin Auth o Auth sin Firestore) sin Cloud Functions | Cuentas huérfanas o perfiles sin usuario | Orden fijo (Firestore primero, Auth después), reintento idempotente y, como destino, una función de backend atómica |
| Datos del usuario en otras colecciones (reservas, moteles, reseñas, PQRS, pagos) de otras ramas | Datos huérfanos o pérdida de historial que otras partes necesitan | Coordinar con esas ramas qué se borra, qué se anonimiza y qué se conserva por obligación legal o contable |
| Eliminación accidental | Pérdida irreversible de la cuenta | Reautenticación, texto de confirmación y mensaje explícito de permanencia |
| Quedarse sin administradores | Nadie puede aprobar propietarios ni crear administradores | Bloquear la eliminación del último administrador activo (validado en backend) |
| `requires-recent-login` en sesiones viejas | La operación falla de forma confusa | Reautenticar siempre antes de eliminar |
| Reglas de Firestore que permitan borrar perfiles ajenos | Borrado malicioso de cuentas | Regla `allow delete: if request.auth.uid == uid`; pruebas DA-09 y DA-10 en el emulador |
| Datos locales que sobreviven a la eliminación | Fuga de información en el dispositivo | Borrar SQLite y el namespace `auth` completo tras confirmar la eliminación |
| Subcolecciones de `users/{uid}` que sobreviven: Firestore no borra en cascada y las reglas hoy tienen `allow delete: if false` en `subscriptions` y `payments` | Datos personales huérfanos tras "eliminar" | Borrarlas desde el backend o acordar el cambio de reglas con la rama de suscripciones; prueba DA-15 |

## Feature: Correo del usuario compartido (SharedPreferences)

Scenario: Guardar el correo al autenticarse
Given un usuario que inicia sesión, se registra o restaura su sesión con éxito
When el sistema confirma la autenticación
Then guarda su correo normalizado (sin espacios, en minúsculas) en SharedPreferences con la clave `current_user_email` del namespace `auth`

Scenario: Otra pantalla o funcionalidad consulta el correo
Given un usuario autenticado
When cualquier pantalla de otra funcionalidad (perfil, reservas, PQRS, pagos) necesita el correo del usuario
Then lo obtiene a través del método público de lectura que expone esta rama (p. ej. `AuthPreferences.loadCurrentUserEmail()`)
And ninguna vista lee SharedPreferences directamente
And si no hay correo guardado, recibe `null` y no un texto vacío ni una excepción

Scenario: Cargar el correo al abrir la app
Given un usuario con sesión válida y un correo guardado en SharedPreferences
When abre la aplicación
Then el correo queda disponible en memoria desde el arranque, antes de pintar la primera vista protegida

Scenario: El correo compartido no se usa para autorizar
Given cualquier funcionalidad que lea `current_user_email`
When toma una decisión de acceso o de datos del usuario
Then la autorización se valida con la sesión de Firebase Auth en el backend, no con el correo guardado localmente

## Feature: Retiro de las credenciales de prueba [Hecho 2026-11-04]

> Sustituye a la antigua feature "Acceso local temporal". Los integrantes ya
> crean sus usuarios con correo en Firebase Auth, así que el login quemado se
> elimina. Archivos a tocar: borrar `lib/service/auth/hardcoded_auth_service.dart`;
> quitar `useHardcodedAuthUsers` de `auth_config.dart`; quitar la selección
> de implementación, el banner de modo desarrollo y la lista de usuarios de
> prueba de `lib/views/login/login_page.dart`; limpiar las referencias en
> `auth_service.dart`, `backend_registered_user_directory.dart` (verificar si
> sigue en uso) y `test/widget_test.dart`. Antes de borrar, `grep` para
> confirmar que ninguna otra rama importa `HardcodedAuthService`.

Scenario: La app solo autentica con Firebase Auth
Given la aplicación compilada sin ningún `--dart-define` de autenticación
When se abre la pantalla de login
Then el `LoginController` usa `FirebaseAuthService`
And no existe ningún flag ni ruta de código que active usuarios quemados

Scenario: La pantalla de login no muestra datos de prueba
Given la pantalla de login
When se muestra
Then no aparece el aviso "Modo desarrollo", ni la lista de usuarios de prueba, ni correos o contraseñas precargados

Scenario: Las credenciales de prueba antiguas ya no funcionan
Given un integrante que escribe el correo y la contraseña de un antiguo usuario de prueba
When presiona "Ingresar"
Then el sistema responde igual que con cualquier credencial no registrada en Firebase ("Correo o contraseña incorrectos")

Scenario: El código no contiene credenciales
Given el repositorio en esta rama
When se busca `HardcodedAuthService`, `AUTH_USE_HARDCODED_AUTH_USERS` o las contraseñas de los antiguos usuarios de prueba
Then no hay coincidencias en `lib/` ni en `test/`
And los README y `docs/` ya no indican usar usuarios de prueba

Scenario: Los integrantes obtienen cuentas de cada rol
Given un integrante del equipo que necesita probar un rol
When necesita una cuenta Cliente o Propietario
Then se registra desde la pantalla de registro con su correo
And si necesita Propietario activo, otro integrante con rol admin lo aprueba (o se ajusta `accountStatus` en la consola mientras no exista la vista)
And si necesita Administrador, se le asigna `role: admin` en `users/{uid}` desde la consola de Firebase

Scenario: Las pruebas automáticas no dependen de cuentas reales
Given las pruebas de `test/`
When se ejecutan
Then usan un servicio de autenticación falso inyectado, sin red ni credenciales reales

### Casos de prueba

| ID | Tipo | Caso | Resultado esperado |
| --- | --- | --- | --- |
| RC-01 | Búsqueda (`grep`) | `HardcodedAuthService`, `useHardcodedAuthUsers`, `AUTH_USE_HARDCODED_AUTH_USERS` en `lib/` y `test/` | Sin coincidencias |
| RC-02 | Análisis | `flutter analyze` tras el retiro | Sin errores ni imports rotos |
| RC-03 | Widget | Pintar `LoginPage` con servicio falso | No hay banner de modo desarrollo ni lista de usuarios de prueba |
| RC-04 | Unitaria (controller) | Construcción por defecto del controller | Usa la implementación de Firebase (o el falso inyectado en pruebas) |
| RC-05 | Unitaria | `test/widget_test.dart` actualizado | Pasa sin `HardcodedAuthService` |
| RC-06 | Manual | Login con una antigua credencial de prueba | "Correo o contraseña incorrectos" |
| RC-07 | Manual | Login con una cuenta real de cada rol | Navega a la ruta correcta de cada rol |

### Riesgos

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| Hoy el flag tiene `defaultValue: true`: cualquier build sin `--dart-define` entra con usuarios quemados | Acceso con credenciales públicas del repositorio en builds distribuidos | Retirar el servicio y el flag (no solo cambiar el valor por defecto) |
| Otras ramas aún dependen de los usuarios de prueba para llegar a sus vistas | Integrantes bloqueados tras el merge | Avisar al equipo antes del merge y documentar en `docs/firebase.md` cómo crear cuentas de cada rol |
| Sin vista de "Creación de administradores", nadie obtiene rol admin desde la app | Bloqueo para probar vistas del administrador | Asignar `role: admin` desde la consola de Firebase a quien lo necesite |
| Propietarios de prueba quedan en `pending_approval` | No pueden probar vistas de propietario | Aprobación manual en la consola hasta que exista "Solicitudes de propietarios" |
| Las credenciales antiguas siguen en el historial de git | Si alguien las reutilizó en Firebase, quedan expuestas | Verificar que ninguna cuenta real de Firebase use esas contraseñas |
| Pruebas que dependían del servicio quemado se rompen | CI en rojo | Reemplazarlas por un servicio falso inyectado (RC-05) |

## Feature: Registro público de usuario (Cliente y Propietario)

> En la pantalla principal **solo se pueden registrar Clientes y
> Propietarios**. Los administradores se crean desde la vista del
> administrador (ver "Creación de administradores"). Los campos por rol son
> una propuesta de esta rama y deben validarse con producto (ver "Pendientes
> de validar").

### Matriz de registro por rol

| Aspecto | Cliente (registro público) | Propietario (registro público) | Administrador (lo crea otro administrador) |
| --- | --- | --- | --- |
| Datos comunes (nombres, apellidos, indicativo y celular, correo, contraseña, confirmación) | Sí | Sí | Sí (sin contraseña, ver feature de creación) |
| Tipo y número de documento | **No se solicita** | **No se solicita** | **No se solicita** |
| Campos propios | Fecha de nacimiento | Tipo de persona (natural/jurídica), NIT y plan de suscripción de interés (obligatorios); si es jurídica, además razón social | — |
| Regla clave | Debe ser mayor de 18 años | Su cuenta debe aprobarla un administrador | Solo un administrador autenticado puede crearlo |
| Estado inicial de la cuenta | `active` | `pending_approval` | `active` |
| Destino tras el registro | Ruta del cliente | Pantalla "Cuenta en revisión" | (No aplica: el creador permanece en su vista) |
| Registro con Google o GitHub ([Futuro], no se implementa aún) | Sí | Sí, pero luego debe completar los campos propios | No |

Scenario: Visitante elige el rol antes de diligenciar el formulario
Given un visitante en la pestaña "Registrarse"
When ve el selector de tipo de perfil
Then solo se ofrecen las opciones Cliente y Propietario (Administrador no aparece)
When selecciona un tipo de perfil
Then el sistema muestra el bloque de datos comunes más los campos propios de ese rol
And ningún perfil muestra campos de tipo ni número de documento
When el visitante cambia de rol con datos ya escritos
Then el sistema conserva los datos comunes
And descarta los campos propios del rol anterior

Scenario: Cliente se registra (camino feliz)
Given un visitante que eligió el perfil Cliente
When diligencia nombres, apellidos, indicativo y celular, correo, contraseña, confirmación y fecha de nacimiento
And presiona "Crear cuenta"
Then el sistema no le solicita tipo ni número de documento
And crea la cuenta en Firebase Auth con rol `client` y estado `active`
And guarda el perfil con el id del indicativo telefónico (no el texto mostrado)
And guarda en SharedPreferences el correo del usuario y el indicativo usado como último indicativo seleccionado
And navega a la ruta inicial del cliente

Scenario: Cliente menor de edad
Given un visitante que eligió el perfil Cliente
When ingresa una fecha de nacimiento que corresponde a una persona menor de 18 años
Then el sistema rechaza el registro e indica que debe ser mayor de edad
And no crea la cuenta

Scenario: Propietario persona natural se registra (camino feliz)
Given un visitante que eligió el perfil Propietario y el tipo de persona "Natural"
When el sistema muestra el campo NIT como obligatorio
And el visitante diligencia los datos comunes y su NIT
And presiona "Crear cuenta"
Then el sistema no le solicita tipo ni número de documento ni razón social
And crea la cuenta con rol `owner`, tipo de persona natural, su NIT y estado `pending_approval`
And la solicitud aparece en "Solicitudes de propietarios" de los administradores
And navega a la pantalla "Cuenta en revisión", que explica que un administrador debe aprobarla

Scenario: Propietario persona jurídica se registra
Given un visitante que eligió el perfil Propietario y el tipo de persona "Jurídica"
When el sistema muestra los campos razón social y NIT como obligatorios
And el visitante los diligencia junto con los datos comunes del representante (sin documento del representante)
And presiona "Crear cuenta"
Then el sistema crea la cuenta con rol `owner`, tipo de persona jurídica, razón social, NIT y estado `pending_approval`
But si falta la razón social o el NIT tiene un formato inválido, no envía el formulario y señala el campo

Scenario: Propietario sin tipo de persona o sin NIT
Given un visitante que eligió el perfil Propietario
When intenta crear la cuenta sin elegir el tipo de persona o sin diligenciar el NIT
Then el sistema no envía el formulario
And señala que el tipo de persona y el NIT son obligatorios para todo propietario
When cambia el tipo de persona de "Jurídica" a "Natural"
Then conserva el NIT escrito y oculta y descarta la razón social

Scenario: Propietario pendiente de aprobación intenta iniciar sesión
Given un propietario registrado cuya cuenta sigue en estado `pending_approval`
When inicia sesión con credenciales correctas
Then el sistema lo lleva a la pantalla "Cuenta en revisión"
And no le da acceso a las vistas de gestión de moteles hasta que un administrador apruebe la cuenta

Scenario: Intento de registrarse como administrador desde el registro público
Given cualquier registro público
When la petición llega con `role: admin` (p. ej. un cliente manipulado)
Then el backend la rechaza y no crea ninguna cuenta, ni siquiera con otro rol
And el rol y el estado inicial los asigna y valida siempre el backend según las reglas del rol

Scenario: Términos y condiciones (temporal)
Given un visitante en el formulario de registro
When ve el final del formulario, antes de "Crear cuenta"
Then encuentra un botón o enlace "Términos y condiciones"
When lo presiona
Then se abre un AppBottomSheet con un texto provisional "Contenido de términos y condiciones pendiente"
And cerrar el panel lo devuelve al formulario con los datos intactos
And por ahora su lectura o aceptación no bloquea el registro
But el componente queda preparado para, más adelante, mostrar el documento vigente y exigir una casilla de aceptación

Scenario: Validación del número de celular según el país
Given un visitante en el formulario de registro con un indicativo seleccionado
When escribe un número de celular con longitud fuera del rango definido por ese país en el maestro
Then el sistema señala que el número no es válido para el país seleccionado
And no permite enviar el formulario

Scenario: Ningún formulario solicita documento de identidad
Given un visitante en el registro público o un administrador en "Crear administrador"
When revisa el formulario de cualquier perfil
Then no encuentra campos de tipo ni número de documento
And la petición al backend no incluye esos datos

Scenario: Campos obligatorios del registro
Given un visitante en el formulario de registro con un rol elegido
When intenta crear la cuenta sin alguno de los datos comunes o sin un campo propio obligatorio de ese rol
Then el sistema no envía el formulario
And señala cada campo obligatorio faltante

Scenario: Contraseñas no coinciden o son débiles
Given un visitante en el formulario de registro
When la confirmación no coincide con la contraseña, o la contraseña tiene menos de 8 caracteres (en desarrollo no se exigen letras ni números; endurecer antes de producción)
Then el sistema muestra el error junto al campo correspondiente
And no envía el formulario

Scenario: Correo ya registrado
Given un visitante que intenta registrarse con un correo que ya tiene cuenta
When presiona "Crear cuenta"
Then el sistema informa que el correo ya está en uso
And ofrece ir a "Iniciar sesión" o "¿Olvidaste tu contraseña?"

## Feature: Consulta de planes de suscripción para propietarios (Supabase + SQLite)

> Esta rama solo **consulta** los planes posibles y registra el plan de
> interés del propietario. El cobro, la activación y la gestión de la
> suscripción pertenecen a la rama de suscripciones
> (`lib/database/repository/suscripcion/`).

Scenario: El propietario consulta los planes disponibles al registrarse
Given un visitante que eligió el perfil Propietario en el formulario de registro
When se muestra el bloque propio del propietario
Then el sistema consulta los planes activos del maestro `subscription_plans`
And los muestra ordenados por `sort_order` con nombre, descripción, precio en COP, periodicidad, número máximo de moteles y características
And el visitante debe elegir un plan de interés antes de "Crear cuenta"

Scenario: El plan elegido se guarda con la solicitud del propietario
Given un visitante Propietario que eligió un plan y diligenció el formulario válido
When presiona "Crear cuenta"
Then la cuenta se crea en `pending_approval` con el id del plan elegido (no el nombre mostrado)
And el plan aparece en el detalle de la solicitud que ve el administrador
And la suscripción no se activa ni se cobra hasta que la cuenta sea aprobada y la rama de suscripciones lo procese

Scenario: Uso de la caché local de planes
Given un dispositivo con los planes ya guardados en SQLite hace menos de 24 horas
When el visitante elige el perfil Propietario
Then el sistema muestra los planes desde SQLite sin esperar a la red
And solo consulta Supabase cuando se fuerza el refresco o la caché venció

Scenario: Sin conexión y sin caché de planes
Given un dispositivo sin caché de planes y sin conexión
When el visitante elige el perfil Propietario
Then el bloque de planes muestra un estado de error con opción de reintentar
And el botón "Crear cuenta" permanece deshabilitado para Propietario
But el registro de Cliente y el inicio de sesión siguen funcionando

Scenario: Sin planes activos
Given el maestro `subscription_plans` sin registros activos
When el visitante elige el perfil Propietario
Then el sistema muestra un estado vacío "No hay planes disponibles por ahora"
And no permite crear la cuenta de propietario

Scenario: Un plan se desactiva
Given un plan marcado como inactivo en Supabase
When el sistema refresca los planes
Then el plan deja de mostrarse en el registro
But los propietarios que ya lo eligieron conservan la referencia en su solicitud

Scenario: El plan elegido no se usa para autorizar ni cobrar desde la app
Given una petición de registro con un `plan_id` manipulado o inexistente
When llega al backend
Then el backend valida que el plan exista y esté activo, y si no, rechaza el registro
And el precio nunca se toma del valor enviado por la app

## Feature: Ingreso con proveedores externos (Google/Gmail y GitHub) [Hecho; ver docs/auth/plan-auth-social.md]

> **Actualización 2026-11-09:** ya están implementados con
> `FirebaseSocialAuthService` (`signInWithProvider`), `SocialAuthButtons` y
> "Completar perfil"; los escenarios siguientes se conservan como referencia
> histórica y la fuente vigente es `docs/auth/`. El texto siguiente ("solo
> definición") ya no aplica.
>
> **Solo definición, no implementación (histórico).** Estos escenarios se implementarán
> más adelante con los proveedores de Firebase Auth (`GoogleAuthProvider` y
> `GithubAuthProvider`) y **en cooperación con otras ramas** (configuración
> del proyecto de Firebase, OAuth App de GitHub, SHA-1/SHA-256 de Android,
> URL schemes de iOS). En esta rama **no** se agregan dependencias
> (`google_sign_in` u otras), ni lógica de controller, ni servicios para
> ellos. Mientras tanto solo aplica el escenario "Proveedores externos aún no
> disponibles".

Scenario: Proveedores externos aún no disponibles
Given la aplicación sin los proveedores externos habilitados
When el usuario ve la pantalla de login o de registro
Then los botones "Continuar con Google" y "Continuar con GitHub" no se muestran, o se muestran deshabilitados con la etiqueta "Próximamente"
And presionarlos no lanza una excepción ni bloquea el formulario de correo y contraseña

Scenario: [Futuro] Inicio de sesión con Google (Gmail)
Given un usuario con cuenta existente vinculada a Google y Firebase Auth configurado con el proveedor de Google
When presiona "Continuar con Google" y completa el flujo del proveedor
Then el sistema autentica al usuario con Firebase Auth
And obtiene su rol y estado de cuenta desde el backend
And guarda su correo en SharedPreferences y navega a la ruta de su rol mediante `resolvePostLoginRoute`
But si el usuario cancela el flujo, permanece en el login sin mostrar error

Scenario: [Futuro] Inicio de sesión con GitHub
Given un usuario con cuenta existente vinculada a GitHub y Firebase Auth configurado con el proveedor de GitHub
When presiona "Continuar con GitHub" y autoriza la aplicación
Then el sistema autentica al usuario con Firebase Auth
And obtiene su rol y estado de cuenta desde el backend
And guarda su correo en SharedPreferences y navega a la ruta de su rol
But si GitHub no entrega un correo verificado, el sistema no crea sesión e informa que debe usar una cuenta con correo público o verificado

Scenario: [Futuro] Registro con un proveedor externo según el rol
Given un visitante en el formulario de registro que eligió un tipo de perfil
When elige "Continuar con Google" o "Continuar con GitHub" y completa el flujo
Then para Cliente, el sistema pide completar los datos que el proveedor no entrega (nombres y apellidos si faltan, indicativo y celular, fecha de nacimiento) antes de crear el perfil y navegar
And para Propietario, pide completar indicativo y celular, tipo de persona, NIT y, si es jurídica, razón social, y la cuenta queda en `pending_approval`
And el rol y el estado inicial los asigna y valida el backend, igual que en el registro con correo
And nunca se crea una cuenta `admin` por este medio

Scenario: [Futuro] Correo ya registrado con otro método
Given un visitante cuyo correo ya tiene cuenta con correo y contraseña u otro proveedor
When intenta ingresar con Google o GitHub usando ese mismo correo
Then el sistema no crea una cuenta duplicada
And le indica que ya existe una cuenta con ese correo y que inicie sesión con el método original para vincular el proveedor

Scenario: [Futuro] Cuenta deshabilitada, pendiente o rechazada con proveedor externo
Given un usuario cuya cuenta está `disabled`, `pending_approval` o `rejected`
When inicia sesión con Google o GitHub
Then el sistema aplica las mismas reglas que en el inicio de sesión con correo y contraseña

## Feature: Validación de formato de los datos del formulario

> Aplica al login, al registro público y al formulario de creación de
> administradores. La validación vive en el controller (o en validadores de
> `lib/controllers/auth/`), no en la vista, y se repite en el backend.

### Reglas de formato

| Campo | Regla |
| --- | --- |
| Nombres / apellidos | Solo letras (con tildes y ñ), espacios, guion y apóstrofo; 2 a 50 caracteres; sin espacios dobles |
| Correo | Formato `usuario@dominio.ext`, máx. 254 caracteres; se recortan espacios y se guarda en minúsculas |
| Celular | Solo dígitos; longitud entre `phone_min_length` y `phone_max_length` del país |
| NIT del propietario (natural y jurídica, obligatorio) | Solo dígitos, guion opcional y dígito de verificación válido. Jurídica: 9 dígitos + DV (p. ej. `900123456-8`). Natural: número base de 6 a 10 dígitos + DV (p. ej. `1020304050-8`) |
| Razón social | 2 a 120 caracteres; letras, números, espacios y `. , & -` |
| Fecha de nacimiento | Fecha real, no futura, edad ≥ 18 años |
| Contraseña | Mínimo 8 caracteres en desarrollo (sin reglas de complejidad). Propuesta para producción: 8 a 64 caracteres, al menos una letra y un número |

Scenario: Formato inválido en un campo
Given un usuario diligenciando cualquier formulario de esta rama
When escribe un valor que no cumple la regla de formato del campo
And sale del campo o presiona el botón de envío
Then el sistema muestra junto al campo un mensaje en español que explica el formato esperado
And el formulario no se envía mientras haya algún campo con formato inválido

Scenario: Normalización antes de validar
Given un usuario que escribe un dato con espacios al inicio o al final, o un correo con mayúsculas
When el sistema valida el formulario
Then recorta los espacios y normaliza el correo a minúsculas antes de validar y enviar
And no muestra error por esas diferencias

Scenario: Campos con caracteres no permitidos
Given un usuario que pega texto con caracteres de control, emojis o símbolos no permitidos en nombres, celular o NIT
When el sistema valida el campo
Then lo marca como inválido indicando qué caracteres se admiten
And no los envía al backend

## Feature: Protección contra inyección SQL

Scenario: Entradas con código SQL en el login
Given un usuario en la pantalla de login
When escribe en el correo o en la contraseña un valor como `' OR '1'='1' --` o `admin'; DROP TABLE users; --`
And presiona "Ingresar"
Then el sistema trata el valor como texto literal
And el correo falla la validación de formato o la autenticación con el mensaje genérico "Correo o contraseña incorrectos"
And no se ejecuta ninguna instrucción SQL adicional ni se altera ningún dato

Scenario: Entradas con código SQL en el registro y en la creación de administradores
Given un usuario en un formulario de registro o de creación de administrador
When escribe código SQL en nombres, apellidos, razón social, NIT o cualquier otro campo
Then la validación de formato lo rechaza en los campos con formato restringido
And en los campos de texto libre el valor se guarda como texto literal sin ejecutarse

Scenario: Consultas parametrizadas en SQLite y Supabase
Given cualquier consulta de esta rama a SQLite (Floor) o a Supabase (REST)
When incluye un valor ingresado por el usuario o recibido de la red
Then el valor se pasa como parámetro enlazado (`:param` en Floor) o como filtro codificado en la URL de PostgREST
And nunca se arma una consulta concatenando texto con datos del usuario
And las tablas de Supabase mantienen RLS, de modo que una petición manipulada no puede leer ni escribir fuera de lo permitido

Scenario: Búsqueda en el selector de indicativo
Given un visitante que escribe `%`, `'`, `;` o `--` en el buscador de países
When se filtra la lista
Then el filtro se aplica en memoria o con parámetros enlazados
And la app no falla ni muestra resultados inesperados

## Feature: Creación de administradores (vista del administrador) [Datos y reglas hechos 2026-11-09; vista pendiente]

> Datos, controller y reglas implementados el 2026-11-09
> (`AdministratorsRepository`, `AdministratorsController`, `firestore.rules`);
> `AdministratorsPage` sigue mostrando "Próximamente" hasta que la rama de
> frontend construya las vistas con ese contrato. Antes se creaban a mano en la
> consola de Firebase (`users/{uid}` con `role: admin`).

> **Sin backend propio (plan Spark, decisión 2026-11-09).** Solo un
> administrador activo puede crear otro; la autoridad son las reglas de
> Firestore. La app crea el usuario con una **instancia secundaria** de
> Firebase (así no se cierra la sesión de quien crea), genera una **contraseña
> temporal** que quien crea ve una sola vez y entrega por su cuenta, y escribe
> `users/{uid}` con la sesión del administrador principal. **No se envían
> correos ni SMS.** La contraseña temporal nunca se guarda ni se registra. Si
> falla la escritura del perfil, se borra el usuario recién creado.

Scenario: El administrador accede a la vista "Administradores"
Given un administrador autenticado
When abre su perfil o menú y selecciona "Administradores"
Then el sistema muestra la lista de administradores existentes (nombre, correo y estado)
And un botón "Crear administrador"

Scenario: Crear un administrador (camino feliz)
Given un administrador en la vista "Administradores"
When presiona "Crear administrador"
And diligencia nombres, apellidos, indicativo y celular y correo con formato válido (sin tipo ni número de documento)
And presiona "Crear"
Then las reglas de Firestore verifican que quien escribe es un administrador activo (rol `admin`, estado `active` y sin contraseña temporal pendiente)
And la app crea el usuario en Firebase Auth con una contraseña temporal de 12 o más caracteres generada con `Random.secure()`
And guarda `users/{uid}` con rol `admin`, estado `active`, `mustChangePassword: true`, `createdBy` y `createdAt`, y suma 1 a `system/adminRegistry.activeAdminCount` en la misma transacción
And muestra la contraseña temporal una sola vez, para que el creador la entregue por su cuenta (no se envía ningún correo ni SMS)
And el administrador creador permanece en su sesión y ve al nuevo administrador en la lista con un mensaje de confirmación

Scenario: Correo ya registrado al crear un administrador
Given un administrador en el formulario "Crear administrador"
When ingresa un correo que ya pertenece a otra cuenta
Then el sistema informa que "ese correo ya está en uso" (`email-already-in-use`)
And no crea ni modifica ninguna cuenta (no convierte en administrador a un cliente o propietario existente)
And el correo de un administrador eliminado por otro también sigue ocupado, porque su usuario de Firebase Auth no se borra (limitación aceptada)

Scenario: Datos inválidos al crear un administrador
Given un administrador en el formulario "Crear administrador"
When deja campos obligatorios vacíos o con formato inválido
Then el sistema no envía el formulario y señala cada campo

Scenario: Un usuario que no es administrador intenta crear un administrador
Given un cliente o propietario autenticado, o una petición manipulada
When intenta acceder a la ruta de "Administradores" o llama directamente a la operación de creación
Then la app no muestra la vista (redirige a la ruta de su rol)
And las reglas de Firestore rechazan la escritura aunque la app haya sido modificada

Scenario: Prevención de doble envío al crear un administrador
Given un administrador que acaba de presionar "Crear"
When la creación todavía está en curso
Then el botón muestra estado de carga y queda deshabilitado
And un segundo toque no crea una segunda cuenta

Scenario: Primer ingreso del nuevo administrador
Given un administrador recién creado que recibió la contraseña temporal de quien lo creó
When inicia sesión con esa contraseña
Then `resolvePostLoginRoute` lo lleva a `AuthRoutes.adminChangePassword` en lugar de la ruta del administrador
And debe definir una contraseña nueva que cumpla la política
When la cambia
Then la app llama a `User.updatePassword` y luego limpia `mustChangePassword`
And entra a la ruta inicial del administrador
But si Firebase pide un inicio de sesión reciente (`requires-recent-login`) o la contraseña es débil, se informa y puede reintentar sin repetir el cambio ya hecho
And mientras `mustChangePassword` sea `true`, las reglas no lo tratan como administrador activo (no crea, edita ni elimina administradores, ni atiende solicitudes)

Scenario: El nuevo administrador pierde la contraseña temporal
Given un administrador creado que aún no define su contraseña
When usa "¿Olvidaste tu contraseña?" desde el login
Then recibe el correo de restablecimiento existente y define su contraseña desde allí
And nadie más ve ni reenvía la contraseña (no existe "Reenviar correo")

Scenario: Error de red al crear un administrador
Given un administrador en el formulario "Crear administrador"
When la conexión falla antes de recibir respuesta
Then el sistema conserva los datos escritos y ofrece reintentar
And si el usuario de Auth ya se había creado y falla la escritura del perfil, la app lo borra (reversión)
And reintentar no deja una segunda cuenta huérfana con el mismo correo

## Feature: Gestión de administradores (vista del administrador) [Datos y reglas hechos 2026-11-09; vista pendiente]

> Vista "Administradores": consultar, registrar (ver "Creación de
> administradores"), actualizar y eliminar cuentas de administrador. **Siempre
> debe existir al menos un administrador activo**, y eliminar un administrador
> **anonimiza** sus datos en lugar de borrar su registro.
>
> **Administrador activo (para la regla del último administrador)** es todo
> el que tiene `role: admin` y `accountStatus: active`, **incluso con la
> contraseña temporal pendiente** (decisión 2026-11-09; reemplaza "ya definió
> su contraseña"). Distinto es el administrador "activo para las reglas"
> (`isActiveAdmin()`): además exige `mustChangePassword != true`, porque solo
> puede operar quien ya cambió su contraseña.
>
> **Sin backend propio (plan Spark).** Anonimizar a otro administrador es solo
> escribir su `users/{uid}`; las reglas de Firestore son la autoridad.
> **Limitación aceptada:** el usuario de Firebase Auth de OTRO administrador no
> se puede borrar desde el cliente (solo el Admin SDK), así que sigue
> existiendo: pierde el acceso porque su perfil queda `anonymized`, pero su
> correo sigue ocupado. Al **eliminar la propia cuenta** sí se borra el usuario
> con `User.delete()`.
>
> **Contador:** `system/adminRegistry.activeAdminCount`. Crear suma 1 y
> anonimizar resta 1 en una transacción que lee el conteo y falla con
> `lastAdmin` si es <= 1 (si el documento no existe, la app lo inicializa
> contando los administradores activos). Las reglas exigen ese cambio con
> `getAfter` y que el resultado sea >= 1.

### Datos al anonimizar `users/{uid}`

| Dato | Tratamiento |
| --- | --- |
| `fullName` | Se reemplaza por "Administrador eliminado" |
| `firstNames`, `lastNames`, `email`, `phoneNumber`, `phoneCountryCodeId` | Se eliminan |
| `accountStatus` | Pasa a `anonymized` (estado nuevo, definitivo) |
| `anonymizedAt`, `anonymizedBy` | Se agregan: fecha y uid de quien ejecutó la acción |
| `uid`, `role`, `createdAt`, `createdBy` (si existía) | Se conservan, sin identificar a la persona |
| `mustChangePassword` | Se elimina |
| Referencias en otros documentos (`approvedBy`, `rejectedBy`, creador) | Se conservan: apuntan al uid anonimizado |
| Usuario de Firebase Auth | Propia cuenta: se elimina con `User.delete()`. Otro administrador: **se conserva** (limitación aceptada); no puede ingresar porque la app rechaza el estado `anonymized` con "Esta cuenta ya no existe" |

### Consulta

Scenario: Consultar los administradores
Given un administrador activo autenticado
When abre su perfil o menú y selecciona "Administradores"
Then el sistema muestra cada administrador con nombre, correo y estado (activo, deshabilitado o con contraseña temporal pendiente: `mustChangePassword`)
And identifica su propia cuenta con la etiqueta "Tú"
And no muestra las cuentas anonimizadas
And ofrece el botón "Crear administrador"

Scenario: Error de red al cargar los administradores
Given un administrador en la vista "Administradores"
When la conexión falla al cargar la lista
Then el sistema muestra un error comprensible con opción de reintentar
And no muestra datos parciales como si fueran la lista completa

Scenario: Ver el detalle de un administrador
Given un administrador en la lista
When selecciona un administrador
Then el sistema muestra nombres, apellidos, indicativo y celular, correo, estado, fecha de creación y quién lo creó
And las acciones "Editar" y "Eliminar cuenta"

### Actualización

Scenario: Actualizar los datos de un administrador (camino feliz)
Given un administrador en el detalle de un administrador
When presiona "Editar", cambia nombres, apellidos, indicativo o celular con formato válido y guarda
Then las reglas de Firestore verifican que quien escribe es un administrador activo
And guardan solo nombres, apellidos, `fullName` (recalculado), indicativo y celular
And la lista y el detalle muestran los datos nuevos con un mensaje de confirmación

Scenario: Datos inválidos al actualizar
Given un administrador en el formulario de edición
When deja campos obligatorios vacíos o con formato inválido
Then el sistema no envía el formulario y señala cada campo
And aplica las mismas reglas de formato del registro

Scenario: El correo y el rol no se editan
Given un administrador en el formulario de edición
When revisa los campos
Then el correo se muestra en solo lectura y el rol no aparece como editable
And las reglas rechazan una petición manipulada que intente cambiarlos

Scenario: El administrador editado ya fue anonimizado
Given dos administradores con el mismo administrador abierto
When uno lo elimina y luego el otro intenta guardar cambios
Then la app (y, si se manipula, las reglas) rechaza la edición
And la app informa que esa cuenta ya no existe y refresca la lista

Scenario: Error de red al actualizar
Given un administrador que guarda cambios
When la conexión falla antes de recibir respuesta
Then el sistema conserva lo escrito y ofrece reintentar
And no muestra los datos como guardados hasta recibir confirmación de Firestore

### Eliminación con anonimización

Scenario: Eliminar a otro administrador (camino feliz)
Given un administrador activo en el detalle de otro administrador, y queda al menos otro administrador activo
When presiona "Eliminar cuenta"
Then el sistema muestra un AppBottomSheet que explica que la acción es permanente y qué datos se anonimizan
And pide reautenticarse y escribir "ELIMINAR" para confirmar
When confirma
Then la app anonimiza `users/{uid}` y resta 1 al contador en una transacción
And el usuario de Firebase Auth de esa persona NO se elimina (limitación aceptada: su correo sigue ocupado) pero ya no puede ingresar
And la cuenta desaparece de la lista con un mensaje de confirmación
And quien eliminó permanece en su sesión

Scenario: Eliminar la propia cuenta de administrador
Given un administrador activo en su propio detalle, y existe otro administrador activo
When confirma "Eliminar cuenta" tras reautenticarse
Then el sistema anonimiza su cuenta y elimina su usuario de Firebase Auth con `User.delete()`
And borra su perfil de SQLite y el namespace `auth` de SharedPreferences
And navega al login con el mensaje "Tu cuenta fue eliminada" sin permitir volver atrás

Scenario: Las decisiones del administrador eliminado siguen siendo auditables
Given un administrador anonimizado que aprobó o rechazó propietarios o creó administradores
When alguien consulta esos registros
Then el registro conserva la decisión, la fecha y el uid
And muestra "Administrador eliminado" como responsable, sin nombre, correo ni celular

Scenario: La anonimización no se puede revertir
Given una cuenta anonimizada
When cualquier administrador o una petición manipulada intenta reactivarla, editarla o cambiar su estado
Then las reglas de Firestore lo rechazan
And esa cuenta no puede iniciar sesión (fallo neutro "Esta cuenta ya no existe" y se cierra la sesión)

Scenario: Registrarse de nuevo con el correo de un administrador eliminado
Given el correo de un administrador anonimizado por OTRO administrador
When esa persona se registra de nuevo o la crean otra vez como administrador
Then el sistema informa que el correo ya está en uso (su usuario de Firebase Auth sigue existiendo: limitación aceptada)
But si el administrador eliminó su PROPIA cuenta, su usuario de Auth se borró y el correo queda libre para crear una cuenta nueva con otro uid
And no se recupera ningún dato ni permiso de la cuenta anterior

Scenario: Falla parcial al eliminar la propia cuenta
Given un administrador que confirmó la eliminación
When el proceso falla después de anonimizar el documento y antes de `User.delete()`
Then el sistema informa el error y permite reintentar
And el reintento detecta el perfil ya anonimizado y solo ejecuta `User.delete()`, sin duplicar cambios ni restar dos veces al contador
And el usuario no conserva acceso de administrador mientras tanto

### Siempre debe existir un administrador

Scenario: No se puede eliminar al último administrador activo
Given un único administrador activo
When intenta eliminar su propia cuenta
Then la transacción falla con el tipo `lastAdmin` y no cambia ningún dato (`AuthFailureType.lastAdministrator` en el flujo de eliminar cuenta)
And el sistema explica que primero debe existir otro administrador activo y ofrece "Crear administrador"

Scenario: Los administradores no activos no cuentan para la regla
Given un administrador activo y otros deshabilitados o anonimizados
When el administrador activo intenta eliminar su cuenta
Then el contador lo trata como el último administrador activo y rechaza la operación
But un administrador con la contraseña temporal pendiente SÍ cuenta (su estado es `active`), así que con uno pendiente el otro sí puede eliminarse

Scenario: Dos administradores se eliminan al mismo tiempo
Given exactamente dos administradores activos
When cada uno elimina al otro, o a sí mismo, al mismo tiempo
Then la regla se valida dentro de una transacción que lee `activeAdminCount`
And Firestore reintenta la transacción en conflicto: solo una operación se completa y la otra falla con `lastAdmin`
And queda exactamente un administrador activo

Scenario: Deshabilitar o cambiar de rol no deja al sistema sin administradores
Given un único administrador activo
When una petición manipulada intenta deshabilitarlo o cambiarle el rol
Then las reglas la rechazan (nadie cambia el rol ni el estado de un administrador)

Scenario: La regla no depende de la interfaz
Given una app modificada o una petición directa a Firestore
When intenta eliminar o anonimizar al último administrador activo
Then las reglas la rechazan porque el contador resultante sería menor que 1, aunque la app haya ocultado o no el botón
And un administrador no puede borrar su `users/{uid}` (las reglas niegan `delete` a los administradores)

### Autorización y doble envío

Scenario: Un usuario sin permiso intenta gestionar administradores
Given un cliente, un propietario, un administrador deshabilitado, uno con la contraseña temporal pendiente o una petición manipulada
When intenta abrir "Administradores" o llamar a sus operaciones
Then la app no muestra la vista
And las reglas de Firestore rechazan la escritura y la lectura del contador

Scenario: Prevención de doble envío al editar o eliminar
Given un administrador que acaba de confirmar una edición o una eliminación
When la operación sigue en curso
Then el botón muestra estado de carga y queda deshabilitado
And un segundo toque no repite la operación

### Casos de prueba

| ID | Tipo | Caso | Resultado esperado |
| --- | --- | --- | --- |
| AG-01 | Widget | Lista con varios estados, incluida una cuenta anonimizada | Muestra estados y "Tú"; oculta la anonimizada |
| AG-02 | Widget | Falla la carga | Error con "Reintentar" |
| AG-03 | Unitaria (controller) | Editar con datos inválidos, incluida inyección SQL | No llama al repositorio; señala los campos |
| AG-04 | Reglas (emulador) | Petición que cambia correo o rol | Rechazada |
| AG-05 | Unitaria (repositorio) y reglas | Anonimizar | Quedan solo los campos permitidos; sin nombre, correo ni celular |
| AG-06 | Unitaria (servicio) | Falla `User.delete()` tras anonimizar y reintento | Solo ejecuta `User.delete()`, sin duplicar cambios ni restar dos veces |
| AG-07 | Reglas (emulador) | Reactivar o editar una cuenta anonimizada | Rechazada |
| AG-08 | Reglas (emulador) y unitaria | Eliminar, deshabilitar o cambiar el rol del último activo | Rechazada; sin cambios |
| AG-09 | Reglas (emulador) y unitaria | Dos eliminaciones simultáneas con dos activos | Una se completa, la otra se rechaza (`lastAdmin`); queda un activo |
| AG-10 | Unitaria (repositorio) | Un activo y otro con contraseña temporal pendiente | El pendiente cuenta: el activo puede eliminarse; con solo uno activo, se rechaza |
| AG-11 | Reglas (emulador) | Cliente, propietario y admin con contraseña pendiente llaman a las operaciones | Rechazadas |
| AG-15 | Unitaria (repositorio) | Fallo al escribir el perfil tras crear el usuario | Se borra el usuario creado (reversión) y se cierra la app secundaria |
| AG-16 | Unitaria (repositorio) | Correo ya en uso al crear | `emailInUse`; ninguna cuenta ni contador cambia |
| AG-17 | Unitaria (controller) | Primer ingreso: cambiar contraseña y limpiar la marca | Reintenta solo la limpieza si el cambio ya se hizo; maneja `requires-recent-login` y contraseña débil |
| AG-18 | Unitaria (controller) | `resolvePostLoginRoute` con `mustChangePassword` | `AuthRoutes.adminChangePassword` |
| AG-12 | Widget | Doble toque al eliminar | Una sola operación |
| AG-13 | Widget | Solicitud aprobada por un administrador anonimizado | Muestra "Administrador eliminado" |
| AG-14 | Manual | Eliminar un administrador de prueba y crearlo otra vez con el mismo correo | Cuenta nueva con otro uid; sin datos anteriores |

### Riesgos

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| Quedarse sin administradores por eliminaciones simultáneas | Nadie puede aprobar propietarios ni crear administradores | Transacción que lee el contador + reglas con `getAfter`; prueba AG-09 |
| Un administrador malintencionado escribe `system/adminRegistry` directamente | El contador se desvía y la regla del último administrador falla | Las reglas limitan el cambio a +-1 y >= 1; aceptado en un proyecto universitario |
| `firestore.rules` permitía a cualquier usuario borrar su propio `users/{uid}` | El último administrador podía saltarse la regla | **Resuelto 2026-11-09:** `delete` excluye `role == 'admin'` y cuentas `anonymized` |
| Sin Admin SDK no se puede borrar el usuario de Auth de otro administrador | Su correo queda ocupado y su usuario de Auth sigue existiendo | **Limitación aceptada (2026-11-09).** Las reglas niegan toda edición de la cuenta anonimizada y la app rechaza su ingreso |
| `isAdmin()` (fuera de esta rama) solo comprueba `role == 'admin'` | Un administrador anonimizado por otro o con contraseña temporal pendiente conserva los accesos que dependen de `isAdmin()` (lecturas de `users`, `owners`, `payments`, `subscriptions`) | Pedir a la rama dueña que lo cambie por una comprobación de estado `active` (ver informe del 2026-11-09) |
| Datos personales fuera de `users/{uid}` (registros de auditoría, cachés, otras ramas) | Anonimización incompleta | Guardar en auditoría solo uids; revisar colecciones de otras ramas; prueba AG-05 |
| Estado nuevo `anonymized` no contemplado por otras ramas | Pantallas que fallan o tratan la cuenta como activa | Actualizar `AccountStatus` y `accountAccessFailure`; denegar por defecto cualquier estado desconocido |
| Un administrador malintencionado elimina a los demás | Pérdida de acceso de otros administradores | Reautenticación, registro de quién y cuándo; evaluar confirmación de un segundo administrador |

## Feature: Solicitudes de aprobación de propietarios (vista del administrador) [Parcial]

> Al 2026-11-08 existen `owner_approvals_page.dart`,
> `owner_approval_detail_page.dart`, `reject_owner_sheet.dart` y
> `admin_access_repository.dart`, con reglas para aprobar y rechazar. **Desde
> 2026-11-09** la capa de datos expone las alertas de validación
> (`AdminAccessController.loadAlerts` -> `OwnerRequestAlerts`: dígito de
> verificación del NIT, NIT duplicado y plan disponible; solo informan, no
> bloquean); falta que el frontend las muestre en el detalle y pida confirmar
> antes de aprobar. Pendiente también enlazar la vista desde el menú del
> administrador en las demás ramas (`docs/auth/handoff-otras-ramas.md`).

Scenario: El administrador valida los datos antes de decidir
Given un administrador en el detalle de una solicitud pendiente
When revisa la solicitud
Then el sistema indica si el dígito de verificación del NIT es válido
And indica si el NIT ya está registrado en otra cuenta de propietario
And indica si el plan de interés sigue activo
But estas alertas informan y no bloquean: la decisión de aprobar o rechazar es del administrador

Scenario: Confirmación antes de aprobar con alertas
Given una solicitud con una o más alertas de validación
When el administrador presiona "Aprobar"
Then el sistema muestra las alertas y pide confirmar antes de enviar
And el backend registra la aprobación solo tras la confirmación

Scenario: El administrador consulta las solicitudes pendientes
Given un administrador autenticado
When abre su perfil o menú y selecciona "Solicitudes de propietarios"
Then el sistema muestra la lista de propietarios en estado `pending_approval`, de la más antigua a la más reciente
And cada elemento muestra nombre o razón social, tipo de persona, correo y fecha de la solicitud
And el acceso muestra un contador con el número de solicitudes pendientes

Scenario: Sin solicitudes pendientes
Given un administrador en "Solicitudes de propietarios"
When no hay propietarios en estado `pending_approval`
Then el sistema muestra un estado vacío "No hay solicitudes pendientes"

Scenario: Ver el detalle de una solicitud
Given un administrador en la lista de solicitudes
When selecciona una solicitud
Then el sistema muestra los datos del registro: nombres, apellidos, celular con indicativo, correo, tipo de persona, NIT, plan de suscripción de interés y, si es jurídica, razón social
And los botones "Aprobar" y "Rechazar"

Scenario: Aprobar una solicitud
Given un administrador en el detalle de una solicitud pendiente
When presiona "Aprobar" y confirma
Then el backend verifica que quien aprueba es un administrador activo
And cambia la cuenta del propietario a estado `active`
And registra qué administrador la aprobó y cuándo
And la solicitud desaparece de la lista de pendientes
And en su próximo inicio de sesión el propietario accede a su ruta inicial en lugar de "Cuenta en revisión"

Scenario: Rechazar una solicitud
Given un administrador en el detalle de una solicitud pendiente
When presiona "Rechazar"
Then el sistema exige un motivo de rechazo (obligatorio, 10 a 300 caracteres)
And al confirmar, cambia la cuenta del propietario a estado `rejected` y guarda el motivo, el administrador y la fecha
And la solicitud desaparece de la lista de pendientes

Scenario: Solicitud ya resuelta por otro administrador
Given dos administradores con la misma solicitud abierta
When uno la aprueba o rechaza y luego el otro intenta resolverla
Then el backend rechaza la segunda acción porque la cuenta ya no está en `pending_approval`
And la app informa que la solicitud ya fue atendida y refresca la lista

Scenario: Un usuario que no es administrador intenta ver las solicitudes
Given un cliente o propietario autenticado, o una petición manipulada
When intenta acceder a "Solicitudes de propietarios" o aprobar una cuenta
Then la app no muestra la vista
And el backend rechaza la consulta y la acción

Scenario: Error de red al cargar o resolver solicitudes
Given un administrador en "Solicitudes de propietarios"
When la conexión falla al cargar la lista o al aprobar/rechazar
Then el sistema muestra un error comprensible con opción de reintentar
And no cambia el estado mostrado de la solicitud hasta recibir confirmación del backend

## Feature: Lista de indicativos con bandera (Supabase `phone_country_codes` + `country_flags`) [Hecho 2026-11-04]

> Implementada siguiendo el patrón de `lib/database/repository/client/`
> (`ClientRepository`): `GET /rest/v1/phone_country_codes`, guardado en
> SQLite con el DAO Floor compartido `PhoneCountryCodeDao` y lectura siempre
> desde SQLite. Código: `lib/database/repository/auth/auth_catalog_repository.dart`,
> `lib/models/auth/country_phone_code.dart`,
> `lib/widgets/form/app_country_flag.dart` y `lib/widgets/form/app_phone_field.dart`.
> Dependencia: `country_flags: ^4.1.2`.

### Tabla en Supabase `phone_country_codes` (existente)

| Columna | Tipo | Notas |
| --- | --- | --- |
| `id` | `int` PK | Se guarda en el perfil como `phoneCountryCodeId` |
| `country_code` | `text` | ISO 3166-1 alfa-2 (`CO`, `MX`…); la bandera se obtiene de aquí |
| `country_name` | `text` | Texto visible en español |
| `calling_code` | `text` | Con `+`, p. ej. `+57` |
| `active` | `bool` | Solo los activos se muestran |
| `created_at` / `updated_at` | `timestamp` | No se consultan |

Al 2026-11-04 hay 10 registros: Argentina, Brasil, Chile, Colombia, Ecuador,
España, Estados Unidos, México, Panamá y Perú.

Scenario: Consultar todos los indicativos registrados en Supabase
Given un dispositivo con conexión y sin caché vigente
When el visitante abre la pestaña "Registrarse"
Then el sistema consulta `phone_country_codes` con `select=id,country_code,country_name,calling_code,active`
And guarda todos los registros (activos e inactivos) en la tabla `phone_country_codes` de SQLite, reemplazando los anteriores
And guarda la fecha de sincronización en SharedPreferences (`catalogs_synced_at`)

Scenario: Mostrar los indicativos como una lista con bandera
Given los indicativos cargados
When el visitante toca el campo "Indicativo"
Then se abre un panel con la lista de países activos ordenados por nombre
And cada fila muestra la bandera obtenida con `country_flags` a partir de `country_code`, el nombre del país y el indicativo
And el campo compacto muestra la bandera y el indicativo del país seleccionado

Scenario: Código ISO sin bandera disponible
Given un registro de Supabase con un `country_code` que `country_flags` no reconoce
When se muestra la lista
Then la fila se muestra con un recuadro vacío en lugar de la bandera, sin lanzar errores
And el nombre y el indicativo siguen visibles

Scenario: Accesibilidad de la bandera
Given un lector de pantalla activo
When recorre el campo o la lista
Then la bandera se ignora (es decorativa) y se anuncian el nombre del país y el indicativo

### Casos de prueba

| ID | Tipo | Caso | Resultado esperado | Estado |
| --- | --- | --- | --- | --- |
| IN-01 | Unitaria (repositorio, SQLite FFI) | Respuesta con CO, MX y EC inactivo | Devuelve CO y MX ordenados; SQLite guarda los 3; fecha de sincronización guardada | Pasa |
| IN-02 | Unitaria | Caché de menos de 24 h | No llama a la red | Pasa |
| IN-03 | Unitaria | Caché vencida | Refresca y elimina lo que ya no está en Supabase | Pasa |
| IN-04 | Unitaria | Supabase responde 500 o JSON malformado | Usa la caché | Pasa |
| IN-05 | Unitaria | Sin conexión y sin caché / Supabase sin activos | `AuthCatalogRepositoryException` | Pasa |
| IN-06 | Unitaria | Supabase sin configurar | Semilla Colombia +57 sin llamar a la red | Pasa |
| IN-07 | Widget (`test/widgets/app_phone_field_test.dart`) | Campo con Colombia | Una bandera y `+57` | Pasa |
| IN-08 | Widget | Abrir la lista | Una bandera por país; filtro con `pan'; --` sin resultados ni errores; seleccionar Panamá | Pasa |
| IN-09 | Manual | Registro en un dispositivo real | Se ven los 10 países con bandera | Pendiente |

### Riesgos

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| `phone_country_codes` no publica la longitud del celular por país | La validación usa 7 a 15 dígitos y acepta números que no son válidos en el país | Pedir a quien administra Supabase agregar `phone_min_length` y `phone_max_length` y leerlas en `CountryPhoneCode.fromEntry` |
| Tabla compartida con la rama de moteles (`PhoneCountryCodeDao`) | Un cambio de columnas de otra rama rompe el registro | Coordinar cambios del modelo `PhoneCountryCode`; las pruebas IN-01 a IN-06 lo detectan |
| `country_flags` agrega `jovial_svg` y SVG embebidos | Mayor tamaño de la app | Aceptado por la rama; usar solo a través de `AppCountryFlag` |
| La tabla local obsoleta `country_phone_codes` sigue en el esquema | Confusión al mantener | Retirarla en una migración acordada con las demás ramas |
| Clave publicable con valor por defecto en el código | Lectura del maestro por cualquiera | Es clave pública de solo lectura; mantener RLS sin escritura desde el cliente |

## Feature: Maestro de indicativo telefónico (Supabase + SQLite)

> Los escenarios de esta sección siguen vigentes, pero la tabla real es
> `phone_country_codes` (ver la feature anterior). El orden es por nombre
> del país (Supabase no tiene `sort_order`) y Colombia se preselecciona si no
> hay un indicativo guardado.

Scenario: Primera carga de maestros desde Supabase
Given un dispositivo sin caché local de maestros y con conexión
When el visitante abre la pestaña "Registrarse"
Then el sistema consulta en Supabase los indicativos telefónicos activos
And los guarda en SQLite
And los muestra ordenados por `sort_order`

Scenario: Uso de la caché local en cargas posteriores
Given un dispositivo con los maestros ya guardados en SQLite
When el visitante abre el formulario de registro
Then el sistema muestra los maestros desde SQLite sin esperar a la red
And solo consulta Supabase cuando se fuerza el refresco o la caché supera su vigencia (24 horas, guardada en SharedPreferences)

Scenario: Sin conexión y sin caché
Given un dispositivo sin caché de maestros y sin conexión
When el visitante abre el formulario de registro
Then el selector de indicativo muestra un estado de error con opción de reintentar
And el botón "Crear cuenta" permanece deshabilitado
But la pestaña "Iniciar sesión" sigue funcionando con normalidad

Scenario: Supabase no configurado
Given la app ejecutándose sin `SUPABASE_URL` / `SUPABASE_ANON_KEY`
When se cargan los maestros
Then el sistema usa la caché de SQLite si existe
And si no existe, usa una semilla local mínima de desarrollo (Colombia +57)
And la semilla queda marcada como datos de desarrollo y se reemplaza en cuanto Supabase responda

Scenario: Solo se ofrecen registros activos
Given un registro de un maestro marcado como inactivo en Supabase
When el sistema refresca los maestros
Then ese registro deja de mostrarse en los selectores
And se elimina o marca como inactivo en la caché de SQLite
But los usuarios ya registrados con ese valor conservan la referencia en su perfil

Scenario: Indicativo preseleccionado
Given un visitante que abre el formulario de registro
When se cargan los indicativos
Then el sistema preselecciona el último indicativo usado (SharedPreferences)
And si no hay ninguno guardado, preselecciona Colombia (+57)

Scenario: Búsqueda de país en el selector de indicativo
Given un visitante que abre el selector de indicativo
When escribe parte del nombre del país, su código ISO o el indicativo
Then la lista se filtra mostrando solo las coincidencias
And si no hay coincidencias muestra un estado vacío

## Maestros en Supabase

### Ya definidos en esta rama

`country_phone_codes` (indicativo telefónico por país) — **propuesta no
creada en Supabase**. La tabla real es `phone_country_codes` (ver "Lista de
indicativos con bandera"); estas columnas quedan como propuesta para
ampliarla (sobre todo `phone_min_length` y `phone_max_length`).

| Columna | Tipo | Notas |
| --- | --- | --- |
| `id` | `int` PK | |
| `iso_code` | `text` único | ISO 3166-1 alfa-2, p. ej. `CO` |
| `country_name` | `text` | Texto visible en español |
| `dial_code` | `text` | Con `+`, p. ej. `+57` |
| `flag_emoji` | `text` nullable | Opcional para la UI |
| `phone_min_length` | `int` | Validación del celular |
| `phone_max_length` | `int` | Validación del celular |
| `is_active` | `bool` | |
| `sort_order` | `int` | Colombia primero |

`subscription_plans` (planes de suscripción para propietarios)

La tabla **ya existe** en Supabase y la rama de suscripciones la consulta
hoy con `select=id,name`. Esta rama la **amplía** con las columnas
siguientes, en coordinación con esa rama (agregar columnas no rompe su
consulta actual):

| Columna | Tipo | Notas |
| --- | --- | --- |
| `id` | `int` PK | Existente |
| `name` | `text` | Existente; texto visible en español |
| `description` | `text` nullable | Resumen del plan |
| `price` | `numeric(12,2)` | Precio de referencia; el backend valida el cobro |
| `currency` | `text` | `COP` por defecto |
| `billing_period` | `text` | `monthly` / `yearly` |
| `max_motels` | `int` nullable | Límite de moteles del plan |
| `features` | `text[]` | Características visibles |
| `is_active` | `bool` | |
| `sort_order` | `int` | |

> El maestro `identification_types` (tipo de identificación) se retiró del
> alcance: ningún perfil solicita tipo ni número de documento.

Las tablas son de **solo lectura** para la app: política RLS que permita
`select` con la clave pública y ninguna escritura desde el cliente. La
administración de los registros se hace desde Supabase. El detalle de
conexión (URL, clave, SQL y recorrido) está en el documento "MACHUCO —
Conexión con Firebase y Supabase".

### Maestros adicionales sugeridos (no son criterio de aceptación)

Validar con el equipo antes de comprometerlos en el alcance de esta rama:

- **Versiones de términos y condiciones / política de tratamiento de datos**
  (`legal_documents`): versión, URL y fecha de vigencia, para registrar qué
  versión aceptó cada usuario al registrarse (exigido por la Ley 1581 de 2012
  de habeas data en Colombia). Es lo que reemplazaría el contenido provisional
  del botón "Términos y condiciones".
- **Motivos de rechazo de propietarios** (`owner_rejection_reasons`): lista
  de motivos frecuentes para el rechazo, además del texto libre.
- **Tipos de perfil** (`user_roles`): título, descripción y campos propios
  de cada rol en el registro, en lugar de tenerlos fijos en la vista.
- **Tipo de persona** (`person_types`: natural / jurídica): el registro del
  propietario ya lo necesita. Mientras no exista el maestro, se maneja como
  un enum local `PersonType` en `lib/models/auth/`.
- **Países → departamentos → ciudades** (`countries`, `regions`,
  `cities`): ubicación del usuario y base reutilizable para direcciones de
  moteles.
- **Política de contraseñas** (`password_policies`): longitud mínima y
  reglas, para no fijarlas en el código.
- **Proveedores de inicio de sesión habilitados** (`auth_providers`: correo,
  Google, GitHub): permite encender o apagar "Continuar con Google" y
  "Continuar con GitHub" sin publicar una nueva versión.
- **Motivos de bloqueo o desactivación de cuenta** (`account_block_reasons`):
  mensaje claro al usuario cuando su cuenta está deshabilitada.
- **Género o tratamiento** (`genders`), solo si producto lo necesita.

## Alcance técnico

- **Directorios de trabajo**:
  - Vistas: `lib/views/login/` (`login_page.dart`, `logout_navigation.dart`), `lib/views/register/` y `lib/views/admin_access/` (`administrators_page.dart`, `create_admin_page.dart`, `owner_approvals_page.dart`, `owner_approval_detail_page.dart`).
  - Controllers: `lib/controllers/auth/login_controller.dart`. Si la carga de maestros crece, separarla en `lib/controllers/auth/auth_catalog_controller.dart`. Las vistas del administrador usan `lib/controllers/auth/admin_access_controller.dart` (creación de administradores y aprobación de propietarios). Validadores de formato en `lib/controllers/auth/validators/`.
  - Rutas nuevas en `lib/routes/routes.dart` (solo rol administrador): `adminAdministrators` (`/auth/admin/administrators`), `adminCreateAdministrator` (`/auth/admin/administrators/new`), `adminAdministratorDetail` (`/auth/admin/administrators/detail`), `adminOwnerApprovals` (`/auth/admin/owner-approvals`) y `adminOwnerApprovalDetail` (`/auth/admin/owner-approvals/detail`). Se enlazan desde el perfil o menú del administrador.
  - Modelos: `lib/models/auth/`.
    - `registered_user.dart`: agregar `firstNames`, `lastNames`, `phoneCountryCodeId` y `accountStatus`. No incluir campos de tipo ni número de documento.
    - Datos propios por rol: `birthDate` (cliente); `personType` y `nit` obligatorios y `companyName` solo para persona jurídica (propietario). Modelarlos como campos opcionales validados por rol o como un objeto de detalle por rol; no crear tres modelos de usuario paralelos.
    - Nuevos: `country_phone_code.dart`, `person_type.dart` (enum), `account_status.dart` (enum: `active`, `pending_approval`, `rejected`, `disabled` y, para administradores eliminados, `anonymized`) y `owner_approval_request.dart` (solicitud con fecha, y al resolverse: administrador, fecha y motivo de rechazo). Al 2026-10-28 existen `country_phone_code.dart`, `account_status.dart` y `user_profile.dart`; `person_type.dart` y `owner_approval_request.dart` siguen pendientes.
    - Se mantiene `RegisteredUserRole { admin, client, owner }` como único enum de rol.
  - Registro por rol: la validación específica de cada rol vive en el controller (o en un validador por rol en `lib/controllers/auth/`), no en la vista. La vista solo decide qué bloque de campos mostrar según el rol elegido.
  - Servicios de autenticación: `lib/service/auth/`.
    - Destino final: `firebase_auth_service.dart` como **único** proveedor. **Hecho (2026-10-27):** decisión documentada y `firebase_core`, `firebase_auth` y `cloud_firestore` agregados.
    - `hardcoded_auth_service.dart` y el flag `AUTH_USE_HARDCODED_AUTH_USERS` se **eliminan** (ver "Retiro de las credenciales de prueba"). El contrato `AuthService` / `AuthSession` / `AuthFailure` solo se conserva como costura para fakes de prueba; no se agregan implementaciones alternativas.
    - Operaciones nuevas en `FirebaseAuthService`: `deleteAccount({required String password})` (reautentica con `EmailAuthProvider.credential`, borra `users/{uid}` vía `UserProfileRepository.deleteProfile` y llama a `User.delete()`). `requestPasswordReset` ya existe; falta mapear `too-many-requests`.
    - `firestore.rules`: permitir `delete` de `users/{uid}` solo si `request.auth.uid == uid` (y nunca del último administrador, validado en backend cuando exista).
    - La creación de administradores y la aprobación/rechazo de propietarios se exponen como operaciones del backend; la app solo las invoca a través de un repositorio (p. ej. `lib/database/repository/auth/admin_access_repository.dart`, aún no creado).
    - Limpieza (no es un escenario): el código heredado de un proveedor anterior (`auth0_auth_service.dart`, `auth0_config.dart`, la dependencia `auth0_flutter` y sus referencias en `login_controller.dart`, `login_page.dart`, `logout_navigation.dart`, `backend_registered_user_directory.dart`, `hardcoded_auth_service.dart` y las pruebas) se retira al integrar Firebase. Antes de borrarlo, verificar con `grep` que ninguna otra rama lo importa. No se escriben escenarios ni se amplía ese código. **Hecho (2026-10-27):** `FirebaseAuthService` reemplaza a Auth0; el contrato quedó en `auth_service.dart` y los flags en `auth_config.dart`.
  - Maestros: `lib/database/repository/auth/auth_catalog_repository.dart` (REST a Supabase `phone_country_codes` + caché con el DAO compartido `PhoneCountryCodeDao`), siguiendo el patrón de `lib/database/repository/client/client_repository.dart`. `auth_catalog_dao.dart` se eliminó (2026-11-04); `subscription_plan_options` sigue pendiente. Modelo nuevo: `lib/models/auth/subscription_plan_option.dart` (no reutilizar `SubscriptionPlan` de la rama de suscripciones, que solo tiene `id` y `name`, ni su tabla `subscriptions` de SQLite).
  - Almacenamiento en Firebase: el perfil del usuario y las solicitudes de propietarios se leen y escriben a través de un repositorio (p. ej. `lib/database/repository/auth/user_profile_repository.dart`), nunca desde la vista.
  - Preferencias: `SharedPreferencesLocalService` con `namespace: 'auth'` (contrato en `lib/service/storage/local_preferences_service.dart`). El acceso compartido al correo se expone con una clase pequeña (p. ej. `lib/service/auth/auth_preferences.dart`) que otras ramas consumen sin conocer las claves.
- **Claves de SharedPreferences (namespace `auth`)**: `current_user_email` (string; correo del usuario autenticado, compartido con otras funcionalidades), `remember_email` (bool), `remembered_email` (string), `last_country_code_id` (int), `last_auth_tab` (string), `catalogs_synced_at` (string ISO-8601). **Nota 2026-11-09:** `SharedPreferencesLocalService` solo acepta claves en lowerCamelCase sin puntos, así que las claves reales son `currentUserEmail`, `rememberEmail`, `rememberedEmail`, `lastCountryCodeId` y `catalogsSyncedAt` (los nombres en snake_case son solo descriptivos). API: `AuthPreferences.loadRememberedEmail()`, `saveRememberedEmail(email)` y `clearRememberedEmail()`; el controller las usa en `LoginController.login(rememberEmail:)` y `loadRememberedEmail()`. **Nunca** guardar contraseñas, tokens ni el NIT en SharedPreferences. La persistencia del token la maneja el SDK de Firebase. Al eliminar la cuenta se borra el namespace `auth` completo.
- **SQLite**: las tablas nuevas se registran en `lib/database/app_database.dart` con una migración nueva (versión actual: 12; `country_phone_codes` se creó en la 10 → 11. `auth_user_profile` irá en la 12 → 13 con su DAO `lib/database/repository/auth/auth_user_profile_dao.dart` y su entidad en `lib/models/auth/`; la caché de planes, si se implementa, en otra migración). Es un archivo compartido con otras ramas (`room`, `suscripcion`, `motel`, `client`, pagos): coordinar el número de versión antes de hacer merge para no chocar migraciones.
- **Configuración de Supabase**: reutilizar `SUPABASE_URL` y `SUPABASE_ANON_KEY` vía `--dart-define`. Las ramas de suscripciones y notificaciones leen `SUPABASE_PUBLISHABLE_KEY`; proponer al equipo un solo nombre. `SupabaseRoomConfig` es específico de habitaciones; si se necesita una configuración común, proponer al equipo una sola clase compartida en lugar de crear otra copia.
- **Dependencias de entrada**: rutas por rol de `lib/routes/routes.dart` (`clientMotels`, `ownerMotels`, `ownerManagement`); componentes del sistema de diseño (`AppTextField`, `AppButton`, `AppCard`, `AppBottomSheet`).
- **Dependencias de salida**: todas las vistas protegidas dependen de la sesión que expone `LoginController` (usuario y rol). `logout_navigation.dart` es consumido por otras ramas para cerrar sesión: no cambiar su firma sin avisar. El lector del correo compartido (`AuthPreferences` o equivalente) también es una API pública para otras ramas.
- **Fuera de alcance**:
  - Las vistas de destino de cada rol (pertenecen a otras ramas), salvo las vistas "Administradores" y "Solicitudes de propietarios" del administrador.
  - La gestión general de clientes y propietarios (activar o desactivar cuentas existentes). La gestión de administradores (registrar, actualizar y eliminar con anonimización) **sí** es de esta rama.
  - Las vistas de otros roles distintos de "Eliminar cuenta": se definirán después, empezando por las de administrador.
  - El contenido real de los términos y condiciones (solo se deja el botón con contenido provisional).
  - El CRUD de los maestros (se administran directamente en Supabase).
  - El cobro, la activación y la gestión de la suscripción del propietario (rama de suscripciones); aquí solo se consultan los planes y se registra el plan de interés.
  - Inicio de sesión por SMS/OTP con el número de celular.
  - La implementación del login y registro con Google/Gmail y GitHub: aquí solo se definen sus escenarios; se implementa más adelante en cooperación con otras ramas.
  - Verificación de correo obligatoria antes del primer ingreso (queda como mejora posible con Firebase).
- **Reglas de seguridad**:
  - La autorización por rol se valida en el backend. El rol enviado por la app es solo una solicitud: la creación de administradores, la aprobación de propietarios, la mayoría de edad del cliente y el estado inicial del propietario se verifican del lado del servidor.
  - El registro público nunca crea cuentas `admin`.
  - Toda consulta a SQLite o Supabase usa parámetros enlazados; nunca se concatenan datos del usuario en una consulta.
  - Los mensajes de error de login y de recuperación de contraseña no deben revelar si un correo existe.
  - El correo guardado en SharedPreferences sirve para mostrar y precargar datos, no para autorizar.
  - Ninguna vista consulta Supabase, Firebase, SQLite ni SharedPreferences directamente: siempre a través del controller y del repositorio o servicio.

## Pendientes de validar con producto

Estas reglas son una propuesta de esta rama. Se implementan así mientras
nadie las corrija, pero deben confirmarse:

- Los campos propios de cada rol (fecha de nacimiento del cliente; tipo de
  persona, NIT y razón social del propietario).
- La edad mínima de 18 años para clientes.
- La longitud del número base del NIT de persona natural (propuesta: 6 a 10
  dígitos más dígito de verificación).
- Si el propietario elige el plan de suscripción al registrarse (propuesta,
  obligatorio) o después de ser aprobado, y cuáles son los planes reales.
- ~~Si el almacenamiento en Firebase es Cloud Firestore, Cloud Storage o ambos,
  y si el rol se guarda como custom claim (requiere Cloud Functions) o en un
  documento de Firestore.~~ **Resuelto (2026-10-27):** Cloud Firestore; el rol
  y el estado se guardan en el documento `users/{uid}`. Cloud Storage
  (archivos) sigue sin decidir.
- ~~Si el administrador creado define su contraseña mediante correo de
  restablecimiento o con una contraseña temporal.~~ **Resuelto (2026-11-09):**
  contraseña temporal generada por la app, sin correo ni SMS; el nuevo
  administrador la cambia en su primer ingreso.
- Eliminación de cuenta: si se exige resolver reservas, moteles y
  suscripciones antes de eliminar (propuesta) o se anonimizan; qué datos de
  otras ramas (reseñas, PQRS, pagos) se borran, anonimizan o conservan por
  obligación legal; y si se implementa como Cloud Function (requiere plan
  Blaze de Firebase).
- ~~**Backend de la gestión de administradores**: Cloud Functions con Admin
  SDK (plan Blaze).~~ **Resuelto (2026-11-09): no hay Cloud Functions.** Se usa
  el plan Spark: la app crea el usuario con una instancia secundaria de
  Firebase y las reglas de Firestore son la autoridad. Limitación aceptada: el
  usuario de Auth de otro administrador eliminado no se borra (su correo sigue
  ocupado). Ver `docs/decisions_log.md` (2026-11-09).
- Qué campos conserva la anonimización (la tabla de "Gestión de
  administradores" está implementada) y si un administrador puede eliminar a
  otro sin la confirmación de un tercero (hoy basta con reautenticarse y las
  reglas no exigen un tercero).
- `isAdmin()` en `firestore.rules` (fuera de esta rama) solo comprueba el rol:
  endurecerlo con el estado `active` con la rama dueña.
- Si las alertas de validación de una solicitud de propietario solo informan
  (propuesta) o algunas, como un NIT duplicado, deben bloquear la aprobación.
- Si un propietario rechazado puede corregir sus datos y volver a enviar la
  solicitud, o debe registrarse de nuevo.
- Si "Términos y condiciones" pasará a requerir una casilla de aceptación
  obligatoria y qué documento mostrará.

## Notas para el agente

- **Contexto histórico**: esta rama construyó antes el módulo de bookings
  (Cliente, Propietario y Administrador en `lib/views/booking/`,
  `lib/controllers/booking/`, `lib/models/booking/`). Ese trabajo ya no es
  responsabilidad de esta rama; no refactorizarlo como parte del login.
- El login actual ya tiene la base: pestañas de login y registro, selector
  de tipo de perfil y una tarjeta de sesión activa (los avisos de modo
  desarrollo y los usuarios de prueba se retiran, ver "Retiro de las
  credenciales de prueba"). **Hecho (2026-10-28):** se retiraron los avisos
  del proveedor anterior, el indicativo fijo `'CO +57'` se reemplazó por
  `AppPhoneField` alimentado por el maestro y la opción "Administrador" ya
  no aparece en el registro público. Pendiente: la pantalla "Cuenta en
  revisión" (hoy el propietario pendiente solo ve un mensaje en el login).
- `login_page.dart` tiene más de 1100 líneas. Al tocarlo, extraer los
  componentes reutilizables a `lib/widgets/` en lugar de seguir creciendo el
  archivo.
- Las pruebas del controller deben inyectar un servicio de autenticación
  falso, un `LocalPreferencesService` en memoria y repositorios falsos (de
  maestros y de acceso del administrador). Ninguna prueba debe depender de
  red real. Incluir casos con cadenas de inyección SQL y con cada regla de
  formato.

### Intención visual

- **Login**: logo y título "Machuco" arriba, selector de pestañas
  "Iniciar sesión / Registrarse", formulario dentro de un AppCard con
  correo, contraseña (con botón mostrar/ocultar), casilla "Recordar mi
  correo", enlace "¿Olvidaste tu contraseña?" y botón principal "Ingresar".
  Los botones secundarios "Continuar con Google" y "Continuar con GitHub"
  quedan ocultos o deshabilitados ("Próximamente") hasta que se implementen.
- **Sin aviso de modo desarrollo**: el banner y la lista de usuarios de
  prueba se retiran junto con las credenciales de prueba.
- **Eliminar cuenta**: acción de peligro al final del perfil o menú del
  usuario (color de error del design system). Abre un AppBottomSheet con
  título "Eliminar cuenta", lista de lo que se borra, campo de contraseña,
  campo de confirmación "ELIMINAR" y botones "Eliminar definitivamente"
  (peligro, deshabilitado hasta completar ambos campos) y "Cancelar".
- **Registro**: una sola pantalla con scroll, sin stepper. Primero va el
  tipo de perfil (tarjetas seleccionables: **Cliente y Propietario**),
  porque define el resto del formulario. Luego: nombres y apellidos
  (sin campos de documento) → indicativo + celular
  (en una fila) → **bloque propio del rol** dentro de un AppCard con título
  (Cliente: fecha de nacimiento; Propietario: tipo de persona, NIT, si es
  jurídica razón social, y los planes de suscripción como tarjetas
  seleccionables con nombre, precio, periodicidad y características) → correo → contraseña → confirmación →
  enlace "Términos y condiciones" → "Crear cuenta". Los bloques que
  aparecen o desaparecen según el rol usan una transición corta con los
  tokens de duración del design system. Los errores de formato se muestran
  debajo de cada campo con el color de error del design system.
- **Términos y condiciones**: botón de texto (estilo enlace) que abre un
  AppBottomSheet con título, texto provisional y botón "Cerrar".
- **Cuenta en revisión** (Propietario): pantalla de estado con ícono,
  mensaje explicativo, el correo registrado y el botón "Cerrar sesión".
  Variante "Solicitud rechazada" con el motivo.
- **Administradores** (Administrador): lista en AppCards con nombre, correo,
  estado y la etiqueta "Tú" en la cuenta propia; botón principal "Crear
  administrador" que abre un formulario con los mismos componentes y
  validaciones del registro (sin contraseña). El detalle muestra los datos y
  las acciones "Editar" y "Eliminar cuenta" (peligro), que abre un
  AppBottomSheet con lo que se anonimiza, la reautenticación y "ELIMINAR".
- **Solicitudes de propietarios** (Administrador): lista en AppCards con
  nombre o razón social, tipo de persona, correo y fecha; contador de
  pendientes en el acceso desde el perfil; estado vacío y estado de error
  con "Reintentar". El detalle muestra todos los datos y los botones
  "Aprobar" (principal) y "Rechazar" (secundario/peligro); rechazar abre un
  AppBottomSheet con el campo de motivo obligatorio.
- **Selector de indicativo**: un campo compacto con bandera (imagen de
  `country_flags` vía `AppCountryFlag`) e indicativo (p. ej. bandera + "+57"). Al tocarlo abre un AppBottomSheet con buscador y una
  lista de país, nombre e indicativo.
- **Estados de los selectores**: cargando (skeleton dentro del campo),
  error (mensaje corto y "Reintentar") y vacío (en la búsqueda).
- **Recuperación de contraseña**: AppBottomSheet con el campo de correo y el
  botón "Enviar instrucciones". Al confirmar muestra el mensaje neutro.

### Nota sobre la construcción de la interfaz (UI)

El selector de indicativo debe construirse como widget genérico en
`lib/widgets/` (p. ej. `AppPhoneField`) que reciba los datos por
parámetro, sin conocer Supabase ni el login. Así otras ramas (perfil de
cliente, registro de propietario, PQRS) pueden reutilizarlos. Usar siempre
los tokens del design system, sin colores, radios ni duraciones fijos
(el `height: 52` actual del indicativo debe pasar a un token o al propio
`AppTextField`).
