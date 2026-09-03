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
  static const useBackendUsers = bool.fromEnvironment(
    'AUTH_USE_BACKEND_USERS',
    defaultValue: false,
  );

  static bool get isConfigured =>
      domain.isNotEmpty && clientId.isNotEmpty && connection.isNotEmpty;

  static bool get hasUsersApiConfigured => usersApiBaseUrl.trim().isNotEmpty;
}
