import 'package:flutter/foundation.dart';
import 'package:machuco/database/repository/auth/auth_catalog_repository.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/auth/registered_user_directory.dart';

/// Orquesta autenticación y registro de usuarios para la pantalla de login.
///
/// Mantiene la sesión activa y también un directorio de usuarios registrados
/// para pruebas de integración entre módulos.
class LoginController extends ChangeNotifier {
  /// `preferences` y `catalogRepository` son opcionales: sin ellos el
  /// correo no se persiste y el indicativo usa la semilla de desarrollo.
  LoginController({
    this._authService,
    RegisteredUserDirectory? userDirectory,
    this._preferences,
    this._catalogRepository,
  }) : _userDirectory = userDirectory ?? InMemoryRegisteredUserDirectory();

  static const _defaultCountryIsoCode = 'CO';

  final AuthService? _authService;
  final RegisteredUserDirectory _userDirectory;
  final AuthPreferences? _preferences;
  final AuthCatalogRepository? _catalogRepository;

  bool _isSubmitting = false;
  bool _isListingUsers = false;
  AuthSession? _session;
  List<RegisteredUser> _registeredUsers = const [];
  String? _currentUserEmail;
  List<CountryPhoneCode> _countryPhoneCodes = const [];
  CountryPhoneCode? _selectedCountryPhoneCode;
  bool _isLoadingCountryPhoneCodes = false;
  String? _countryPhoneCodesError;

  bool get isAuthConfigured => _authService != null;

  bool get isSubmitting => _isSubmitting;

  bool get isListingUsers => _isListingUsers;

  AuthSession? get session => _session;

  List<RegisteredUser> get registeredUsers =>
      List.unmodifiable(_registeredUsers);

  /// Correo del usuario autenticado, persistido en SharedPreferences.
  /// Sirve para mostrar y precargar datos, nunca para autorizar.
  String? get currentUserEmail => _currentUserEmail;

  List<CountryPhoneCode> get countryPhoneCodes =>
      List.unmodifiable(_countryPhoneCodes);

  CountryPhoneCode? get selectedCountryPhoneCode => _selectedCountryPhoneCode;

  bool get isLoadingCountryPhoneCodes => _isLoadingCountryPhoneCodes;

  String? get countryPhoneCodesError => _countryPhoneCodesError;

  Future<AuthSession?> restoreSession() async {
    final authService = _authService;
    if (authService == null) {
      return null;
    }
    final restored = await authService.restoreSession();
    _session = restored;
    if (restored == null) {
      await _clearCurrentUserEmail();
    } else {
      await _saveCurrentUserEmail(restored.email);
    }
    notifyListeners();
    return _session;
  }

  /// Carga el correo compartido al arrancar, antes de pintar la primera vista
  /// protegida. Devuelve `null` si no hay ninguno guardado.
  Future<String?> loadCurrentUserEmail() async {
    final preferences = _preferences;
    if (preferences == null) {
      return _currentUserEmail;
    }
    try {
      _currentUserEmail = await preferences.loadCurrentUserEmail();
    } catch (error) {
      debugPrint('No fue posible leer el correo de sesión: $error');
      _currentUserEmail = null;
    }
    notifyListeners();
    return _currentUserEmail;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final authService = _requireAuthService();
    _setSubmitting(true);
    try {
      final nextSession = await authService.login(
        email: AuthPreferences.normalizeEmail(email),
        password: password,
      );
      _session = nextSession;
      await _saveCurrentUserEmail(nextSession.email);
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
    required RegisteredUserRole role,
  }) async {
    final authService = _requireAuthService();
    _setSubmitting(true);
    final normalizedEmail = AuthPreferences.normalizeEmail(email);
    final fullPhoneNumber = _withDialCode(phoneNumber);
    try {
      await authService.register(
        fullName: fullName,
        email: normalizedEmail,
        phoneNumber: fullPhoneNumber,
        password: password,
        role: role,
      );
      await _saveLastCountryPhoneCode();
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
      await _saveCurrentUserEmail(nextSession.email);
      notifyListeners();
      return nextSession;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<void> requestPasswordReset({required String email}) {
    final authService = _requireAuthService();
    return authService.requestPasswordReset(
      email: AuthPreferences.normalizeEmail(email),
    );
  }

  Future<void> logout() async {
    final authService = _authService;
    if (authService != null) {
      await authService.logout();
    }
    _session = null;
    await _clearCurrentUserEmail();
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

  /// Carga el maestro de indicativos (caché de SQLite primero, Supabase
  /// después) y preselecciona el último usado o, si no hay, Colombia (+57).
  Future<void> loadCountryPhoneCodes({bool forceRefresh = false}) async {
    if (_isLoadingCountryPhoneCodes) {
      return;
    }
    _isLoadingCountryPhoneCodes = true;
    _countryPhoneCodesError = null;
    notifyListeners();
    try {
      final repository = _catalogRepository;
      _countryPhoneCodes = repository == null
          ? const [developmentCountryPhoneCodeSeed]
          : await repository.getCountryPhoneCodes(forceRefresh: forceRefresh);
      _selectedCountryPhoneCode = await _resolveInitialCountryPhoneCode();
    } on AuthCatalogRepositoryException {
      _countryPhoneCodes = const [];
      _selectedCountryPhoneCode = null;
      _countryPhoneCodesError =
          'No pudimos cargar los indicativos. Revisa tu conexión.';
    } finally {
      _isLoadingCountryPhoneCodes = false;
      notifyListeners();
    }
  }

  Future<void> selectCountryPhoneCode(CountryPhoneCode code) async {
    _selectedCountryPhoneCode = code;
    notifyListeners();
    await _saveLastCountryPhoneCode();
  }

  /// Valida el celular con la longitud definida por el país seleccionado.
  String? validatePhoneNumber(String? value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) {
      return 'Ingresa tu número de celular.';
    }
    final code = _selectedCountryPhoneCode;
    if (code == null) {
      return 'Selecciona el indicativo de tu país.';
    }
    if (digits.length < code.phoneMinLength ||
        digits.length > code.phoneMaxLength) {
      final range = code.phoneMinLength == code.phoneMaxLength
          ? '${code.phoneMinLength}'
          : '${code.phoneMinLength} a ${code.phoneMaxLength}';
      return 'Ingresa un número de $range dígitos para ${code.countryName}.';
    }
    return null;
  }

  String resolveRouteByRole(RegisteredUserRole role) {
    return switch (role) {
      RegisteredUserRole.client => AppRoutes.clientMotels,
      RegisteredUserRole.owner => AppRoutes.ownerMotels,
      RegisteredUserRole.admin => AppRoutes.ownerManagement,
    };
  }

  String resolvePostLoginRoute(AuthSession session) =>
      resolveRouteByRole(session.role);

  Future<CountryPhoneCode?> _resolveInitialCountryPhoneCode() async {
    if (_countryPhoneCodes.isEmpty) {
      return null;
    }
    final preferredIds = <int?>[_selectedCountryPhoneCode?.id];
    try {
      preferredIds.add(await _preferences?.loadLastCountryCodeId());
    } catch (error) {
      debugPrint('No fue posible leer el último indicativo: $error');
    }
    for (final id in preferredIds) {
      for (final code in _countryPhoneCodes) {
        if (id != null && code.id == id) return code;
      }
    }
    for (final code in _countryPhoneCodes) {
      if (code.isoCode == _defaultCountryIsoCode) return code;
    }
    return _countryPhoneCodes.first;
  }

  String _withDialCode(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final dialCode = _selectedCountryPhoneCode?.dialCode;
    return dialCode == null ? digits : '$dialCode$digits';
  }

  Future<void> _saveLastCountryPhoneCode() async {
    final code = _selectedCountryPhoneCode;
    if (code == null || code.isDevelopmentSeed) {
      return;
    }
    await _runPreference((preferences) {
      return preferences.saveLastCountryCodeId(code.id);
    });
  }

  Future<void> _saveCurrentUserEmail(String email) async {
    final normalized = AuthPreferences.normalizeEmail(email);
    _currentUserEmail = normalized.isEmpty ? null : normalized;
    await _runPreference((preferences) {
      return preferences.saveCurrentUserEmail(normalized);
    });
  }

  Future<void> _clearCurrentUserEmail() async {
    _currentUserEmail = null;
    await _runPreference((preferences) {
      return preferences.clearCurrentUserEmail();
    });
  }

  /// Las preferencias son best-effort: un fallo del almacenamiento local no
  /// debe impedir iniciar ni cerrar sesión.
  Future<void> _runPreference(
    Future<void> Function(AuthPreferences preferences) action,
  ) async {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    try {
      await action(preferences);
    } catch (error) {
      debugPrint('No fue posible actualizar las preferencias de auth: $error');
    }
  }

  AuthService _requireAuthService() {
    final authService = _authService;
    if (authService != null) {
      return authService;
    }
    throw const AuthFailure(
      AuthFailureType.invalidConfiguration,
      'La autenticación no está disponible en este momento.',
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
