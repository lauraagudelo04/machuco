abstract final class Auth0Config {
  static const domain = String.fromEnvironment('AUTH0_DOMAIN');
  static const clientId = String.fromEnvironment('AUTH0_CLIENT_ID');
  static const connection = String.fromEnvironment(
    'AUTH0_CONNECTION',
    defaultValue: 'Username-Password-Authentication',
  );
  static const audience = String.fromEnvironment('AUTH0_AUDIENCE');

  static bool get isConfigured =>
      domain.isNotEmpty && clientId.isNotEmpty && connection.isNotEmpty;
}
