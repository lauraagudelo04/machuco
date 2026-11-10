# Firebase en MACHUCO: guía para las ramas

Guía corta para integrar una funcionalidad con Firebase Authentication y
Cloud Firestore. La decisión y su historial están en
[decisions_log.md](decisions_log.md); el detalle del módulo de
autenticación, en [modules/auth.md](modules/auth.md). Las reglas generales de
seguridad están en
[GUIA_MACHUCO.md](../GUIA_MACHUCO.md) y no se repiten aquí.

Firebase se inicializa en `lib/main.dart` (`Firebase.initializeApp` con
`lib/firebase_options.dart`); ninguna rama debe volver a inicializarlo.

## 1. Usuario autenticado

```dart
import 'package:machuco/service/firebase/current_user.dart';

final uid = CurrentUser.uid;            // null si no hay sesión
if (!CurrentUser.isSignedIn) { /* ... */ }
```

- Usa `CurrentUser.uid` para asociar o filtrar tus documentos
  (p. ej. `ownerId`, `clientId`).
- Para **mostrar** o precargar el correo sin depender de Firebase:
  `await AuthPreferences().loadCurrentUserEmail()`
  (`lib/service/auth/auth_preferences.dart`).
- Nada de esto **autoriza**. Ocultar un botón según el rol no es seguridad:
  la autorización real vive en `firestore.rules`, que se evalúa en el
  servidor con `request.auth` y el documento `users/{uid}` (campo `role`:
  `client`, `owner` o `admin`; campo `accountStatus`).

## 2. Agregar una colección nueva

Ejemplo con una colección hipotética `reservations`; sigue el patrón de
`lib/database/repository/auth/user_profile_repository.dart`.

1. **Nombre de la colección** en
   `lib/service/firebase/firestore_collections.dart`:

   ```dart
   static const reservations = 'reservations';
   ```

2. **Modelo** en `lib/models/<feature>/` con `fromFirestore`/`toFirestore`
   (ver `UserProfile` en `lib/models/auth/user_profile.dart`): tolera campos
   faltantes y usa `FieldValue.serverTimestamp()` para fechas de creación.

3. **Repositorio** en `lib/database/repository/<feature>/`: una interfaz y
   una implementación Firestore que traduce `FirebaseException` a una
   excepción propia con mensaje en español.

   ```dart
   abstract interface class ReservationRepository {
     Future<List<Reservation>> listForClient(String clientId);
   }

   class FirestoreReservationRepository implements ReservationRepository {
     FirestoreReservationRepository({FirebaseFirestore? firestore})
       : _firestore = firestore ?? FirebaseFirestore.instance;
     final FirebaseFirestore _firestore;
     // _firestore.collection(FirestoreCollections.reservations)...
   }
   ```

4. **Controller** que recibe la interfaz del repositorio por constructor.
   La vista **nunca** importa `cloud_firestore` ni llama al repositorio.

5. **Regla** en `firestore.rules`, dentro de `match /databases/{database}/documents`
   y **antes** del bloque final `match /{document=**}` (que lo deniega
   todo). Puedes reutilizar `isSignedIn()` e `isAdmin()`. Ejemplo por rol:

   ```text
   function userRole() {
     return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
   }

   match /reservations/{reservationId} {
     allow read: if isSignedIn() && (
       resource.data.clientId == request.auth.uid || isAdmin());
     allow create: if isSignedIn()
       && userRole() == 'client'
       && request.resource.data.clientId == request.auth.uid;
     allow update, delete: if isAdmin();
   }
   ```

   Si la colección expone datos de un propietario, valida además que su
   `accountStatus` sea `active`. Restringe los campos escribibles con
   `keys().hasOnly([...])` en `create` y
   `diff(resource.data).affectedKeys().hasOnly([...])` en `update`, como en
   `users/{uid}`.

## 3. Probar sin red

- Escribe un fake que implemente la **interfaz** del repositorio (ver
  `_FakeUserProfileRepository` en
  `test/repositories/auth/user_profile_test.dart`) e inyéctalo en el
  controller.
- Prueba `fromFirestore`/`toFirestore` con mapas simples.
- No agregues `fake_cloud_firestore`, el emulador u otras dependencias de
  prueba sin una decisión del equipo registrada en
  [decisions_log.md](decisions_log.md).

## 4. Despliegue y consola

Requisitos (una sola vez por proyecto Firebase):

- Crear la base de datos **Cloud Firestore** en la consola.
- Habilitar **Correo electrónico/contraseña** en
  `Authentication > Sign-in method`.
- Crear los administradores manualmente: cuenta en Authentication y
  documento `users/{uid}` con `role: admin` y `accountStatus: active`.

Cada vez que cambie `firestore.rules` (referenciado en `firebase.json`):

```bash
firebase deploy --only firestore:rules
```

### Archivos de configuración en el repositorio

`lib/firebase_options.dart`, `android/app/google-services.json` y
`firebase.json` se versionan **a propósito**: solo contienen identificadores
del proyecto y API keys de cliente, que Firebase no trata como secretos (la
app las necesita para conectarse). La protección real de los datos son las
reglas de `firestore.rules`. Para limitar abusos, restringe las API keys en
Google Cloud Console (`APIs y servicios > Credenciales`) por aplicación
(nombre de paquete y SHA-1 en Android, bundle ID en iOS) y por API. Nunca
subas credenciales de cuenta de servicio (`private_key`, archivos de
Admin SDK).

Estado al 2026-10-28: la base de datos Cloud Firestore `(default)` existe
(modo nativo, ubicación `nam5`) y las reglas de `firestore.rules` se
desplegaron el 2026-10-27. `.firebaserc` fija `machuco` como proyecto por
defecto del CLI. Cada cambio en `firestore.rules` debe volver a
desplegarse; coordina el despliegue con el equipo, porque el archivo de
reglas es único y compartido por todas las ramas y desplegar reemplaza todas
las reglas publicadas.

## 5. Analytics (Firebase Analytics)

La app reporta el uso con `firebase_analytics` a través de un único servicio,
`lib/service/analytics/analytics_service.dart`. Ninguna vista llama a
Firebase directamente: los controllers y servicios usan
`AnalyticsServiceProvider.instance` (o reciben un `AnalyticsService` en el
constructor). `main` activa Firebase con
`AnalyticsServiceProvider.useFirebase()`; en las pruebas queda el
`NoopAnalyticsService`, que descarta todo.

Qué se reporta hoy:

| Evento | Dónde | Parámetros |
| --- | --- | --- |
| `screen_view` | `AnalyticsRouteObserver` en `MaterialApp` (cada ruta con nombre; el `home` se llama `login`) | `screen_name` |
| `login` | `LoginController.login` (correo), `FirebaseSocialAuthService` (Google, GitHub) | `method`: `password`, `google`, `github` |
| `sign_up` | `LoginController.registerAccount`, `FirebaseSocialAuthService.completeProfile` | `method` |
| `reservation_created` | `BookingService.createReservation` (no en reintentos del mismo `requestId`) | `motel_id`, `stay_mode`, `guest_count`, `value`, `currency` |
| `reservation_paid` | `BookingService.confirmPayment` y `registerCashPayment` de una reserva pendiente | `payment_method`, `value`, `currency` |
| `reservation_cancelled` | `BookingService.cancelReservation` | `previous_status` |

Además se asocia el uid de Firebase (`setUserId`) y la propiedad de usuario
`user_role` (`client`, `owner`, `admin`) al iniciar o restaurar la sesión, y
se limpian al cerrar sesión.

Para agregar un evento de tu módulo:

1. Declara el nombre en `AnalyticsEvents` (snake_case, máximo 40
   caracteres).
2. Repórtalo desde el controller o servicio, después de que la operación
   tuvo éxito: `unawaited(analytics.logEvent(AnalyticsEvents.x, {...}))`.
   Los valores son `String` o números. **Nunca** envíes nombres, correos,
   celulares, NIT ni otro dato personal.
3. Pruébalo inyectando `RecordingAnalyticsService`
   (`test/service/analytics/recording_analytics_service.dart`).

Ver los datos:

- **En vivo (DebugView):** con el emulador encendido,
  `adb shell setprop debug.firebase.analytics.app co.machuco.app.dev` y abre
  `Analytics > DebugView` en la consola. Para apagarlo:
  `adb shell setprop debug.firebase.analytics.app .none.`
- **Informes:** `Analytics > Dashboard`, `Events` y `Realtime` tardan de
  minutos a 24 horas en reflejar los eventos. La propiedad `user_role` se
  registra como dimensión personalizada (ámbito usuario) en
  `Analytics > Custom definitions` para poder filtrar por rol.
