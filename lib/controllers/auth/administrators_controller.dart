import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/auth/validators/auth_input_normalizer.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/password_change_service.dart';

/// Vista "Administradores": consultar, crear, editar y eliminar (anonimizar)
/// cuentas de administrador, y primer cambio de contraseña del nuevo
/// administrador.
///
/// Ocultar estas pantallas a otros roles es solo UX: quien autoriza es
/// `firestore.rules`. La validación de este controller solo da mensajes
/// claros antes de enviar.
///
/// Eliminar la PROPIA cuenta no pasa por aquí: usa `LoginController
/// .deleteAccount` (reautentica, anonimiza y borra el usuario de Auth).
class AdministratorsController extends ChangeNotifier {
  AdministratorsController({
    required this._repository,
    this._passwordChangeService,
    this._currentUid,
  });

  final AdministratorsRepository _repository;
  final PasswordChangeService? _passwordChangeService;
  final String? Function()? _currentUid;

  List<UserProfile> _administrators = const [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isChangingPassword = false;
  bool _isDisposed = false;
  bool _passwordAlreadyUpdated = false;
  String? _error;
  AdministratorsFailureType? _errorType;
  AuthFailureType? _passwordFailure;

  /// Administradores no anonimizados, ordenados por nombre.
  List<UserProfile> get administrators => List.unmodifiable(_administrators);

  bool get isLoading => _isLoading;

  /// `true` mientras se crea, edita o elimina (evita el doble envío).
  bool get isSubmitting => _isSubmitting;

  bool get isChangingPassword => _isChangingPassword;

  /// Último error legible (español) o `null`.
  String? get error => _error;

  /// Tipo del último error del repositorio (`network` => ofrecer reintentar;
  /// `lastAdmin`, `emailInUse`, `notFound`...).
  AdministratorsFailureType? get errorType => _errorType;

  /// Tipo del último fallo al cambiar la contraseña (`weakPassword`,
  /// `requiresRecentLogin`, `network`...).
  AuthFailureType? get passwordFailure => _passwordFailure;

  UserProfile? findAdministrator(String uid) {
    for (final profile in _administrators) {
      if (profile.uid == uid) return profile;
    }
    return null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  void clearError() {
    if (_error == null && _errorType == null && _passwordFailure == null) {
      return;
    }
    _error = null;
    _errorType = null;
    _passwordFailure = null;
    notifyListeners();
  }

  /// Carga (o reintenta cargar) la lista. Si falla no deja datos parciales.
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _clear();
    notifyListeners();
    try {
      _administrators = await _repository.listAdministrators();
    } on AdministratorsRepositoryException catch (e) {
      _administrators = const [];
      _setError(e);
    } catch (e) {
      debugPrint(
        'Error inesperado al cargar administradores: ${e.runtimeType}',
      );
      _administrators = const [];
      _setUnknown('No pudimos cargar los administradores. Intenta nuevamente.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crea un administrador con contraseña temporal. Devuelve el resultado (con
  /// la contraseña, que solo existe aquí y debe mostrarse una vez) o `null` si
  /// falló; entonces [error] y [errorType] explican el motivo. No se envía
  /// ningún correo ni SMS.
  Future<CreatedAdministrator?> create({
    required String firstNames,
    required String lastNames,
    required CountryPhoneCode phoneCode,
    required String phoneNumber,
    required String email,
  }) async {
    final invalid =
        _validateContact(firstNames, lastNames, phoneCode, phoneNumber) ??
        AuthValidators.email(email);
    if (invalid != null) {
      _setInvalid(invalid);
      return null;
    }
    CreatedAdministrator? created;
    final ok = await _submit(() async {
      created = await _repository.createAdministrator(
        NewAdministratorData(
          firstNames: AuthInputNormalizer.text(firstNames),
          lastNames: AuthInputNormalizer.text(lastNames),
          phoneCountryCodeId: phoneCode.id,
          phoneNumber: _fullPhone(phoneCode, phoneNumber),
          email: AuthInputNormalizer.email(email),
        ),
      );
    });
    return ok ? created : null;
  }

  /// Actualiza nombres, apellidos, indicativo y celular. El correo, el rol y
  /// el estado no se editan.
  Future<bool> update(
    String uid, {
    required String firstNames,
    required String lastNames,
    required CountryPhoneCode phoneCode,
    required String phoneNumber,
  }) async {
    final invalid = _validateContact(
      firstNames,
      lastNames,
      phoneCode,
      phoneNumber,
    );
    if (invalid != null) {
      _setInvalid(invalid);
      return false;
    }
    return _submit(() async {
      await _repository.updateAdministrator(
        uid,
        AdministratorContactChanges(
          firstNames: AuthInputNormalizer.text(firstNames),
          lastNames: AuthInputNormalizer.text(lastNames),
          phoneCountryCodeId: phoneCode.id,
          phoneNumber: _fullPhone(phoneCode, phoneNumber),
        ),
      );
    });
  }

  /// Anonimiza a OTRO administrador. Con [AdministratorsFailureType.lastAdmin]
  /// no cambia nada.
  Future<bool> anonymize(String uid) {
    if (uid == _currentUid?.call()) {
      _setInvalid(
        'Para eliminar tu propia cuenta usa "Eliminar cuenta" en tu perfil.',
      );
      return Future.value(false);
    }
    return _submit(() => _repository.anonymizeAdministrator(uid));
  }

  /// Primer ingreso del administrador creado con contraseña temporal: valida
  /// la nueva contraseña, la cambia y limpia la marca `mustChangePassword`.
  /// Si la contraseña ya cambió y solo falló limpiar la marca, un reintento
  /// no vuelve a cambiarla. Mira [passwordFailure] si devuelve `false`.
  Future<bool> changeOwnPassword({
    required String newPassword,
    required String confirmation,
  }) async {
    final service = _passwordChangeService;
    if (_isChangingPassword) return false;
    _clear();
    final invalid =
        AuthValidators.password(newPassword) ??
        AuthValidators.confirmPassword(() => newPassword)(confirmation);
    if (invalid != null) {
      _passwordFailure = AuthFailureType.invalidInput;
      _error = invalid;
      notifyListeners();
      return false;
    }
    if (service == null) {
      _passwordFailure = AuthFailureType.invalidConfiguration;
      _error = 'El cambio de contraseña no está disponible en este momento.';
      notifyListeners();
      return false;
    }
    _isChangingPassword = true;
    notifyListeners();
    try {
      if (!_passwordAlreadyUpdated) {
        await service.changePassword(newPassword: newPassword);
        _passwordAlreadyUpdated = true;
      }
      await _repository.clearMustChangePassword();
      _passwordAlreadyUpdated = false;
      return true;
    } on AuthFailure catch (failure) {
      _passwordFailure = failure.type;
      _error = failure.message;
      return false;
    } on AdministratorsRepositoryException catch (e) {
      _passwordFailure = e.type == AdministratorsFailureType.network
          ? AuthFailureType.network
          : AuthFailureType.unknown;
      _error = _passwordAlreadyUpdated
          ? 'Tu contraseña cambió, pero no pudimos terminar. Intenta nuevamente.'
          : e.message;
      return false;
    } catch (e) {
      debugPrint('Error inesperado al cambiar la contraseña: ${e.runtimeType}');
      _passwordFailure = AuthFailureType.unknown;
      _error = 'No pudimos cambiar tu contraseña. Intenta nuevamente.';
      return false;
    } finally {
      _isChangingPassword = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- internals

  /// Una sola operación a la vez. Tras un éxito refresca la lista; si la
  /// cuenta ya no existe, la quita y refresca.
  Future<bool> _submit(Future<void> Function() action) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _clear();
    notifyListeners();
    var ok = false;
    try {
      await action();
      ok = true;
    } on AdministratorsRepositoryException catch (e) {
      _setError(e);
    } catch (e) {
      debugPrint('Error inesperado en administradores: ${e.runtimeType}');
      _setUnknown('No pudimos completar la operación. Intenta nuevamente.');
    }
    if (ok || _errorType == AdministratorsFailureType.notFound) {
      await _refreshQuietly();
    }
    _isSubmitting = false;
    notifyListeners();
    return ok;
  }

  Future<void> _refreshQuietly() async {
    try {
      _administrators = await _repository.listAdministrators();
    } catch (e) {
      // La operación ya se hizo; la lista se refresca al reintentar la carga.
      debugPrint('No se pudo refrescar la lista: ${e.runtimeType}');
    }
  }

  String? _validateContact(
    String firstNames,
    String lastNames,
    CountryPhoneCode phoneCode,
    String phoneNumber,
  ) {
    final digits = phoneNumber.replaceAll(RegExp(r'\s'), '');
    return AuthValidators.firstNames(firstNames) ??
        AuthValidators.lastNames(lastNames) ??
        AuthValidators.phone(
          phoneCode.phoneMinLength,
          phoneCode.phoneMaxLength,
        )(digits);
  }

  String _fullPhone(CountryPhoneCode code, String phoneNumber) =>
      '${code.dialCode}${phoneNumber.replaceAll(RegExp(r'\s'), '')}';

  void _clear() {
    _error = null;
    _errorType = null;
    _passwordFailure = null;
  }

  void _setError(AdministratorsRepositoryException e) {
    _error = e.message;
    _errorType = e.type;
  }

  void _setUnknown(String message) {
    _error = message;
    _errorType = AdministratorsFailureType.unknown;
  }

  void _setInvalid(String message) {
    _error = message;
    _errorType = AdministratorsFailureType.invalidInput;
    notifyListeners();
  }
}
