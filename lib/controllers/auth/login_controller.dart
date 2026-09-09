import 'package:flutter/foundation.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/service/auth/auth0_auth_service.dart';
import 'package:machuco/service/auth/registered_user_directory.dart';

/// Orquesta autenticación y registro de usuarios para la pantalla de login.
///
/// Mantiene la sesión activa y también un directorio de usuarios registrados
/// para pruebas de integración entre módulos.
class LoginController extends ChangeNotifier {
  LoginController({this._authService, RegisteredUserDirectory? userDirectory})
    : _userDirectory = userDirectory ?? InMemoryRegisteredUserDirectory();

  final Auth0AuthService? _authService;
  final RegisteredUserDirectory _userDirectory;

  bool _isSubmitting = false;
  bool _isListingUsers = false;
  AuthSession? _session;
  List<RegisteredUser> _registeredUsers = const [];

  bool get isAuthConfigured => _authService != null;

  bool get isSubmitting => _isSubmitting;

  bool get isListingUsers => _isListingUsers;

  AuthSession? get session => _session;

  List<RegisteredUser> get registeredUsers =>
      List.unmodifiable(_registeredUsers);

  Future<void> restoreSession() async {
    final authService = _authService;
    if (authService == null) {
      return;
    }
    _session = await authService.restoreSession();
    notifyListeners();
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final authService = _requireAuthService();
    _setSubmitting(true);
    try {
      final nextSession = await authService.login(
        email: email,
        password: password,
      );
      _session = nextSession;
      notifyListeners();
      return nextSession;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String profileType,
  }) async {
    final authService = _requireAuthService();
    _setSubmitting(true);
    try {
      await authService.register(
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
        profileType: profileType,
      );
      await _userDirectory.upsertUser(
        RegisteredUser(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          fullName: fullName.trim(),
          email: email.trim(),
          phoneNumber: phoneNumber.trim(),
          role: roleFromMetadataValue(profileType),
          createdAt: DateTime.now().toUtc(),
        ),
      );
      _registeredUsers = await _userDirectory.listUsers(
        accessToken: _session?.accessToken,
      );
      notifyListeners();
    } finally {
      _setSubmitting(false);
    }
  }

  Future<AuthSession> loginWithGoogle({bool preferSignup = false}) async {
    final authService = _requireAuthService();
    _setSubmitting(true);
    try {
      final nextSession = await authService.loginWithGoogle(
        preferSignup: preferSignup,
      );
      _session = nextSession;
      notifyListeners();
      return nextSession;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<void> requestPasswordReset({required String email}) {
    final authService = _requireAuthService();
    return authService.requestPasswordReset(email: email);
  }

  Future<void> logout() async {
    final authService = _authService;
    if (authService != null) {
      await authService.logout();
    }
    _session = null;
    notifyListeners();
  }

  Future<List<RegisteredUser>> listRegisteredUsers() async {
    _isListingUsers = true;
    notifyListeners();
    try {
      _registeredUsers = await _userDirectory.listUsers(
        accessToken: _session?.accessToken,
      );
      return registeredUsers;
    } finally {
      _isListingUsers = false;
      notifyListeners();
    }
  }

  Auth0AuthService _requireAuthService() {
    final authService = _authService;
    if (authService != null) {
      return authService;
    }
    throw const AuthFailure(
      AuthFailureType.invalidConfiguration,
      'Auth0 no está configurado. Define AUTH0_DOMAIN y AUTH0_CLIENT_ID.',
    );
  }

  void _setSubmitting(bool value) {
    if (_isSubmitting == value) {
      return;
    }
    _isSubmitting = value;
    notifyListeners();
  }
}
