/// Métodos de acceso que maneja la app (Firebase Authentication).
///
/// [providerId] es el identificador de Firebase (`UserInfo.providerId`).
enum AuthProviderKind {
  password('password', 'correo y contraseña'),
  google('google.com', 'Google'),
  github('github.com', 'GitHub');

  const AuthProviderKind(this.providerId, this.displayName);

  final String providerId;

  /// Nombre visible en español para mensajes.
  final String displayName;

  /// `null` si el proveedor no es uno de los que usa la app.
  static AuthProviderKind? fromProviderId(String? providerId) {
    for (final kind in values) {
      if (kind.providerId == providerId) return kind;
    }
    return null;
  }

  bool get isSocial => this != password;
}
