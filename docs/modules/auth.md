# Módulo: Autenticación

Estado general: **parcial**. El login y registro contra Auth0 están
implementados; la autorización por rol en backend y el modo de usuarios de
prueba son piezas explícitamente provisionales.

## Modelos

- `lib/models/auth/registered_user.dart`
  - `RegisteredUserRole` (`admin`, `client`, `owner`): ver perfiles en
    [README.md#perfiles](../../README.md#perfiles).
  - `RegisteredUser`: usuario de la aplicación (nombre, correo, teléfono,
    rol, fecha de creación), con `fromJson`/`toJson` pensados para un API
    HTTP.

## Servicios (`lib/service/auth/`)

- `AuthService` (interfaz): contrato único para login, login con Google,
  registro, recuperación de contraseña, restaurar sesión y logout.
- `Auth0AuthService`: implementación real contra Auth0 (`auth0_flutter`).
  Solo se construye si `Auth0Config.isConfigured` es `true`
  (`Auth0Config.fromEnvironment`). Extrae el rol del usuario de los claims
  del ID token, con varias rutas de compatibilidad (`_extractRole`); si no
  encuentra ningún claim reconocible, asume `client` por defecto.
- `HardcodedAuthService`: **estado: placeholder de pruebas.** Autentica
  contra una lista fija de cuentas embebidas en el código, sin depender de
  Auth0. Solo se activa con `AUTH_USE_HARDCODED_AUTH_USERS=true` (apagado
  por defecto). No soporta registro, login con Google ni recuperación de
  contraseña: todos esos métodos lanzan `AuthFailure`. Ver hallazgo de
  seguridad en [../decisions_log.md](../decisions_log.md).
- `Auth0Config`: valores leídos de `--dart-define`, documentados en
  [README.md#configuración-de-auth0-para-login-y-registro](../../README.md#configuración-de-auth0-para-login-y-registro).
  No hay valores por defecto sensibles hardcodeados.

### Directorio de usuarios

- `RegisteredUserDirectory` (interfaz): listar y crear/actualizar usuarios,
  independiente del origen de datos.
- `InMemoryRegisteredUserDirectory`: **estado: datos de ejemplo.** Usuarios
  sembrados en memoria, sin persistencia real. Es la implementación por
  defecto.
- `BackendRegisteredUserDirectory`: **estado: parcial/opcional.** Consulta
  un API HTTP externo vía `package:http`, activable con
  `AUTH_USE_BACKEND_USERS=true` y `AUTH_USERS_API_BASE_URL`. Su método
  `upsertUser` es un no-op intencional: la creación/actualización de
  usuarios se espera que ocurra vía Auth0, no vía este directorio. Ver
  [../decisions_log.md](../decisions_log.md) para el hallazgo asociado.

## Controllers y vistas

- `lib/controllers/auth/login_controller.dart` (`ChangeNotifier`) coordina
  el formulario de login/registro con el `AuthService` activo.
- `lib/views/login/login_page.dart` y `lib/views/register/` contienen las
  pantallas de autenticación, incluido el botón "Continuar con Google"
  descrito en
  [README.md#inicio-de-sesión-con-google](../../README.md#inicio-de-sesión-con-google).

## Qué falta o es provisional

- Autorización por rol en backend: no hay evidencia en este repositorio de
  que un servidor valide el rol del usuario antes de autorizar una
  operación; el rol se interpreta hoy solo del lado del cliente a partir
  del token de Auth0.
- `BackendRegisteredUserDirectory` es de solo lectura en la práctica
  (`upsertUser` no persiste nada) y depende de un API cuyo contrato no está
  descrito en ningún documento del proyecto más allá del código.
- El modo de usuarios de prueba (`HardcodedAuthService`) no debe activarse
  fuera de desarrollo/QA local.
- No se encontraron pruebas automatizadas para este módulo en `test/`.
