# Verificación del celular por SMS (Firebase Authentication)

Al crear una cuenta nueva, la app comprueba que el usuario es dueño del
número de celular que escribió: Firebase envía un código de 6 dígitos por SMS
y la cuenta solo se crea si el código es correcto. Aplica a los dos caminos
de registro:

| Camino | Pantalla | Qué pasa con el celular |
| --- | --- | --- |
| Correo y contraseña | Login → pestaña "Registrarse" | Se verifica antes de crear la cuenta. |
| Google o GitHub (primer ingreso) | "Completar perfil" | Se verifica antes de crear el perfil. |

No cambia el inicio de sesión: el usuario sigue entrando con correo y
contraseña, Google o GitHub. El SMS se pide **solo al registrarse**.

> Estado: implementado y probado con servicios falsos (1092 pruebas en
> verde). **No se ha probado con un SMS real**: faltan los pasos de la
> sección [Configuración pendiente](#6-configuración-pendiente-en-firebase).

---

## 1. Cómo funciona

### Registro con correo y contraseña

```text
Usuario              App (LoginPage)            Firebase Auth            Firestore
  │  llena el form      │                           │                       │
  │  "Crear cuenta" ───▶│ valida todo el formulario │                       │
  │                     │ (si algo falla, no manda  │                       │
  │                     │  SMS)                     │                       │
  │                     │── verifyPhoneNumber ─────▶│ envía SMS             │
  │◀──── SMS con código ┼───────────────────────────│                       │
  │  escribe el código ▶│ (hoja "Verifica tu celular")                      │
  │                     │── createUserWithEmailAndPassword ───▶│            │
  │                     │── linkWithCredential(SMS) ──────────▶│ comprueba  │
  │                     │                           │  el código            │
  │                     │── createProfile(users/{uid}) ─────────────────────▶│
  │                     │── signOut                 │                       │
  │◀ "Cuenta creada" ───│                           │                       │
```

1. `RegisterForm` valida el formulario y entrega un `RegistrationData`.
2. `LoginPage` pide al controller el celular en formato E.164
   (`LoginController.phoneNumberToVerify`, p. ej. `+573001234567`). Esa
   llamada vuelve a validar el formulario, así que **un dato inválido nunca
   cuesta un SMS**.
3. Se abre la hoja `PhoneVerificationSheet`, que pide el SMS al abrirse.
4. Con el código escrito, la hoja llama a `LoginController.registerAccount`
   con un `RegistrationData` que ya lleva la prueba (`phoneProof`).
5. `FirebaseAuthService.registerAccount` crea el usuario, **vincula el
   celular** con `linkWithCredential` (aquí Firebase comprueba el código) y
   recién entonces guarda el perfil en `users/{uid}`.

### Google y GitHub ("Completar perfil")

Igual, pero el usuario de Firebase ya existe (entró con el proveedor), así que
no se crea nada: `FirebaseSocialAuthService.completeProfile` vincula el
celular a ese usuario y luego crea el perfil.

### Qué ve el usuario en la hoja

- "Enviando el código…" mientras Firebase responde.
- Campo de 6 dígitos (solo números, con autocompletado del SMS).
- **Verificar y crear cuenta** (o "Verificar y guardar" en Completar perfil).
- **Reenviar código**, bloqueado 60 s después de cada envío.
- **Cancelar**: cierra la hoja; no se crea nada y el formulario conserva los
  datos.
- Un código incorrecto o vencido se muestra dentro de la hoja y se puede
  reintentar sin volver a llenar el formulario.
- La hoja no se cierra arrastrando ni tocando fuera: así el resultado de la
  creación de la cuenta nunca queda sin atender.

---

## 2. Decisiones de diseño

| Decisión | Motivo |
| --- | --- |
| **Vincular el celular al usuario** (`linkWithCredential`) en vez de guardar un campo "verificado" | La verificación queda dentro de Firebase Auth (`user.phoneNumber` y proveedor `phone`) y no se puede escribir desde la app. No cambia el esquema de Firestore ni `firestore.rules`. |
| **Crear primero el usuario y vincular después** (y no iniciar sesión con el celular primero) | Si el número ya existe en otra cuenta, iniciar sesión con él entraría a esa cuenta. Vincular falla con `credential-already-in-use`, que es justo la unicidad que se busca. |
| **Si vincular falla, se borra la cuenta recién creada** | Mismo criterio que ya existía cuando falla el perfil (`_rollbackAccount`): no quedan cuentas a medias. En Completar perfil el usuario no se borra; puede reintentar con otro código. |
| **La prueba viaja dentro de `RegistrationData` / `SocialProfileData`** (`phoneProof`) | `AuthService.registerAccount` y `SocialAuthService.completeProfile` conservan su firma; las vistas no tocan Firebase. |
| **`PhoneVerificationProof` es opaca** (interfaz en `models/`) | Las vistas y el controller no importan `firebase_auth`; solo `FirebasePhoneVerificationProof` conoce la credencial. |
| **Se compara el número verificado con el del formulario** | Evita verificar un número y registrar otro. |
| **Sin dependencias nuevas** | `firebase_auth` ya trae `verifyPhoneNumber`; la hoja usa los componentes del design system. |

---

## 3. Archivos

| Archivo | Rol |
| --- | --- |
| `lib/models/auth/phone_verification.dart` | `PhoneVerificationProof` (opaca) y `PhoneCodeRequest` (SMS pedido). |
| `lib/service/auth/phone_verification_service.dart` | Contrato `PhoneVerificationService`, implementación Firebase, `requireVerifiedPhoneProof`, `linkVerifiedPhone` y la traducción de errores (`phoneAuthFailureFor`). |
| `lib/service/auth/firebase_auth_service.dart` | `registerAccount` exige la prueba, vincula el celular y revierte la cuenta si falla. |
| `lib/service/auth/firebase_social_auth_service.dart` | `completeProfile` hace lo mismo para Google/GitHub. |
| `lib/service/auth/auth_service.dart` | 4 nuevos `AuthFailureType`: `invalidVerificationCode`, `verificationExpired`, `phoneAlreadyInUse`, `phoneNotVerified`. |
| `lib/models/auth/registration_data.dart`, `social_profile_data.dart` | Campo opcional `phoneProof`. |
| `lib/controllers/auth/login_controller.dart` | `phoneVerificationService` (inyectable) y `phoneNumberToVerify`. |
| `lib/controllers/auth/validators/auth_validators.dart` | `smsCode` (6 dígitos). |
| `lib/widgets/auth/phone_verification_sheet.dart` | Hoja "Verifica tu celular". |
| `lib/widgets/form/app_bottom_sheet.dart` | Nuevo parámetro `enableDrag` (por defecto `true`; no cambia el resto de hojas). |
| `lib/views/login/login_page.dart`, `lib/views/register/complete_profile_page.dart` | Abren la hoja antes de crear la cuenta o el perfil. |
| `lib/views/login/auth_controller_factory.dart` | Inyecta `FirebasePhoneVerificationService` en producción. |

---

## 4. Errores y mensajes

Todos los mensajes salen de `phoneAuthFailureFor`; nunca se muestra el texto
crudo de Firebase.

| Código de Firebase | `AuthFailureType` | Mensaje |
| --- | --- | --- |
| `invalid-phone-number`, `missing-phone-number` | `invalidInput` | El número de celular no es válido para recibir el SMS. |
| `invalid-verification-code` | `invalidVerificationCode` | El código no es correcto. Revísalo e intenta de nuevo. |
| `invalid-verification-id`, `session-expired` | `verificationExpired` | El código venció. Solicita uno nuevo. |
| `credential-already-in-use`, `account-exists-with-different-credential` | `phoneAlreadyInUse` | Este celular ya está asociado a otra cuenta. |
| `too-many-requests` | `tooManyRequests` | Demasiados intentos. Espera unos minutos e intenta nuevamente. |
| `quota-exceeded` | `tooManyRequests` | Se alcanzó el límite de mensajes SMS. Intenta más tarde. |
| `network-request-failed` | `network` | No hay conexión. Revisa tu internet e intenta nuevamente. |
| `operation-not-allowed`, `app-not-authorized`, `captcha-check-failed`, `invalid-app-credential`, `missing-app-credential`, `missing-client-identifier`, `play-integrity-token-request-failed`, `web-internal-error` | `providerMisconfigured` | La verificación por SMS no está disponible en esta versión de la app. |
| cualquier otro | `unknown` | No fue posible verificar tu celular. Intenta nuevamente. |

Además: sin respuesta de Firebase en 90 s → `network`; plataforma sin
soporte (`UnimplementedError`) → `providerMisconfigured`; código que no tiene
6 dígitos → `invalidVerificationCode` sin llamar a Firebase; falta de prueba o
prueba de otro número → `phoneNotVerified`.

---

## 5. Pruebas

```bash
flutter test test/service/auth test/controllers/auth test/views/auth test/widgets/auth
```

| Archivo | Qué cubre |
| --- | --- |
| `test/service/auth/phone_verification_service_test.dart` | Envío, reenvío con token, verificación instantánea, errores, tiempo de espera, `buildProof`, `requireVerifiedPhoneProof` y la tabla de errores. |
| `test/service/auth/firebase_auth_service_test.dart` | Sin prueba no se crea nada; prueba de otro número; vincula antes de guardar el perfil; código incorrecto, vencido o celular ajeno → se revierte la cuenta. |
| `test/service/auth/firebase_social_auth_service_test.dart` | Lo mismo para Completar perfil; celular ya vinculado no pide otra prueba. |
| `test/controllers/auth/login_controller_phone_test.dart` | `phoneNumberToVerify` y que la prueba llegue al servicio. |
| `test/widgets/auth/phone_verification_sheet_test.dart` | La hoja: envío al abrir, validación, reintento, reenvío con espera de 60 s, cancelar. |
| `test/views/auth/register_phone_verification_test.dart` | Flujo completo desde el login: formulario → hoja → cuenta. |
| `test/views/auth/social_auth_flow_test.dart` (`PH-UI-01…03`) | Flujo completo en Completar perfil. |

Las pruebas usan servicios falsos: **no envían SMS ni tocan Firebase**.

---

## 6. Configuración pendiente en Firebase

Esto no se puede hacer desde el código; sin ello la app muestra "La
verificación por SMS no está disponible en esta versión de la app".

1. **Habilitar el proveedor Teléfono** en la consola de Firebase del proyecto
   `machuco`: `Authentication > Sign-in method > Teléfono`.
2. **Android:** los SHA-1 y SHA-256 ya están registrados (ver
   [android-setup.md](android-setup.md)). Phone Auth usa además la
   comprobación de integridad de la app: debe estar habilitada la API de
   **Play Integrity** del proyecto de Google Cloud (o, si no, Firebase cae a
   reCAPTCHA). Si falla, el error es `play-integrity-token-request-failed` o
   `captcha-check-failed`.
3. **Números de prueba:** en `Authentication > Sign-in method > Teléfono >
   Números de teléfono para pruebas` se pueden definir números ficticios con
   un código fijo (p. ej. `+57 300 000 0000` → `123456`). No envían SMS ni
   gastan cuota; úsalos para el equipo.
4. **Cuota de SMS:** los envíos reales tienen una cuota diaria y el plan
   gratuito es muy limitado (revisa el límite vigente en la consola). Sin
   números de prueba, el equipo se quedaría sin SMS rápido.
5. **iOS:** el proyecto aún no tiene `ios/Runner/GoogleService-Info.plist`, así
   que iOS no está configurado para Firebase. Cuando se agregue, Phone Auth
   exige además la clave APNs y el esquema de URL de reCAPTCHA.
6. **Web:** `verifyPhoneNumber` no funciona en web (requiere reCAPTCHA). La app
   lo detecta y muestra "La verificación por SMS no está disponible en esta
   plataforma". Hoy nadie puede registrarse desde web; hay que decidir si se
   soporta (otra API, `linkWithPhoneNumber`) o se acepta.

### Prueba manual sugerida

1. Registrar un cliente con un número de prueba y el código fijo → la cuenta se
   crea; en Firebase Auth el usuario muestra los proveedores `password` y
   `phone`.
2. Repetir con el mismo número y otro correo → "Este celular ya está asociado a
   otra cuenta" y no queda un usuario nuevo en Auth.
3. Escribir un código equivocado → el error aparece en la hoja y no queda
   usuario en Auth.
4. Pedir "Reenviar código" antes de 60 s → el botón está bloqueado.
5. Repetir 1 con Google o GitHub en "Completar perfil".

---

## 7. Límites conocidos (léelos antes de confiar en esto)

- **La exigencia vive en la app, no en las reglas de Firestore.** El servicio
  se niega a crear la cuenta sin prueba, pero un cliente manipulado podría
  crear `users/{uid}` directamente, porque `firestore.rules` no comprueba el
  celular. Para cerrarlo hay que añadir a `isPublicRegistration` una condición
  sobre el token (`request.auth.token.phone_number == request.resource.data.phoneNumber`),
  refrescar el token tras vincular, cubrir el camino de Completar perfil, y
  desplegar las reglas **después** de publicar la app (si no, los registros de
  las versiones antiguas fallan). No se hizo para no cambiar reglas
  compartidas sin acuerdo del equipo.
- **Las cuentas anteriores no están verificadas.** Solo aplica a registros
  nuevos; no hay migración.
- **El método `register(...)` (registro histórico con nombre completo) no
  verifica el celular.** La interfaz no lo usa; si se vuelve a usar, debe pasar
  por el mismo flujo.
- **Editar el celular después no lo vuelve a verificar.** Las reglas dejan que
  el usuario cambie `phoneNumber` en su perfil; el número vinculado en Firebase
  Auth y el del perfil pueden diferir.
- **Un código incorrecto crea y borra una cuenta de Firebase.** El código se
  comprueba al vincular, que ocurre después de crear el usuario. Funciona, pero
  cada reintento repite ese ciclo (en Completar perfil no, porque el usuario ya
  existe).
- **Un correo ya registrado se detecta después del SMS**, no antes, porque
  Firebase no permite consultarlo sin revelar qué correos existen. Gasta un
  SMS en ese caso.
- **En Completar perfil, si el celular ya quedó vinculado pero el perfil no se
  guardó** (corte de red), al reintentar la app vuelve a mostrar la hoja y
  envía otro SMS que no hace falta: el servicio ve que el número ya está
  vinculado a ese usuario y no vuelve a comprobar el código.
- **Con el celular vinculado, esa cuenta también puede entrar con SMS** desde
  cualquier cliente de Firebase. La app no ofrece ese acceso y exige el SMS al
  dueño del número, pero es un método de acceso más.
