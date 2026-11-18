# Login y registro en MACHUCO

Documento generado a partir del código de la rama `feature-juan_gallego`. Describe cómo funcionan hoy el inicio de sesión y el registro con correo y contraseña. También resume los flujos relacionados: sesión, recuperación de contraseña, eliminación de cuenta y acceso social.

## 1. Resumen

- **Autenticación:** Firebase Authentication con correo y contraseña. Es la única implementación de producción (`FirebaseAuthService`).
- **Perfil, rol y estado:** viven en Firestore, en `users/{uid}`. El rol y el estado nunca se toman de la UI.
- **Autorización real:** `firestore.rules`. La UI y el controller solo reflejan el resultado y deciden a qué pantalla ir.
- **Datos locales no sensibles:**
  - `shared_preferences` (namespace `auth`) guarda el correo de la sesión, el correo recordado y el último indicativo.
  - SQLite (Floor, tabla `auth_user_profile`) guarda un perfil básico en caché.
- **Datos maestros (Supabase vía REST):** indicativos telefónicos y planes de suscripción. Se leen con `AuthCatalogRepository`, que usa SQLite como caché.
- **Pantalla única:** `LoginPage` tiene dos pestañas, "Ingresar" y "Crear cuenta" (`AuthTab`).

## 2. Arquitectura por capas

```
views/login/login_page.dart        ─┐
views/register/register_form.dart   │  UI (formularios, snackbars, navegación)
widgets/auth/*                     ─┘
            │
            ▼
controllers/auth/login_controller.dart   Lógica de aplicación (ChangeNotifier)
controllers/auth/validators/*            Validación y normalización de formato
            │
            ▼
service/auth/auth_service.dart           Contrato (AuthService, AuthSession, AuthFailure)
service/auth/firebase_auth_service.dart  Implementación con Firebase Auth + Firestore
service/auth/auth_preferences.dart       shared_preferences (namespace `auth`)
database/repository/auth/*               Perfiles Firestore, caché Floor, catálogos Supabase
```

| Pieza | Archivo | Responsabilidad |
|---|---|---|
| `LoginPage` | `lib/views/login/login_page.dart` | Pantalla con pestañas. Arma el controller y reacciona a los resultados. |
| `LoginForm` | `lib/widgets/auth/login_form.dart` | Campos de correo y contraseña, casilla "Recordar mi correo", botón "Ingresar" y enlace "¿Olvidaste tu contraseña?". |
| `RegisterForm` | `lib/views/register/register_form.dart` | Registro por rol en una sola pantalla con scroll. |
| `ProfileFields`, `ClientRegistrationSection`, `OwnerRegistrationSection`, `RoleSelector`, `PlanSelector` | `lib/views/register/` | Campos comunes y campos propios de cada rol. |
| `LoginController` | `lib/controllers/auth/login_controller.dart` | Orquesta login, registro, sesión, reset de contraseña, eliminación de cuenta, indicativos y planes. |
| `AuthValidators` / `AuthInputNormalizer` | `lib/controllers/auth/validators/` | Reglas de formato y normalización. |
| `AuthService` / `FirebaseAuthService` | `lib/service/auth/` | Contrato y acceso a Firebase. |
| `AuthPreferences` | `lib/service/auth/auth_preferences.dart` | Preferencias locales. |
| `buildLoginController` | `lib/views/login/auth_controller_factory.dart` | Ensambla el controller de producción. |
| `AccountSessionWatcher` | `lib/service/auth/account_session_watcher.dart` | Detecta con la app abierta que la cuenta ya no es válida. |

`LoginPage` recibe `authService`, `controller` y `socialAuthService` opcionales. Con eso las pruebas pueden inyectar *fakes*. En producción, `buildLoginController` crea:

```dart
LoginController(
  authService: FirebaseAuthService(),
  preferences: AuthPreferences(),
  catalogRepository: AuthCatalogRepository.fromEnvironment(...),
  profileCache: FloorAuthUserProfileRepository(),
);
```

## 3. Modelos clave

- **`AuthSession`** (`auth_service.dart`): `userId`, `name`, `email`, `role`, `accessToken`, `idToken`, `accountStatus` y `profile`. Representa al usuario autenticado en memoria.
- **`AuthFailure(type, message, {rejectionReason})`**: error ya traducido a un mensaje en español. La UI nunca ve errores crudos de Firebase.
  - Tipos principales: `invalidCredentials`, `emailAlreadyExists`, `weakPassword`, `network`, `tooManyRequests`, `accountDisabled`, `accountRejected`, `accountDeleted`, `profileIncomplete`, `invalidInput`, `requiresRecentLogin`, `lastAdministrator`, `invalidConfiguration`, `unknown`.
  - Otros tipos: `accountPending`, `cancelled`, `accountExistsWithDifferentCredential`, `emailUnavailable`, `emailNotVerified`, `providerMisconfigured`.
- **`RegisteredUserRole`**: `client`, `owner`, `admin`.
- **`AccountStatus`**: `active`, `pendingApproval`, `rejected`, `disabled`, `anonymized`. En Firestore se guardan como `snake_case`, por ejemplo `pending_approval`.
  - Un valor ausente o desconocido devuelve `null` y se bloquea. Nunca se concede acceso por omisión.
- **`RegistrationData`**: datos del formulario de registro. Tiene dos fábricas, `RegistrationData.client(...)` y `RegistrationData.owner(...)`.
- **`UserProfile`**: documento `users/{uid}`.

## 4. Flujo de login (correo y contraseña)

1. **Arranque de `LoginPage`** (`_bootstrap`):
   - Carga el correo recordado (`loadRememberedEmail`) y precarga el campo si la casilla estaba marcada.
   - Si no hay correo recordado, precarga el último correo de sesión (`loadCurrentUserEmail`).
   - Si Firebase está configurado, intenta `restoreSession()`. Con sesión válida va directo al home del rol. Sin sesión, intenta reanudar un flujo social (`resumeSession`).
   - Arranca una sola vez `AccountSessionWatcher` (`ensureAccountSessionWatcher`).
2. **Validación en el formulario:** `AuthValidators.email` y `AuthValidators.password` (ver sección 6).
3. **`_submitLogin`:** si ya hay un envío en curso, sale. Si el formulario no valida, sale. Si Firebase no está configurado, muestra "La autenticación no está disponible en este momento." Después llama a `LoginController.login(email, password, rememberEmail)`.
4. **`LoginController.login`:**
   - Marca `isSubmitting`.
   - Normaliza el correo (trim y minúsculas) y llama a `AuthService.login`.
   - Si funciona, `_startSession` guarda la sesión, registra el usuario en analítica, guarda el correo de sesión en `shared_preferences` y cachea el perfil en SQLite.
   - Registra `logLogin(password)`.
   - Si "Recordar mi correo" está marcada, guarda el correo. Si no, borra el recordado.
5. **`FirebaseAuthService.login`:**
   - Llama a `signInWithEmailAndPassword`.
   - Construye la sesión con `_toSession(user)`, que lee `users/{uid}`.
   - Si no existe el perfil, lanza `profileIncomplete` (ver 4.2). Si el estado bloquea el acceso, cierra sesión de Firebase y lanza el `AuthFailure` correspondiente.
   - Si todo está bien, obtiene el `idToken` con `getIdTokenResult()`.
6. **Navegación** (`goToSessionHome` y `LoginController.resolvePostLoginRoute`):

| Condición | Destino |
|---|---|
| Administrador con `mustChangePassword == true` | `AuthRoutes.adminChangePassword` |
| Estado `pendingApproval` (propietario) | `AuthRoutes.accountReview` |
| Rol `client` | `AppRoutes.clientMotels` |
| Rol `owner` | `AppRoutes.ownerMotels` |
| Rol `admin` | `AppRoutes.ownerManagement` |

La navegación usa `pushNamedAndRemoveUntil`, así que el botón "atrás" no vuelve al login.

### 4.1 Estados de cuenta al iniciar sesión

La regla vive en `FirebaseAuthService.accountAccessFailure`. Es compartida con el login social.

| `accountStatus` | Resultado |
|---|---|
| `active` | Entra. |
| `pendingApproval` + rol `owner` | Entra con sesión, pero va a "Cuenta en revisión". `firestore.rules` le impide operar hasta que sea aprobado. |
| `pendingApproval` + otro rol | Error `unknown`: "No pudimos verificar el estado de tu cuenta...". |
| `rejected` | `accountRejected`. La UI abre `AccountReviewPage` con el motivo del rechazo. |
| `disabled` | `accountDisabled`. Muestra un aviso en el formulario. |
| `anonymized` | `accountDeleted`: "Esta cuenta ya no existe." El mensaje es neutro a propósito. |
| Ausente y rol `admin` | `invalidConfiguration`. |
| Ausente y otro rol | `unknown`. |

Cuando se bloquea, se llama a `signOut()` de Firebase y se borra la caché local. `LoginController._isBlockingFailure` cubre `accountDisabled`, `accountRejected` y `accountDeleted`.

### 4.2 Usuario autenticado sin perfil

Si el usuario existe en Firebase Auth pero no tiene `users/{uid}`, `_toSession` lanza `profileIncomplete`. **No se le da acceso de cliente por omisión**, porque sin perfil no hay rol ni términos aceptados.

La sesión de Firebase se conserva para que el flujo "Completar perfil" (`CompleteProfilePage`, vía `FirebaseSocialAuthService.completeProfile`) pueda retomarla. Normalmente esto ocurre con el acceso social.

### 4.3 Manejo de errores en la UI (`_handleLoginFailure`)

- `accountRejected`: navega a `AccountReviewPage` (rechazada) con el motivo.
- `accountDisabled`, `network`, `accountDeleted`: aviso persistente (`AuthNotice`) en el formulario. En red ofrece un botón "Reintentar".
- Cualquier otro error: `SnackBar` rojo con `failure.message`.

Mensajes mapeados desde Firebase (`_mapException`):

| Código de Firebase | Mensaje |
|---|---|
| `invalid-credential`, `invalid-email`, `wrong-password`, `user-not-found` | "Correo o contraseña incorrectos." Es deliberadamente genérico para no revelar si el correo existe. |
| `user-disabled` | Cuenta deshabilitada. |
| `email-already-in-use` | "Este correo ya está registrado." |
| `weak-password` | "La contraseña es demasiado débil." |
| `network-request-failed` | "No hay conexión..." |
| `too-many-requests` | "Demasiados intentos..." |
| `operation-not-allowed` | "El ingreso con correo y contraseña no está habilitado en Firebase." |
| Cualquier otro | "Ocurrió un error inesperado." |

## 5. Flujo de registro

El registro vigente es **por rol**: `LoginController.registerAccount(RegistrationData)`. Existe un `register(fullName, ...)` histórico que se conserva por compatibilidad y que la UI no usa.

### 5.1 Formulario (`RegisterForm`)

- Una sola pantalla con scroll, sin *stepper*. Los datos comunes se conservan al cambiar de rol.
- Al abrirse carga el maestro de indicativos (`loadCountryPhoneCodes`). Al elegir "Propietario" carga los planes (`loadSubscriptionPlans`).
- **Campos comunes:** nombres, apellidos, indicativo y celular, correo, contraseña y confirmación de contraseña. También muestra el enlace a los términos (`TermsLink`).
- **Cliente:** fecha de nacimiento (`dd/mm/aaaa`, mayor de 18 años).
- **Propietario:**
  - Tipo de persona (`natural` o `juridica`).
  - NIT con dígito de verificación DIAN.
  - Razón social, solo si es persona jurídica.
  - Plan de suscripción, obligatorio.
- El botón "Crear cuenta" se deshabilita hasta que haya un indicativo seleccionado. Para propietario, además deben estar disponibles los planes.
- Si el rol es propietario y no hay plan elegido, muestra "Selecciona un plan." y no envía.

### 5.2 Controller (`registerAccount`)

1. Resuelve el indicativo elegido (`_resolveCountryCodeFor`).
2. `_prepareRegistration` valida todo con `AuthValidators` y normaliza con `AuthInputNormalizer`. Si algo falla, lanza `AuthFailure(invalidInput, mensaje)`.
   - Rechaza el rol `admin`: "El tipo de cuenta no está disponible para registro."
   - El celular queda como `dialCode + dígitos`.
   - El NIT queda en forma canónica `base-DV`.
3. Llama a `AuthService.registerAccount(prepared)`.
4. Registra `logSignUp(password)` y guarda el último indicativo usado. No lo guarda si es la semilla de desarrollo.

### 5.3 Servicio (`FirebaseAuthService._createAccount`)

1. Comprueba `isPublicRegistrationRole(role)`: solo `client` y `owner`. **El registro público nunca crea administradores.**
2. `createUserWithEmailAndPassword`.
3. `updateDisplayName` y `createProfile` en Firestore, con `users/{uid}`.
4. **Rollback:** si falla guardar el perfil, borra la cuenta recién creada (`_rollbackAccount`) para no dejar usuarios huérfanos. Si eso tampoco es posible, cierra sesión. Devuelve `network` o `unknown` según la causa.
5. `signOut()`: el SDK abre sesión automáticamente al crear la cuenta, y la app la cierra para que el usuario inicie sesión explícitamente.

El perfil se guarda así, según el rol:

| Campo | Cliente | Propietario |
|---|---|---|
| `fullName`, `firstNames`, `lastNames`, `email`, `phoneNumber`, `phoneCountryCodeId`, `role` | Sí | Sí |
| `accountStatus` | `active` | `pending_approval` |
| `birthDate` | Sí | No |
| `personType`, `nit`, `companyName`, `planId` | No | Sí (`companyName` solo si es jurídica) |

`initialAccountStatusFor(role)` define el estado inicial. Coincide con `firestore.rules`.

### 5.4 Qué pasa después (`_submitRegister`)

- **Cliente:** copia el correo en el formulario de login, limpia la contraseña, cambia a la pestaña "Ingresar" y muestra "Cuenta creada correctamente. Ahora inicia sesión."
- **Propietario:** el mensaje es "Solicitud enviada. Un administrador revisará tu cuenta; inicia sesión para ver su estado." Al iniciar sesión irá a "Cuenta en revisión" hasta que un administrador lo apruebe o lo rechace.
- Ante un `AuthFailure`, muestra un `SnackBar` rojo con el mensaje.

## 6. Validaciones (`AuthValidators`)

La validación del cliente mejora la experiencia, pero **no es la autoridad**. Firebase Auth y `firestore.rules` validan de nuevo.

| Campo | Regla |
|---|---|
| Correo | Formato `usuario@dominio.ext`, máx. 254 caracteres y parte local máx. 64. Sin caracteres de control ni emojis. Se recorta y se pasa a minúsculas. |
| Nombres y apellidos | 2 a 50 caracteres. Solo letras latinas, espacios, guion y apóstrofo. Sin espacios dobles. |
| Celular | Solo dígitos. La longitud mínima y máxima depende del país seleccionado (maestro de indicativos). Se descartan los espacios. |
| Contraseña | Mínimo 8 caracteres, sin reglas de complejidad. No se recorta. |
| Confirmación | Debe coincidir con la contraseña. |
| Fecha de nacimiento | Fecha real, no futura, año ≥ 1900 y edad ≥ 18. Acepta `dd/mm/aaaa` o `aaaa-mm-dd` y rechaza fechas inexistentes como 31/02. |
| NIT | Jurídica: 9 dígitos + DV. Natural: 6 a 10 dígitos + DV. Guion opcional. El DV se verifica con el algoritmo DIAN (módulo 11). |
| Razón social | 2 a 120 caracteres. Letras, números, espacios y `. , & -`. |
| Motivo de rechazo (admin) | 10 a 300 caracteres. |

Las consultas a SQLite van parametrizadas (Floor). Los validadores además rechazan caracteres que no pertenecen al formato.

## 7. Sesión: persistencia, restauración y cierre

- **Persistencia del token:** la maneja el SDK de Firebase. La app **no** guarda tokens ni contraseñas.
- **`restoreSession`:**
  - Hace `user.reload()` y reconstruye la sesión desde Firestore.
  - Si la sesión expiró o la cuenta fue eliminada o deshabilitada, hace `signOut` y devuelve `null`.
  - Con error de red conserva la sesión y lanza `network`, para reintentar sin pedir credenciales otra vez.
  - Si el estado de la cuenta es `disabled`, `rejected` o `anonymized`, descarta la sesión y limpia el correo y la caché.
- **`logout`:** `signOut`, borra la sesión en memoria, el usuario de analítica, el correo de sesión y el perfil en SQLite. El correo recordado se **conserva**.
- **`AccountSessionWatcher`** (`account_session_guard.dart`):
  - Revisa al volver a primer plano y cada 15 minutos.
  - Si la cuenta fue eliminada o anonimizada (`user-not-found`), borra todo el namespace `auth` y muestra "Tu cuenta fue eliminada."
  - Si el token expiró (`user-token-expired`, `invalid-user-token`), conserva el correo recordado y muestra "Tu sesión expiró. Inicia sesión de nuevo."
  - En ambos casos lleva al login limpiando la pila.
  - Sin red o con errores de lectura no hace nada. Un usuario sin perfil no se considera eliminado.

### Almacenamiento local (`AuthPreferences`, namespace `auth`)

| Clave | Contenido | Se borra al... |
|---|---|---|
| `currentUserEmail` | Correo del usuario autenticado, solo para mostrar y precargar. | Cerrar sesión o eliminar cuenta |
| `rememberEmail` / `rememberedEmail` | "Recordar mi correo". | Desmarcar la casilla en un ingreso exitoso, o eliminar cuenta (no al cerrar sesión) |
| `lastCountryCodeId` | Último indicativo usado. | Eliminar cuenta |
| `catalogsSyncedAt` | Última sincronización de maestros. | Eliminar cuenta |

El correo guardado **nunca autoriza nada**. Son datos de comodidad.

Las preferencias son *best effort*: si `shared_preferences` falla, el login y el logout continúan (`_runPreference`).

## 8. Recuperación de contraseña

- Se abre desde "¿Olvidaste tu contraseña?" con `showForgotPasswordSheet`.
- `LoginController.requestPasswordReset`:
  - Ignora una segunda llamada mientras hay una en curso.
  - Durante el enfriamiento de **60 segundos** (`passwordResetCooldown`) lanza `tooManyRequests` sin llamar al backend.
  - Valida el formato del correo.
  - Si Firebase responde `too-many-requests`, también activa el enfriamiento.
- `FirebaseAuthService.requestPasswordReset` llama a `sendPasswordResetEmail`. Si el correo no existe (`user-not-found`) lo trata como éxito, para **no revelar qué correos están registrados**.

## 9. Eliminación de cuenta

- Requiere escribir `ELIMINAR` y la contraseña (reautenticación). El controller valida ambos antes de llamar al servicio.
- `FirebaseAuthService.deleteAccount`:
  1. Reautentica con `EmailAuthProvider.credential`.
  2. `removeOrAnonymizeProfile`: borra `users/{uid}`. Un administrador no se borra, sino que se **anonimiza**. Si es el último administrador activo, falla con `lastAdministrator`.
  3. `user.delete()` y `signOut()`.
  - Es idempotente: si el perfil ya no existe, continúa.
- Al terminar, el controller limpia la caché SQLite y todo el namespace `auth`. Los maestros (indicativos) se conservan. Luego la UI vuelve al login con el aviso "Tu cuenta fue eliminada".
- No verifica reservas activas, porque eso no es garantizable desde el cliente.

## 10. Acceso social (Google y GitHub)

- Lo implementa `FirebaseSocialAuthService` (`SocialAuthService`), con `signInWithGoogle`, `signInWithGitHub`, `resumeSession`, `completeProfile`, `linkProvider` y `linkPendingProvider`.
- `AuthService.loginWithGoogle` en `FirebaseAuthService` es un stub que lanza "El ingreso con Google aún no está disponible." La UI usa `SocialAuthService`, no ese método.
- `routeSocialResult` (`social_auth_flow.dart`) enruta el resultado: entra, va a "Completar perfil", va a "Cuenta en revisión" o informa de una cuenta deshabilitada o un error.
- Si el correo ya existe con otro método, `offerPendingProviderLink` ofrece vincular el proveedor tras ingresar con el método original.
- Un usuario social nuevo no tiene `users/{uid}`, así que debe completar su perfil (rol, datos, términos) antes de entrar. Esa pantalla es `CompleteProfilePage`.
- Documentación detallada: `docs/auth/plan-auth-social.md`, `docs/auth/android-setup.md` y `docs/auth/escenarios-auth-social.feature`.

## 11. Autorización en el backend (`firestore.rules`, colección `users`)

- **Lectura:** el propio usuario, un administrador o un propietario activo.
- **Creación pública** (`isPublicRegistration`):
  - Solo si `request.auth.uid == uid`.
  - Rol `client` (estado `active`) o `owner` (estado `pending_approval`).
  - Con solo los campos permitidos y el `email` igual al del token.
  - Nunca un administrador.
- **Administradores:** los crea otro administrador activo (`isAdminCreation`).
- **Actualización:**
  - Un administrador aprueba o rechaza propietarios, y habilita o deshabilita cuentas que no son de administrador.
  - El propio usuario solo cambia su nombre y su celular, y limpia `mustChangePassword` si es un administrador con contraseña temporal.
  - Ninguna regla modifica una cuenta `anonymized`.

Por eso, ocultar un botón en la UI no autoriza ni deniega nada. Cumple la regla del proyecto: *"Validación de autenticación y autorización por rol siempre en el backend"*.

## 12. Resumen de la secuencia

```
LOGIN
LoginForm ─validate─▶ LoginPage._submitLogin ─▶ LoginController.login
   ─▶ FirebaseAuthService.login ─▶ Firebase Auth (signInWithEmailAndPassword)
   ─▶ _toSession ─▶ Firestore users/{uid} (rol + estado)
   ─▶ ¿estado permite acceso? ── no ─▶ signOut + AuthFailure ─▶ aviso / AccountReview
        │ sí
        ▼
   AuthSession ─▶ shared_preferences (correo) + SQLite (perfil) + analytics
   ─▶ resolvePostLoginRoute ─▶ home del rol / revisión / cambio de contraseña

REGISTRO
RegisterForm ─validate─▶ RegistrationData ─▶ LoginController.registerAccount
   ─▶ _prepareRegistration (validar + normalizar)
   ─▶ FirebaseAuthService._createAccount
        createUser ─▶ createProfile(users/{uid}) ─(error)─▶ rollback
        ─▶ signOut
   ─▶ pestaña "Ingresar" (cliente) / mensaje de solicitud enviada (propietario)
```

## 13. Observaciones para el equipo

- En `LoginPage._submitRegister` hay una rama `if (data.role == owner && session != null) _goToRoleHome(session)`. `registerAccount` no deja sesión abierta, así que esa rama solo se activaría si ya hubiera una sesión previa en el controller. El flujo normal del propietario termina en el mensaje de "Solicitud enviada".
- Los métodos `register(...)` (controller y servicio) y `loginWithGoogle` (en `FirebaseAuthService`) existen pero no forman parte del flujo vigente.
- `LoginController` mezcla varias responsabilidades: sesión, registro, reset, eliminación y catálogos. Si crece, vale la pena discutir con el equipo separarlo. La estructura de `lib/` es provisional y no debe reorganizarse sin acuerdo.
- Las reglas de contraseña son mínimas (8 caracteres) y están marcadas en el código como configuración de desarrollo.
