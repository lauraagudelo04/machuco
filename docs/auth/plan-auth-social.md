# Plan — Ingreso y registro con Google y GitHub (Android)

Rama `feature-juan_pablo`, a partir del commit `3bb5397`. Fecha: 2026-11-04.

> **Versión aprobada: Plan de autenticación social v1.0, aprobado el
> 2026-11-04** por el responsable de la rama. Las decisiones aprobadas están
> en la sección 3.1. La etapa 7 (Android) se implementó el mismo día; la
> guía de entorno está en [`android-setup.md`](android-setup.md).
Documento de planeación: **no implementa nada**. Los escenarios están en
[`escenarios-auth-social.feature`](escenarios-auth-social.feature) y lo que
deben hacer otras ramas en [`handoff-otras-ramas.md`](handoff-otras-ramas.md).

## 1. Estado actual

### 1.1 Git

- Rama `feature-juan_pablo`, HEAD `3bb5397`. Los commits de la rama están
  limpios.
- Cambios **sin commit, todos en `android/`** (no los hizo esta rama y quedan
  fuera de cualquier commit hasta que se decida qué hacer con ellos):

| Archivo | Cambio | Diagnóstico |
| --- | --- | --- |
| `android/settings.gradle.kts` | Cambia `google-services` de `4.4.4` a `4.5.0` (con indentación irregular) y agrega una línea en blanco | En la revisión anterior el plugin estaba **declarado dos veces** (4.4.4 dentro del bloque FlutterFire y 4.5.0 debajo). Gradle rechaza un mismo `id` con dos versiones en `plugins {}`, así que el build fallaba. En la copia actual queda **una sola declaración** (4.5.0): el duplicado ya no existe, pero la versión cambió sin acuerdo y el bloque `START/END: FlutterFire Configuration` lo puede reescribir `flutterfire configure` |
| `android/gradle.properties` | Agrega `org.gradle.java.home=C:\\Program Files\\Android\\Android Studio\\jbr` | Es una ruta **de este equipo**. En otro equipo (o en CI) que no tenga esa ruta exacta, Gradle se niega a arrancar. Va en `~/.gradle/gradle.properties` del usuario o en `JAVA_HOME`, no en el repo |
| `android/app/build.gradle.kts` | Agrega un bloque `signingConfigs { debug { storeFile file('debug.keystore') … } }` | **Rompe el build**: (1) usa sintaxis Groovy (`storeFile file('…')`, `keyAlias '…'`) dentro de un archivo Kotlin DSL; (2) quedó dentro de `defaultConfig`, cuya llave de cierre ahora cierra `signingConfigs`, así que el archivo queda con llaves desbalanceadas; (3) `debug {}` no existe en Kotlin DSL (es `getByName("debug")`); (4) apunta a `android/app/debug.keystore`, que no existe (el keystore está en `android/debug.keystore`, ignorado por `**/*.keystore`); (5) escribe credenciales de keystore en un archivo versionado |
| `android/app/google-services.json` | Agrega clientes OAuth de Android (tipo 1) con huella de certificado | Es el paso que habilita Google Sign-In: el SHA de algún keystore ya está registrado en Firebase. Hay que confirmar **de qué keystore** es la huella (debug de quién) antes de versionarlo |
| `android/build/` (sin seguimiento) | Carpeta de reportes de Gradle | No está ignorada: `android/.gitignore` no incluye `build/` y el `/build/` de la raíz solo cubre la raíz. No debe entrar en un commit |

### 1.2 SQLite (Floor)

| Ref | `version:` en `app_database.dart` |
| --- | --- |
| `feature-juan_pablo` (local) | **13** (`migration12To13` crea `auth_user_profile`) |
| `origin/develop` | 12 |
| `origin/feature-juan_pablo` | 11 (el push está pendiente) |
| `origin/feature_marco` | 10 |
| Resto de ramas remotas con base | 2 a 9 |

Ninguna ref remota define `migration12To13` ni `auth_user_profile`. Se
revisaron las refs locales de `origin/*` (último fetch: 2026-11-04 20:27),
sin hacer `fetch` nuevo, así que puede haber versiones posteriores sin
descargar. **Riesgo**: si otra rama publica su propia versión 13 antes del
merge, se repite el choque de la versión 10. Hay que reservar la 13 con el
equipo.

### 1.3 Firestore

- `firebase.json` define `firestore.rules` y `firestore.indexes.json`, pero
  no tiene bloque `emulators` (se usarían los puertos por defecto).
- **No se han desplegado** las reglas ni el índice
  (`users`: `role`, `accountStatus`, `createdAt`).
- Campos de `users/{uid}` (`firestore.rules:189-235`):
  - **obligatorios al crear**: `fullName` (3-100), `email` (debe ser igual a
    `request.auth.token.email`), `phoneNumber` (4-20), `role` (`client` u
    `owner`), `accountStatus` (`active` para cliente, `pending_approval` para
    propietario) y `createdAt == request.time`;
  - **opcionales**: `firstNames`, `lastNames`, `phoneCountryCodeId`,
    `birthDate` (solo cliente, mayor de 18 años), `personType`, `nit`,
    `companyName` (solo jurídica), `planId` (solo propietario);
  - **de auditoría** (solo los escribe un admin): `approvedBy`/`approvedAt` y
    `rejectionReason`/`rejectedBy`/`rejectedAt`.
- `isAdmin()` (lectura, `firestore.rules:10`) **no** exige
  `accountStatus`. `isActiveAdmin()` (aprobar o deshabilitar,
  `firestore.rules:107`) sí exige `accountStatus == 'active'`.
- Emulador: `firebase-tools` 15.34.1 está instalado. El `java` del PATH es
  1.8, insuficiente para el emulador. El JBR de Android Studio (OpenJDK 21)
  sí sirve si se exporta `JAVA_HOME` solo para esa sesión. **No se ejecutó.**
  Para probar reglas hace falta además `@firebase/rules-unit-testing` (Node),
  que es una herramienta nueva y requiere decisión.

### 1.4 Funcionalidad de autenticación ya en `3bb5397`

| Área | Estado | Evidencia |
| --- | --- | --- |
| Registro por rol con validadores | Hecho | `lib/controllers/auth/validators/auth_validators.dart`, `lib/views/register/` |
| Estados de cuenta (`pending`, `rejected`, `disabled`) | Hecho | `lib/service/auth/firebase_auth_service.dart:359-373` |
| Perfil en SQLite | Hecho, pero se guarda al iniciar sesión, no al registrarse (el registro cierra la sesión) | `lib/database/repository/auth/auth_user_profile_repository.dart` |
| Recuperación con enfriamiento de 60 s | Hecho | `LoginController.requestPasswordReset` |
| Eliminación de cuenta | Solo con contraseña | `firebase_auth_service.dart:262-273` (`EmailAuthProvider.credential`) |
| Botones sociales | Deshabilitados con "Próximamente" | `lib/widgets/auth/coming_soon_social_buttons.dart:26` |
| `loginWithGoogle` | Lanza `invalidConfiguration` | `firebase_auth_service.dart:90` |
| Rutas protegidas | Solo las 4 de admin (`AdminRouteGuard`) | `lib/routes/routes.dart:269-285` |
| "Recordar mi correo" | **No existe** en el controller (el frontend no lo pintó) | `lib/controllers/auth/login_controller.dart` |

### 1.5 Configuración de la app

- `applicationId` y `namespace` son `com.example.machuco`
  (`android/app/build.gradle.kts:13,24`). Google Play no acepta
  `com.example.*`.
- `minSdk`, `targetSdk` y `compileSdk` vienen de `flutter.*` (Flutter
  3.44.8). No hay flavors (`dev`/`prod`). El release se firma con la llave de
  debug.
- `lib/firebase_options.dart`: Android e iOS del proyecto `machuco` (también
  macOS y Windows); `iosBundleId` es `com.example.machuco`. **No existe**
  `ios/Runner/GoogleService-Info.plist` y `Info.plist` no tiene
  `CFBundleURLSchemes`. iOS mínimo: 13.0.
- Dependencias: `firebase_core ^5.1.0`, `firebase_auth ^7.0.1` y
  `cloud_firestore ^7.1.0`. **No** están `google_sign_in` ni ningún paquete
  de OAuth.

## 2. Riesgos

| # | Riesgo | Impacto | Mitigación |
| --- | --- | --- | --- |
| R1 | **Un usuario de Auth sin `users/{uid}` entra como cliente activo** (`firebase_auth_service.dart:324`: "Usuario sin perfil… se usa rol cliente") | Con proveedores sociales, todo usuario nuevo tendría acceso de cliente sin completar perfil, términos ni mayoría de edad | Etapa 1: devolver `incompleteProfile` en lugar de sesión |
| R2 | **Admin sin `accountStatus`**: la app lo trata como `active` (`?? AccountStatus.active`), pero las reglas lo rechazan al aprobar | La interfaz deja entrar y la operación falla con `permission-denied` | Tarea manual 1; en la Etapa 1, tratar `null` en admin como estado inválido con mensaje claro |
| R3 | **GitHub con correo privado**: `token.email` llega `null` | La regla `email == request.auth.token.email` rechaza la creación del perfil y el usuario queda sin poder completar | Pedir el alcance `user:email`; si sigue sin correo verificado, no crear la cuenta e informar (decisión D5) |
| R4 | **Google desplaza la contraseña**: si una cuenta de correo y contraseña **no verificada** entra con Google y el mismo correo, Firebase (Google es proveedor de confianza) reemplaza la credencial y la contraseña deja de servir | El usuario pierde su método original sin enterarse | Decisión D4 (verificar el correo antes) y aviso en la UI |
| R5 | **Mismo correo en GitHub y en otro método**: `account-exists-with-different-credential` | Error confuso o cuenta duplicada si se cambia a "varias cuentas por correo" | Mantener "una cuenta por correo" y vincular tras iniciar sesión con el método original |
| R6 | SHA-1/SHA-256 incompletos (debug de cada integrante, release y Play App Signing) | `DEVELOPER_ERROR` / `ApiException: 10` en Google | Tarea manual 3 |
| R7 | Cambiar `applicationId` después de registrar los SHA | Hay que crear otra app Android en Firebase y descargar otro `google-services.json` | Decisión D2 antes de configurar |
| R8 | `android/app/build.gradle.kts` roto en la copia de trabajo | Ningún `flutter run` de Android compila | Decisión D1 (descartar o corregir) |
| R9 | Eliminar cuenta social con contraseña | Imposible: no tiene contraseña | Etapa 4: reautenticar con el proveedor |
| R10 | Choque de la versión 13 de SQLite | La app falla al abrir tras el merge | Reservar la versión con el equipo |
| R11 | Rutas de cliente y propietario sin guard | Una sesión `incompleteProfile` o `pending` podría abrirlas con `pushNamed` | Etapa 5: guard genérico por rol y estado (lo pide la feature "rutas protegidas") |
| R12 | Reglas sin desplegar | El registro con campos nuevos y la lista de solicitudes fallan en producción | Tarea manual 2 |

## 3. Decisiones

### 3.1 Decisiones aprobadas (v1.0, 2026-11-04)

| # | Decisión aprobada | Estado | Diferencia respecto a la recomendación original |
| --- | --- | --- | --- |
| D1 | Descartar los cambios de `build.gradle.kts` y `gradle.properties`; una sola declaración de `google-services` | Implementada | `settings.gradle.kts` vuelve a 4.4.4, la versión de `HEAD`, que compila con AGP 9.0.1 |
| D2 | `applicationId` de producción `co.machuco.app` | Implementada | El `namespace` sigue siendo `com.example.machuco` (paquete del código Kotlin) |
| D3 | Un solo SHA-1 compartido y un solo `google-services.json` | Implementada | Se **reutiliza `android/debug.keystore`** en lugar de generar un keystore nuevo (decisión del responsable); usa los datos de acceso por defecto de Android y solo vale para desarrollo |
| D4 | `signInWithProvider`, sin dependencias nuevas | Solo configuración | `firebase_auth` 7.0.1 lo implementa en Android con `OAuthProvider` + `startActivityForSignInWithProvider` (flujo web). Que funcione con `google.com` debe confirmarse en un dispositivo en la Etapa 3; si falla, se propone `google_sign_in` antes de agregarlo |
| D5 | GitHub: bloquear si el correo no está verificado | Pendiente (Etapa 3) | — |
| D6 | (No se tomó una decisión explícita) | Sin decidir | Se mantiene la recomendación: el propietario puede registrarse con proveedor social y queda `pending_approval` |
| D7 | Google: exigir correo verificado | Pendiente (Etapa 3/4) | — |
| D8 | Flavors `dev` (`co.machuco.app.dev`) y `prod` (`co.machuco.app`) en el mismo proyecto `machuco` | Implementada | Se registraron dos apps Android nuevas en Firebase con autorización del responsable |
| D9 | Pruebas de reglas con Emulator Suite + Node | Implementada | `test_rules/` con `node:test`, `@firebase/rules-unit-testing` 6.0.0 y `firebase` 13.0.0 (33 pruebas) |
| D10 | Abandonar "Completar perfil" cierra la sesión y borra el usuario de Firebase sin perfil (cambio del 2026-11-08) | Pendiente (Etapa 2) | — |
| D11 | Registrar versión y fecha | v1.0 / 2026-11-04 registrados en este plan y en `docs/decisions_log.md` | Para la aceptación de términos (Etapa 2) se guardarán `termsVersion` y `termsAcceptedAt`; la versión del documento de términos todavía no existe y no se inventa |

### 3.2 Opciones evaluadas (texto original del plan)

| # | Decisión | Opciones | Recomendación |
| --- | --- | --- | --- |
| D1 | Qué hacer con los cambios de `android/` | (a) Descartarlos; (b) corregirlos en un commit propio | Descartar `build.gradle.kts` y `gradle.properties`, revisar `google-services.json` (D3) y mantener `google-services` 4.4.4 hasta que el equipo acuerde subirlo |
| D2 | `applicationId` definitivo | Mantener `com.example.machuco` (no publicable) o fijar uno real, p. ej. `co.machuco.app` | Fijarlo **antes** de registrar SHA y OAuth |
| D3 | `google-services.json` versionado | Uno compartido con los SHA de debug de todos, o uno por desarrollador sin versionar | Uno compartido; cada integrante registra su SHA-1 de debug |
| D4 | Paquete para Google | (a) `google_sign_in` (nativo, Credential Manager; **dependencia nueva**); (b) `FirebaseAuth.signInWithProvider(GoogleAuthProvider())` (sin dependencia, flujo en navegador) | (b) para empezar, sin dependencias; (a) solo con decisión documentada del equipo |
| D5 | GitHub sin correo verificado | Bloquear o pedir un correo manual | Bloquear: la regla exige `token.email` y un correo escrito a mano no está verificado |
| D6 | ¿El propietario se puede registrar con proveedor social? | Sí (queda `pending_approval`) / No | Sí, como dice el contexto |
| D7 | ¿Se exige el correo verificado a cuentas de correo y contraseña antes de permitir Google? | Sí / No | Sí, para evitar R4 |
| D8 | Flavors `dev`/`prod` | Un proyecto Firebase con dos apps o dos proyectos | Dos apps en el mismo proyecto `machuco` (sufijo `.dev`), si el equipo lo acepta |
| D9 | Pruebas de reglas | Emulador + `@firebase/rules-unit-testing` (Node, herramienta nueva) o solo pruebas manuales | Emulador, como herramienta de desarrollo fuera de `pubspec` |
| D10 | Abandono de "Completar perfil" | Cerrar sesión y conservar el usuario de Auth, o cerrar sesión y borrarlo | Cerrar sesión y borrar (cambio del 2026-11-08: no deben quedar cuentas a medias en Firebase). Solo se borra si se confirma que no hay perfil y no hay contraseña; si Firebase exige un inicio de sesión reciente o no hay red, solo se cierra la sesión y al volver a entrar se reanuda |
| D11 | Registro de la aceptación de términos | Booleano o versión del documento + fecha (`termsAcceptedAt`/`termsVersion`) | Versión + fecha; requiere ampliar `hasOnly` en las reglas |

## 4. Contrato `SocialAuthResult`

Resultado único para Google, GitHub y la restauración de la sesión. Lo emite
el servicio, lo traduce el controller y la vista solo navega. Es un boceto:
no está implementado.

```dart
sealed class SocialAuthResult {
  const SocialAuthResult();
}

/// Perfil completo y cuenta activa: navegar a la ruta del rol.
final class SocialAuthActive extends SocialAuthResult {
  const SocialAuthActive(this.session);
  final AuthSession session;
}

/// Usuario autenticado en Firebase sin `users/{uid}` (o con campos
/// obligatorios faltantes): navegar a "Completar perfil".
final class SocialAuthIncompleteProfile extends SocialAuthResult {
  const SocialAuthIncompleteProfile({
    required this.uid,
    required this.email,          // null si GitHub no lo entregó
    required this.emailVerified,
    required this.provider,       // AuthProviderKind.google | github
    this.displayName,             // para precargar nombres y apellidos
  });
  final String uid;
  final String? email;
  final bool emailVerified;
  final AuthProviderKind provider;
  final String? displayName;
}

/// Propietario con `pending_approval`: sesión válida, ruta "Cuenta en revisión".
final class SocialAuthPending extends SocialAuthResult {
  const SocialAuthPending(this.session);
  final AuthSession session;
}

/// Propietario rechazado: sin sesión; mostrar el motivo.
final class SocialAuthRejected extends SocialAuthResult {
  const SocialAuthRejected({this.reason});
  final String? reason;
}

/// Cuenta deshabilitada (en Firestore o en Firebase Auth): sin sesión.
final class SocialAuthDisabled extends SocialAuthResult {
  const SocialAuthDisabled();
}

/// El usuario cerró el flujo del proveedor: permanecer en el login sin error.
final class SocialAuthCancelled extends SocialAuthResult {
  const SocialAuthCancelled();
}

/// Cualquier otro caso: red, configuración, correo existente con otro
/// método, correo de GitHub ausente, falla de Firestore. Mensaje en español.
final class SocialAuthError extends SocialAuthResult {
  const SocialAuthError(this.failure);
  final AuthFailure failure; // tipos nuevos: accountExistsWithDifferentCredential,
                             // emailUnavailable, providerMisconfigured
}
```

| Excepción o estado de origen | Resultado |
| --- | --- |
| Perfil completo + `active` | `SocialAuthActive` |
| Sin `users/{uid}` o con campos obligatorios faltantes | `SocialAuthIncompleteProfile` |
| `pending_approval` | `SocialAuthPending` |
| `rejected` | `SocialAuthRejected(reason)` |
| `disabled` o `user-disabled` | `SocialAuthDisabled` |
| `web-context-canceled`, `canceled` o cierre del navegador | `SocialAuthCancelled` |
| `network-request-failed` | `SocialAuthError(network)` |
| `account-exists-with-different-credential` | `SocialAuthError(accountExistsWithDifferentCredential)` con los métodos del correo |
| `operation-not-allowed`, `invalid-credential` por configuración, `DEVELOPER_ERROR` | `SocialAuthError(providerMisconfigured)` |
| GitHub sin correo verificado | `SocialAuthError(emailUnavailable)` |
| Admin con `accountStatus` nulo | `SocialAuthError(invalidConfiguration)` con el mensaje "Tu cuenta de administrador no está activa; contacta a otro administrador" |

`restoreSession()` debe devolver el mismo tipo: así un cierre durante
"Completar perfil" se reanuda en el siguiente arranque.

## 5. Propuesta: "Completar perfil"

- **Ruta**: `AuthRoutes.completeProfile = '/auth/complete-profile'`, con
  argumentos `SocialAuthIncompleteProfile`. Solo se llega con una sesión de
  Firebase activa y sin perfil completo; cualquier otra ruta protegida
  redirige aquí mientras el perfil esté incompleto.
- **Rol**: selector Cliente / Propietario (nunca Administrador). El rol se
  elige aquí, no antes del botón social, porque el usuario puede tocar
  "Continuar con Google" desde el login.
- **Campos obligatorios** (los mismos validadores del registro con correo):
  - comunes: nombres y apellidos (precargados desde `displayName`,
    editables), indicativo y celular;
  - Cliente: fecha de nacimiento (18 años o más);
  - Propietario: tipo de persona, NIT con DV, razón social si es jurídica y
    plan;
  - **sin contraseña**: el proveedor es la credencial;
  - **correo**: solo lectura, el del proveedor; no se puede editar.
- **Términos y condiciones**: el mismo `showTermsSheet`. Si se acepta D11,
  casilla obligatoria y se guardan `termsVersion` y `termsAcceptedAt`.
- **Propietario**: al guardar queda `pending_approval` y navega a "Cuenta en
  revisión", igual que el registro con correo. El administrador lo ve en
  "Solicitudes de propietarios" sin cambios.
- **GitHub con correo privado**: no se llega a esta pantalla. El servicio
  devuelve `SocialAuthError(emailUnavailable)` con el mensaje "Tu cuenta de
  GitHub no comparte un correo verificado. Hazlo público o verificado en
  GitHub, o regístrate con correo y contraseña", y cierra la sesión.
- **Salir sin terminar**: el botón "Cancelar" (y "atrás") cierra la sesión y
  borra el usuario de Firebase sin perfil (D10). Si se cierra la app, el usuario
  sigue en Firebase hasta terminar o cancelar: al abrirla `restoreSession` devuelve `incompleteProfile` y
  vuelve a esta pantalla con los datos del proveedor (lo escrito se pierde;
  no se guardan borradores con datos personales).
- **Errores**: si falla `users/{uid}`, se queda en la pantalla con los datos
  y "Reintentar". Si falla SQLite, no se bloquea: el perfil se guarda en el
  siguiente arranque.
- **Escritura**: `users/{uid}` con las reglas actuales (`fullName` se arma
  con nombres y apellidos, `email` es el del token, `createdAt` es
  `serverTimestamp`). No hace falta cambiar `create` salvo por D11.

## 6. Etapas y archivos permitidos

Cada etapa es un PR o commit propio, con sus pruebas, y no toca archivos de
otras etapas. **Nada de esto se ejecuta sin aprobación.**

| Etapa | Objetivo | Archivos permitidos |
| --- | --- | --- |
| 0 | Decisiones D1-D11 y tareas manuales 1-4 | Ninguno de código. Solo `docs/decisions_log.md` |
| 1 | Contrato y corrección de R1/R2 (sin proveedores todavía) | `lib/models/auth/social_auth_result.dart` (nuevo), `lib/models/auth/auth_provider_kind.dart` (nuevo), `lib/service/auth/auth_service.dart`, `lib/service/auth/firebase_auth_service.dart`, `lib/controllers/auth/login_controller.dart`, `test/service/auth/`, `test/controllers/auth/` |
| 2 | "Completar perfil" | `lib/views/register/complete_profile_page.dart` (nuevo), reutilizar `lib/views/register/*` sin cambiar su comportamiento, `lib/controllers/auth/auth_routes.dart`, `lib/routes/routes.dart` (solo agregar la ruta), `lib/models/auth/registration_data.dart` (constructor sin contraseña), `test/views/auth/` |
| 3 | Google y GitHub en Android | `lib/service/auth/firebase_auth_service.dart`, `lib/widgets/auth/coming_soon_social_buttons.dart` (pasa a `social_auth_buttons.dart`), `lib/widgets/auth/login_form.dart`, `lib/views/register/register_form.dart`, pruebas. Con D4 (a): además `pubspec.yaml`/`pubspec.lock` |
| 4 | Eliminación y recuperación para cuentas sociales; vinculación de proveedores | `lib/service/auth/firebase_auth_service.dart`, `lib/controllers/auth/login_controller.dart`, `lib/widgets/auth/delete_account_sheet.dart`, `lib/widgets/auth/forgot_password_sheet.dart`, pruebas |
| 5 | Guard genérico por rol y estado | `lib/views/admin_access/admin_route_guard.dart` (pasa a un guard común en `lib/views/login/`), `lib/routes/routes.dart` (solo envolver rutas), pruebas |
| 6 | Reglas y emulador (si D9) | `firestore.rules` (solo el bloque `users`), `firebase.json` (bloque `emulators`), `test_rules/` (nuevo, Node) |
| 7 ✅ (2026-11-04) | Android: `applicationId`, flavors y firma (si D1, D2 y D8) | `android/app/build.gradle.kts`, `android/settings.gradle.kts`, `android/app/google-services.json`, `lib/firebase_options*.dart`. **Requiere permiso explícito**: hoy `android/` está vetado |
| 8 | QA en dispositivo y documentación | `docs/auth/`, `docs/modules/auth.md`, `contexts/people/feature-juan_pablo.feature.md` |

## 7. Tareas manuales, en orden

1. **Revisar los administradores** (consola de Firebase → Firestore →
   `users`): cada documento con `role: admin` debe tener
   `accountStatus: 'active'`. Sin ese campo, la app lo deja entrar, pero las
   reglas rechazan aprobar, rechazar y deshabilitar.
2. ✅ **Hecho (2026-11-04).** **Decidir los cambios de `android/`** (D1): mientras
   `android/app/build.gradle.kts` siga así, Android no compila.
3. ✅ **Hecho (2026-11-04)**: reglas publicadas e índice creado. Falta
   confirmar en la consola que el índice está "Habilitado".
   **Desplegar las reglas y el índice**:
   `firebase deploy --only firestore:rules,firestore:indexes --project machuco`.
   Esperar a que el índice pase a "Habilitado" y probar el registro con
   correo y la lista de solicitudes.
4. **Configurar Firebase**:
   1. Authentication → Método de acceso: habilitar **Google**. Para
      **GitHub**, crear una OAuth App en GitHub con el callback
      `https://machuco.firebaseapp.com/__/auth/handler` y pegar su Client ID
      y Client Secret en Firebase. El secreto no va al repo.
   2. Configuración → Usuarios y cuentas: dejar "Vincular cuentas con el
      mismo correo" (una cuenta por correo) y activar la protección contra
      enumeración de correos.
   3. Configuración del proyecto → App Android: registrar el SHA-1 y el
      SHA-256 de debug de cada integrante. Cada uno los obtiene en su equipo
      con `keytool -list -v` sobre su keystore de debug, sin compartir el
      archivo. Agregar también los de release y los de Play App Signing
      cuando existan.
   4. Descargar el `google-services.json` actualizado (D3) y revisar el
      `applicationId` (D2) antes de hacerlo.
   5. Plantillas de correo en español (restablecimiento) y política de
      contraseñas igual a la de la app.
5. **Probar en un dispositivo Android real** (no emulador sin Play
   Services) cada escenario de
   [`escenarios-auth-social.feature`](escenarios-auth-social.feature)
   marcado `@manual`, con un usuario de cada rol.
6. **iOS** (cuando se aborde): agregar `GoogleService-Info.plist` y el URL
   scheme `REVERSED_CLIENT_ID` en `Info.plist`, y compilar en macOS.

## 8. Fuera de alcance

- Creación de administradores desde la app (requiere Cloud Functions).
- Otros proveedores (Apple, Facebook, Microsoft, teléfono/SMS).
- Implementación y pruebas en iOS más allá de que compile.
- Verificación de correo obligatoria para todas las cuentas (solo D7).
- Comprobar "último administrador" y reservas activas al eliminar una cuenta.
- Borrado en cascada de subcolecciones (`users/{uid}/subscriptions`).
- Ampliar `subscription_plans` o `phone_country_codes` en Supabase.
- Corregir `AppButton` (lo hace la rama del design system, ver handoff).
- "Recordar mi correo" (pendiente de la tarea anterior; se planifica
  aparte).
