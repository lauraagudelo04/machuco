/// Reads Auth0 and users-API configuration from `--dart-define` values
/// supplied at build/run time (see README.md#configuración-de-auth0-para-login-y-registro).
///
/// No value has a hardcoded default beyond the ones documented here as
/// `defaultValue`; domain, client ID and API URLs must always be injected
/// per environment and must never be committed to the repository.
abstract final class Auth0Config {
  static const domain = String.fromEnvironment('AUTH0_DOMAIN');
  static const clientId = String.fromEnvironment('AUTH0_CLIENT_ID');
  static const connection = String.fromEnvironment(
    'AUTH0_CONNECTION',
    defaultValue: 'Username-Password-Authentication',
  );
  static const audience = String.fromEnvironment('AUTH0_AUDIENCE');
  static const usersApiBaseUrl = String.fromEnvironment(
    'AUTH_USERS_API_BASE_URL',
  );
  static const usersApiPath = String.fromEnvironment(
    'AUTH_USERS_API_PATH',
    defaultValue: '/users',
  );

  /// When `true`, the app resolves its [RegisteredUserDirectory] as a
  /// [BackendRegisteredUserDirectory] that reads/writes an external users
  /// API instead of the in-memory seed data. Off by default.
  static const useBackendUsers = bool.fromEnvironment(
    'AUTH_USE_BACKEND_USERS',
    defaultValue: false,
  );

  /// When `true`, the app authenticates against the fixed, in-app test
  /// accounts in `hardcoded_auth_service.dart` instead of Auth0. Intended
  /// only for local development and QA without a configured Auth0 tenant;
  /// off by default.
  static const useHardcodedAuthUsers = bool.fromEnvironment(
    'AUTH_USE_HARDCODED_AUTH_USERS',
    defaultValue: false,
  );
  static const roleClaimNamespace = String.fromEnvironment(
    'AUTH0_ROLE_CLAIM_NAMESPACE',
    defaultValue: 'https://machuco.app/claims',
  );
  static const roleClaimName = String.fromEnvironment(
    'AUTH0_ROLE_CLAIM_NAME',
    defaultValue: 'role',
  );

  /// Whether the minimum Auth0 values needed to build [Auth0AuthService]
  /// were provided. [Auth0AuthService.fromEnvironment] returns `null` when
  /// this is `false`.
  static bool get isConfigured =>
      domain.isNotEmpty && clientId.isNotEmpty && connection.isNotEmpty;

  /// Whether [usersApiBaseUrl] was provided, i.e. whether
  /// [BackendRegisteredUserDirectory] can be constructed with a real
  /// endpoint.
  static bool get hasUsersApiConfigured => usersApiBaseUrl.trim().isNotEmpty;
}
