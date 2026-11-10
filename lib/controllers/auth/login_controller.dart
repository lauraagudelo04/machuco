import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/auth/auth_routes.dart';
import 'package:machuco/controllers/auth/validators/auth_input_normalizer.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/database/model/auth/auth_user_profile_entry.dart';
import 'package:machuco/database/repository/auth/auth_catalog_repository.dart';
import 'package:machuco/database/repository/auth/auth_user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/registered_user_directory.dart';

/// Crea el temporizador periódico del enfriamiento (inyectable en pruebas).
typedef PeriodicTimerFactory =
    Timer Function(Duration period, void Function(Timer timer) callback);

/// Orquesta autenticación y registro de usuarios para la pantalla de login.
///
/// Mantiene la sesión activa y también un directorio de usuarios registrados
/// para pruebas de integración entre módulos.
///
/// La validación de formato del cliente (ver `AuthValidators`) nunca sustituye
/// a la del backend: Firebase Auth y `firestore.rules` son la autoridad.
class LoginController extends ChangeNotifier {
  /// `preferences`, `catalogRepository` y `profileCache` son opcionales: sin
  /// ellos el correo no se persiste, el indicativo usa la semilla de
  /// desarrollo y el perfil no se guarda en SQLite.
  LoginController({
    this._authService,
    RegisteredUserDirectory? userDirectory,
    this._preferences,
    this._catalogRepository,
    this._profileCache,
    PeriodicTimerFactory? timerFactory,
  }) : _userDirectory = userDirectory ?? InMemoryRegisteredUserDirectory(),
       _timerFactory = timerFactory ?? Timer.periodic;

  static const _defaultCountryIsoCode = 'CO';

  /// Texto que el usuario debe escribir para confirmar la eliminación.
  static const deleteConfirmationText = 'ELIMINAR';

  /// Segundos de espera entre solicitudes de recuperación de contraseña.
  static const passwordResetCooldown = 60;

  final AuthService? _authService;
  final RegisteredUserDirectory _userDirectory;
  final AuthPreferences? _preferences;
  final AuthCatalogRepository? _catalogRepository;
  final AuthUserProfileRepository? _profileCache;
  final PeriodicTimerFactory _timerFactory;

  bool _isSubmitting = false;
  bool _isListingUsers = false;
  bool _isRequestingPasswordReset = false;
  bool _isDeletingAccount = false;
  bool _isDisposed = false;
  int _resetCooldownSeconds = 0;
  Timer? _cooldownTimer;
  AuthSession? _session;
  List<RegisteredUser> _registeredUsers = const [];
  String? _currentUserEmail;
  List<CountryPhoneCode> _countryPhoneCodes = const [];
  CountryPhoneCode? _selectedCountryPhoneCode;
  bool _isLoadingCountryPhoneCodes = false;
  String? _countryPhoneCodesError;
  List<SubscriptionPlanOption> _subscriptionPlans = const [];
  bool _isLoadingSubscriptionPlans = false;
  String? _subscriptionPlansError;

  bool get isAuthConfigured => _authService != null;

  bool get isSubmitting => _isSubmitting;

  bool get isListingUsers => _isListingUsers;

  /// `true` mientras se envía un correo de recuperación (antidoble envío).
  bool get isRequestingPasswordReset => _isRequestingPasswordReset;

  /// Segundos que faltan para poder pedir otro correo de recuperación
  /// (0 = disponible). Notifica a los oyentes cada segundo.
  int get resetCooldownSeconds => _resetCooldownSeconds;

  bool get isDeletingAccount => _isDeletingAccount;

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

  /// Planes de suscripción para el registro del propietario.
  List<SubscriptionPlanOption> get subscriptionPlans =>
      List.unmodifiable(_subscriptionPlans);

  bool get isLoadingSubscriptionPlans => _isLoadingSubscriptionPlans;

  String? get subscriptionPlansError => _subscriptionPlansError;

  @override
  void dispose() {
    _isDisposed = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  Future<AuthSession?> restoreSession() async {
    final authService = _authService;
    if (authService == null) {
      return null;
    }
    final AuthSession? restored;
    try {
      restored = await authService.restoreSession();
    } on AuthFailure catch (failure) {
      if (_isBlockingFailure(failure)) {
        _session = null;
        await _clearCachedProfile();
        await _clearCurrentUserEmail();
        notifyListeners();
      }
      rethrow;
    }
    _session = restored;
    if (restored == null) {
      await _clearCurrentUserEmail();
      await _clearCachedProfile();
    } else if (restored.accountStatus == AccountStatus.disabled ||
        restored.accountStatus == AccountStatus.rejected ||
        restored.accountStatus == AccountStatus.anonymized) {
      _session = null;
      await _clearCurrentUserEmail();
      await _clearCachedProfile();
    } else {
      await _saveCurrentUserEmail(restored.email);
      await _cacheProfile(restored);
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

  /// Perfil básico guardado en SQLite para mostrar datos sin red, o `null`.
  /// No autoriza nada: Firestore es la fuente de verdad.
  Future<AuthUserProfileEntry?> loadCachedProfile() async {
    final cache = _profileCache;
    if (cache == null) return null;
    try {
      return await cache.loadCurrent();
    } catch (error) {
      debugPrint('No fue posible leer el perfil local: ${error.runtimeType}');
      return null;
    }
  }

  /// Estado de "Recordar mi correo" para precargar el formulario de login:
  /// `remember` (casilla marcada) y `email` (el último correo recordado, o
  /// `null`). Solo para mostrar; nunca autoriza.
  Future<({bool remember, String? email})> loadRememberedEmail() async {
    final preferences = _preferences;
    if (preferences == null) return (remember: false, email: null);
    try {
      return await preferences.loadRememberedEmail();
    } catch (error) {
      debugPrint('No fue posible leer el correo recordado: $error');
      return (remember: false, email: null);
    }
  }

  /// [rememberEmail] es el valor de la casilla "Recordar mi correo": con un
  /// ingreso exitoso `true` guarda el correo y `false` elimina el recordado.
  /// Un ingreso fallido no cambia nada. Cerrar sesión lo conserva; eliminar la
  /// cuenta lo borra.
  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberEmail = false,
  }) async {
    final authService = _requireAuthService();
    _setSubmitting(true);
    try {
      final nextSession = await authService.login(
        email: AuthPreferences.normalizeEmail(email),
        password: password,
      );
      await _startSession(nextSession);
      await _runPreference((preferences) {
        return rememberEmail
            ? preferences.saveRememberedEmail(email)
            : preferences.clearRememberedEmail();
      });
      return nextSession;
    } on AuthFailure catch (failure) {
      if (_isBlockingFailure(failure)) {
        await _clearCachedProfile();
      }
      rethrow;
    } finally {
      _setSubmitting(false);
    }
  }

  /// Registro histórico con nombre completo, conservado por compatibilidad.
  /// El flujo vigente por rol es [registerAccount].
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

  /// Registro por rol (cliente o propietario). Normaliza y valida los datos
  /// antes de enviarlos; lanza [AuthFailure] de tipo
  /// [AuthFailureType.invalidInput] si alguno no cumple el formato.
  ///
  /// El cliente queda `active`; el propietario `pending_approval`. No abre
  /// sesión: el usuario inicia sesión de forma explícita después.
  /// Validación simulada en el cliente; la real son las reglas de Firestore.
  Future<void> registerAccount(RegistrationData data) async {
    final authService = _requireAuthService();
    final code = _resolveCountryCodeFor(data.phoneCountryCodeId);
    final prepared = _prepareRegistration(data, code);
    _setSubmitting(true);
    try {
      await authService.registerAccount(prepared);
      if (code != null && !code.isDevelopmentSeed) {
        await _runPreference((preferences) {
          return preferences.saveLastCountryCodeId(code.id);
        });
      }
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
      await _startSession(nextSession);
      return nextSession;
    } finally {
      _setSubmitting(false);
    }
  }

  /// Envía el correo de recuperación. Ignora una segunda llamada mientras hay
  /// una en curso y, tras enviar, bloquea nuevos envíos durante
  /// [passwordResetCooldown] segundos ([resetCooldownSeconds]). Dentro del
  /// enfriamiento lanza [AuthFailureType.tooManyRequests] sin llamar al
  /// backend.
  Future<void> requestPasswordReset({required String email}) async {
    final authService = _requireAuthService();
    if (_isRequestingPasswordReset) {
      return;
    }
    if (_resetCooldownSeconds > 0) {
      throw AuthFailure(
        AuthFailureType.tooManyRequests,
        'Espera $_resetCooldownSeconds segundos para solicitar otro correo.',
      );
    }
    final emailError = AuthValidators.email(email);
    if (emailError != null) {
      throw AuthFailure(AuthFailureType.invalidInput, emailError);
    }
    _isRequestingPasswordReset = true;
    notifyListeners();
    try {
      await authService.requestPasswordReset(
        email: AuthPreferences.normalizeEmail(email),
      );
      _startResetCooldown();
    } on AuthFailure catch (failure) {
      if (failure.type == AuthFailureType.tooManyRequests) {
        _startResetCooldown();
      }
      rethrow;
    } finally {
      _isRequestingPasswordReset = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final authService = _authService;
    if (authService != null) {
      await authService.logout();
    }
    _session = null;
    await _clearCurrentUserEmail();
    await _clearCachedProfile();
    notifyListeners();
  }

  /// Elimina la cuenta del usuario autenticado. Exige escribir
  /// [deleteConfirmationText] y la contraseña (reautenticación). Si el
  /// backend confirma, limpia SQLite (perfil) y todo el namespace `auth` de
  /// SharedPreferences; los maestros (indicativos) se conservan.
  ///
  /// No verifica "último administrador" ni reservas activas: no es
  /// garantizable desde el cliente.
  Future<void> deleteAccount({
    required String password,
    required String confirmationText,
  }) async {
    final authService = _requireAuthService();
    if (_isDeletingAccount) {
      return;
    }
    if (confirmationText.trim() != deleteConfirmationText) {
      throw const AuthFailure(
        AuthFailureType.invalidInput,
        'Escribe $deleteConfirmationText para confirmar.',
      );
    }
    if (password.isEmpty) {
      throw const AuthFailure(
        AuthFailureType.invalidInput,
        'Ingresa tu contraseña para confirmar.',
      );
    }
    _isDeletingAccount = true;
    notifyListeners();
    try {
      await authService.deleteAccount(password: password);
      _session = null;
      _currentUserEmail = null;
      _stopResetCooldown();
      await _clearCachedProfile();
      await _runPreference((preferences) => preferences.clearAll());
    } finally {
      _isDeletingAccount = false;
      notifyListeners();
    }
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

  /// Carga los planes de suscripción (Supabase `subscription_plans`) para el
  /// registro del propietario. Permite reintentar con [forceRefresh].
  Future<void> loadSubscriptionPlans({bool forceRefresh = false}) async {
    if (_isLoadingSubscriptionPlans) {
      return;
    }
    _isLoadingSubscriptionPlans = true;
    _subscriptionPlansError = null;
    notifyListeners();
    try {
      final repository = _catalogRepository;
      if (repository == null) {
        _subscriptionPlans = const [];
        _subscriptionPlansError = 'Los planes no están disponibles ahora.';
      } else {
        _subscriptionPlans = await repository.getSubscriptionPlans(
          forceRefresh: forceRefresh,
        );
      }
    } on AuthCatalogRepositoryException catch (e) {
      _subscriptionPlans = const [];
      _subscriptionPlansError = e.message;
    } finally {
      _isLoadingSubscriptionPlans = false;
      notifyListeners();
    }
  }

  Future<void> selectCountryPhoneCode(CountryPhoneCode code) async {
    _selectedCountryPhoneCode = code;
    notifyListeners();
    await _saveLastCountryPhoneCode();
  }

  /// Valida el celular con la longitud definida por el país seleccionado.
  /// Acepta espacios entre los dígitos (se descartan antes de validar).
  String? validatePhoneNumber(String? value) {
    final code = _selectedCountryPhoneCode;
    final compact = (value ?? '').replaceAll(RegExp(r'\s'), '');
    if (compact.isEmpty) {
      return 'Ingresa tu número de celular.';
    }
    if (code == null) {
      return 'Selecciona el indicativo de tu país.';
    }
    final error = AuthValidators.phone(
      code.phoneMinLength,
      code.phoneMaxLength,
    )(compact);
    if (error == null || !RegExp(r'^[0-9]+$').hasMatch(compact)) {
      return error;
    }
    final range = code.phoneMinLength == code.phoneMaxLength
        ? '${code.phoneMinLength}'
        : '${code.phoneMinLength} a ${code.phoneMaxLength}';
    return 'Ingresa un número de $range dígitos para ${code.countryName}.';
  }

  String resolveRouteByRole(RegisteredUserRole role) {
    return switch (role) {
      RegisteredUserRole.client => AppRoutes.clientMotels,
      RegisteredUserRole.owner => AppRoutes.ownerMotels,
      RegisteredUserRole.admin => AppRoutes.ownerManagement,
    };
  }

  /// Ruta a la que enviar tras iniciar sesión. Un propietario pendiente de
  /// aprobación va a la pantalla de revisión ([AuthRoutes.accountReview]).
  ///
  /// Un administrador creado con contraseña temporal (`mustChangePassword`)
  /// va primero a [AuthRoutes.adminChangePassword]. Solo es enrutamiento: sin
  /// cambiarla, `firestore.rules` no le da permisos de administrador.
  String resolvePostLoginRoute(AuthSession session) {
    if (session.role == RegisteredUserRole.admin &&
        session.profile?.mustChangePassword == true) {
      return AuthRoutes.adminChangePassword;
    }
    if (session.accountStatus == AccountStatus.pendingApproval) {
      return AuthRoutes.accountReview;
    }
    return resolveRouteByRole(session.role);
  }

  // ------------------------------------------------------------- internals

  Future<void> _startSession(AuthSession nextSession) async {
    _session = nextSession;
    await _saveCurrentUserEmail(nextSession.email);
    await _cacheProfile(nextSession);
    notifyListeners();
  }

  bool _isBlockingFailure(AuthFailure failure) =>
      failure.type == AuthFailureType.accountDisabled ||
      failure.type == AuthFailureType.accountRejected ||
      failure.type == AuthFailureType.accountDeleted;

  CountryPhoneCode? _resolveCountryCodeFor(int id) {
    for (final code in _countryPhoneCodes) {
      if (code.id == id) return code;
    }
    final selected = _selectedCountryPhoneCode;
    return selected != null && selected.id == id ? selected : null;
  }

  /// Normaliza y valida; devuelve los datos listos para el servicio (celular
  /// con indicativo, NIT canónico `base-DV`).
  RegistrationData _prepareRegistration(
    RegistrationData data,
    CountryPhoneCode? code,
  ) {
    if (code == null) {
      throw const AuthFailure(
        AuthFailureType.invalidInput,
        'Selecciona el indicativo de tu país.',
      );
    }
    // Se descartan solo los espacios; cualquier otro símbolo es un error.
    final phoneDigits = data.phoneNumber.replaceAll(RegExp(r'\s'), '');
    final errors = <String?>[
      AuthValidators.firstNames(data.firstNames),
      AuthValidators.lastNames(data.lastNames),
      AuthValidators.phone(code.phoneMinLength, code.phoneMaxLength)(
        phoneDigits,
      ),
      AuthValidators.email(data.email),
      AuthValidators.password(data.password),
    ];
    String? nit;
    String? companyName;
    switch (data.role) {
      case RegisteredUserRole.client:
        errors.add(AuthValidators.birthDate(data.birthDate));
      case RegisteredUserRole.owner:
        final personType = data.personType;
        if (personType == null) {
          errors.add('Selecciona el tipo de persona.');
        } else {
          errors.add(AuthValidators.nit(personType)(data.nit));
          nit = AuthInputNormalizer.nit(data.nit);
          if (personType == PersonType.juridica) {
            errors.add(AuthValidators.companyName(data.companyName));
            companyName = AuthInputNormalizer.text(data.companyName);
          }
        }
        errors.add(data.planId == null ? 'Selecciona un plan.' : null);
      case RegisteredUserRole.admin:
        errors.add('El tipo de cuenta no está disponible para registro.');
    }
    for (final error in errors) {
      if (error != null) {
        throw AuthFailure(AuthFailureType.invalidInput, error);
      }
    }
    return data.copyWith(
      firstNames: AuthInputNormalizer.text(data.firstNames),
      lastNames: AuthInputNormalizer.text(data.lastNames),
      phoneCountryCodeId: code.id,
      phoneNumber: '${code.dialCode}$phoneDigits',
      email: AuthInputNormalizer.email(data.email),
      nit: nit,
      companyName: companyName,
    );
  }

  void _startResetCooldown() {
    _cooldownTimer?.cancel();
    _resetCooldownSeconds = passwordResetCooldown;
    _cooldownTimer = _timerFactory(const Duration(seconds: 1), (timer) {
      _resetCooldownSeconds = _resetCooldownSeconds > 0
          ? _resetCooldownSeconds - 1
          : 0;
      if (_resetCooldownSeconds == 0) {
        timer.cancel();
        _cooldownTimer = null;
      }
      notifyListeners();
    });
  }

  void _stopResetCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _resetCooldownSeconds = 0;
  }

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

  /// Guarda el perfil básico del usuario en SQLite (best-effort; el NIT y la
  /// fecha de nacimiento nunca se proyectan a la tabla local).
  Future<void> _cacheProfile(AuthSession authSession) async {
    final cache = _profileCache;
    if (cache == null) return;
    final profile =
        authSession.profile ??
        UserProfile(
          uid: authSession.userId,
          fullName: authSession.name,
          email: authSession.email,
          phoneNumber: '',
          role: authSession.role,
          accountStatus: authSession.accountStatus,
        );
    try {
      await cache.saveCurrent(profile);
    } catch (error) {
      debugPrint(
        'No fue posible guardar el perfil local: ${error.runtimeType}',
      );
    }
  }

  Future<void> _clearCachedProfile() async {
    final cache = _profileCache;
    if (cache == null) return;
    try {
      await cache.clear();
    } catch (error) {
      debugPrint('No fue posible borrar el perfil local: ${error.runtimeType}');
    }
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
