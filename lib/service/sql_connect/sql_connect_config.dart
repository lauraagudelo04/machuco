/// Configuración de Firebase SQL Connect (antes Data Connect).
///
/// Por defecto la app usa el servicio real en la nube (`machuco-service`).
/// Para desarrollar contra el emulador local:
///
/// ```
/// npx -y firebase-tools@15.34.1 emulators:start --only dataconnect --project demo-machuco
/// flutter run --dart-define=USE_SQL_CONNECT_EMULATOR=true
/// ```
///
/// Ver `docs/sql_connect.md`.
abstract final class SqlConnectConfig {
  /// `true` cuando se corre con `--dart-define=USE_SQL_CONNECT_EMULATOR=true`.
  static const useEmulator = bool.fromEnvironment('USE_SQL_CONNECT_EMULATOR');

  /// Host del emulador. El SDK traduce `127.0.0.1` a `10.0.2.2` en el
  /// emulador de Android. En un celular físico, pasar la IP del computador
  /// con `--dart-define=SQL_CONNECT_EMULATOR_HOST=<ip>`.
  static const emulatorHost = String.fromEnvironment(
    'SQL_CONNECT_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  /// Puerto del emulador (debe coincidir con `firebase.json`).
  static const emulatorPort = int.fromEnvironment(
    'SQL_CONNECT_EMULATOR_PORT',
    defaultValue: 9399,
  );
}
