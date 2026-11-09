/// Reads authentication-related configuration from `--dart-define` values
/// supplied at build/run time.
///
/// Firebase itself is configured through `lib/firebase_options.dart`; these
/// flags only configure the external users API.
/// API URLs must be injected per environment and never committed.
abstract final class AuthConfig {
  static const usersApiBaseUrl = String.fromEnvironment(
    'AUTH_USERS_API_BASE_URL',
  );
  static const usersApiPath = String.fromEnvironment(
    'AUTH_USERS_API_PATH',
    defaultValue: '/users',
  );

  /// When `true`, the app resolves its [RegisteredUserDirectory] as a
  /// [BackendRegisteredUserDirectory] that reads an external users API
  /// instead of the in-memory seed data. Off by default.
  static const useBackendUsers = bool.fromEnvironment(
    'AUTH_USE_BACKEND_USERS',
    defaultValue: false,
  );

  /// Whether [usersApiBaseUrl] was provided, i.e. whether
  /// [BackendRegisteredUserDirectory] can be constructed with a real
  /// endpoint.
  static bool get hasUsersApiConfigured => usersApiBaseUrl.trim().isNotEmpty;
}
