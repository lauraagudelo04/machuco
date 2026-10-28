# Módulo: Autenticación

Estado general: **parcial**. El registro, login, recuperación de contraseña
y restauración de sesión contra Firebase Authentication (correo y
contraseña) están implementados, con el perfil, el rol y el estado de la
cuenta guardados en Cloud Firestore y protegidos por `firestore.rules`. Las
reglas aún no están desplegadas, faltan la pantalla "Cuenta en revisión", la
aprobación de propietarios y los proveedores externos; el modo de usuarios
de prueba es provisional. Guía de uso de Firebase para otras ramas en
[../firebase.md](../firebase.md).

## Modelos (`lib/models/auth/`)

- `registered_user.dart`
  - `RegisteredUserRole` (`admin`, `client`, `owner`): ver perfiles en
    [README.md#perfiles](../../README.md#perfiles).
  - `RegisteredUser`: usuario del directorio de usuarios, con
    `fromJson`/`toJson` pensados para un API HTTP.
- `user_profile.dart` — `UserProfile`: perfil en Firestore
  (`fromFirestore`/`toFirestore`). Un rol faltante o desconocido se lee como
  `client`; un estado faltante o desconocido se lee como `null` (y bloquea el
  ingreso). `createdAt` lo asigna el servidor.
- `account_status.dart` — `AccountStatus` (`active`, `pending_approval`,
  `rejected`, `disabled`) y funciones puras `isPublicRegistrationRole` (solo
  `client`/`owner`) e `initialAccountStatusFor` (propietario →
  `pending_approval`, cliente → `active`), espejo de `firestore.rules`.
- `country_phone_code.dart` — `CountryPhoneCode`: maestro de indicativos
  (Supabase REST, caché SQLite, semilla Colombia +57 si no hay Supabase ni
  caché).

### Esquema `users/{uid}` (Cloud Firestore)

| Campo | Contenido |
|---|---|
| `fullName` | Nombre completo |
| `email` | Correo en minúsculas (debe coincidir con el del token) |
| `phoneNumber` | Celular con indicativo |
| `role` | `client` \| `owner` \| `admin` |
| `accountStatus` | `active` \| `pending_approval` \| `rejected` \| `disabled` |
| `createdAt` | `serverTimestamp()` |

No se guarda documento de identidad. El NIT y tipo de persona del
propietario descritos en el contexto de la rama todavía no están en el
esquema.

## Servicios y repositorios

- `AuthService` (`lib/service/auth/auth_service.dart`, con `AuthSession` y
  `AuthFailure`): **transitorio**. Existe solo mientras conviven Firebase y
  el login quemado; no se amplía y se retira con este.
- `FirebaseAuthService`: implementación real (`firebase_auth`). La sesión la
  persiste el SDK.
  - **Registro:** rechaza `admin` en el cliente (mensaje claro; la regla real
    está en `firestore.rules`) → crea la cuenta en Auth → guarda
    `users/{uid}` con el estado inicial por rol → cierra sesión para que el
    usuario ingrese de forma explícita. Si el perfil no se puede guardar,
    elimina la cuenta recién creada (o, si no puede, cierra sesión).
  - **Login / `restoreSession`:** el rol y el estado se leen de Firestore (ya
    **no** del custom claim `role`). `disabled`, `rejected`,
    `pending_approval` o estado desconocido cierran sesión y muestran un
    mensaje. Sin documento de perfil se asume `client` activo (mínimo
    privilegio). Los errores de red **no** cierran la sesión, para poder
    reintentar.
  - **Recuperación de contraseña:** `user-not-found` se trata como éxito
    para no revelar si el correo existe.
  - **Login con Google:** responde "aún no disponible".
- `UserProfileRepository` (interfaz) y `FirestoreUserProfileRepository`
  (`lib/database/repository/auth/user_profile_repository.dart`):
  `createProfile` y `getProfile`. Traduce errores de Firebase a
  `UserProfileRepositoryException` (`permissionDenied`, `network`,
  `unknown`) con mensajes en español.
- `AuthCatalogRepository` + `AuthCatalogDao`
  (`lib/database/repository/auth/`): indicativos telefónicos desde Supabase
  con caché en SQLite.
- `AuthPreferences` (`auth_preferences.dart`): correo del usuario actual,
  último indicativo y fecha de sincronización de maestros en
  `shared_preferences` (namespace `auth`). Solo para mostrar o precargar,
  nunca para autorizar.
- `CurrentUser` (`lib/service/firebase/current_user.dart`): uid/correo de la
  sesión de Firebase para otras ramas. Identifica, no autoriza.
- `HardcodedAuthService`: **placeholder de pruebas.** Cuentas fijas en el
  código, solo con `AUTH_USE_HARDCODED_AUTH_USERS=true` (apagado por
  defecto). No soporta registro, Google ni recuperación de contraseña. Ver
  hallazgo de seguridad en [../decisions_log.md](../decisions_log.md).
- `AuthConfig`: flags de `--dart-define` (usuarios de prueba y API de
  usuarios), documentados en
  [README.md#configuración-de-la-autenticación](../../README.md#configuración-de-la-autenticación).
  Firebase se configura con `lib/firebase_options.dart`.

### Directorio de usuarios

- `RegisteredUserDirectory` (interfaz), `InMemoryRegisteredUserDirectory`
  (**datos de ejemplo**, implementación por defecto) y
  `BackendRegisteredUserDirectory` (**parcial/opcional**, API HTTP externo
  con `AUTH_USE_BACKEND_USERS=true` y `AUTH_USERS_API_BASE_URL`; su
  `upsertUser` es un no-op intencional). Es independiente de `users/{uid}`
  en Firestore.

## Reglas de seguridad (`firestore.rules`)

Referenciadas en `firebase.json`. Para `users/{uid}`:

- **read:** el propio usuario o un admin (`users/{auth.uid}.role == 'admin'`).
- **create:** solo el propio uid; `keys().hasOnly` sobre los seis campos del
  esquema; `fullName` (3 a 100 caracteres) y `phoneNumber` (4 a 20) como
  texto (`hasValidContactFields`); `email` igual al del token; rol `client`
  (con `active`) u `owner` (con `pending_approval`);
  `createdAt == request.time`.
- **update:** un admin cambiando solo `accountStatus` a un valor válido
  (nunca el rol, ni el suyo), o el propio usuario cambiando solo `fullName`
  y `phoneNumber` con los mismos límites (`affectedKeys().hasOnly`).
- **delete:** denegado.
- Cualquier otra ruta: denegada por defecto.

## Controllers y vistas

- `lib/controllers/auth/login_controller.dart` (`ChangeNotifier`) coordina
  login/registro con el `AuthService` activo, guarda el correo en
  `AuthPreferences` y carga los indicativos.
- `lib/views/login/login_page.dart` elige la implementación (Firebase o
  quemada), el directorio de usuarios y el repositorio de maestros, y se los
  pasa al controller. `lib/views/register/` contiene el registro.

## Qué falta o es provisional

- **Reglas no desplegadas:** falta crear la base de datos Firestore en la
  consola y ejecutar `firebase deploy --only firestore:rules`. Sin eso, el
  registro falla al guardar el perfil (y revierte la cuenta).
- Habilitar el proveedor Correo/contraseña en Firebase Authentication.
- Pantalla "Cuenta en revisión": hoy el propietario pendiente solo ve un
  mensaje en el login (`TODO(auth)` en `FirebaseAuthService`).
- Administradores: se crean manualmente en la consola (cuenta en Auth +
  documento con `role: admin`); no hay flujo en la app.
- Aprobación/rechazo de propietarios por el admin: no implementada (las
  reglas ya permiten el `update` del admin).
- Ingreso con Google/GitHub: definido, no implementado.
- **Compromiso aceptado:** el registro muestra "Este correo ya está
  registrado" (`email-already-in-use`), lo que permite enumerar correos. Se
  acepta por usabilidad; login y recuperación de contraseña sí usan mensajes
  genéricos.
- `HardcodedAuthService` no debe activarse fuera de desarrollo/QA local.
- `BackendRegisteredUserDirectory` es de solo lectura en la práctica y su
  API no tiene contrato documentado.
- Pruebas: `test/widget_test.dart`, `test/controllers/auth/` y
  `test/repositories/auth/`, con servicios falsos. No hay pruebas de
  `FirebaseAuthService` ni de las reglas (emulador).
