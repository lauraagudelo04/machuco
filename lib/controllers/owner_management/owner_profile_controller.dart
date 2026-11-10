import 'package:flutter/foundation.dart';

import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/password_change_service.dart';
import 'package:machuco/service/firebase/current_user.dart';

/// Estado del perfil del propietario autenticado.
///
/// Carga y actualiza `users/{uid}`. Las reglas de Firestore solo permiten que
/// el propio usuario cambie `fullName` y `phoneNumber`; el documento, el rol y
/// el estado los administra el panel de administración.
class OwnerProfileController extends ChangeNotifier {
  OwnerProfileController({
    UserProfileRepository? repository,
    PasswordChangeService? passwordChangeService,
    String? Function()? currentUserId,
  }) : _repository = repository ?? FirestoreUserProfileRepository(),
       _passwordChangeService =
           passwordChangeService ?? FirebasePasswordChangeService(),
       _currentUserId = currentUserId ?? (() => CurrentUser.uid);

  final UserProfileRepository _repository;
  final PasswordChangeService _passwordChangeService;
  final String? Function() _currentUserId;

  UserProfile? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isChangingPassword = false;
  String? _errorMessage;
  String? _passwordError;

  UserProfile? get profile => _profile;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  bool get isChangingPassword => _isChangingPassword;

  /// Error del último intento de cambio de contraseña.
  String? get passwordError => _passwordError;

  /// Carga el perfil del usuario con sesión iniciada.
  Future<void> load() async {
    final uid = _currentUserId()?.trim() ?? '';
    if (uid.isEmpty) {
      _errorMessage = 'No hay una sesión activa.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final profile = await _repository.getProfile(uid);
      _profile = profile;
      if (profile == null) {
        _errorMessage = 'No se encontró el perfil de esta cuenta.';
      }
    } on UserProfileRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'No se pudo cargar tu perfil. Intenta de nuevo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cambia la contraseña y limpia la marca de contraseña temporal.
  ///
  /// Devuelve `true` si Firebase Auth aceptó la nueva contraseña. Si el perfil
  /// tenía `mustChangePassword`, se limpia después; si esa limpieza falla, la
  /// contraseña ya cambió y se informa para reintentar.
  Future<bool> changePassword({required String newPassword}) async {
    _passwordError = null;
    final validationError = AuthValidators.password(newPassword);
    if (validationError != null) {
      _passwordError = validationError;
      notifyListeners();
      return false;
    }

    final uid = _currentUserId()?.trim() ?? '';
    if (uid.isEmpty) {
      _passwordError = 'No hay una sesión activa.';
      notifyListeners();
      return false;
    }

    _isChangingPassword = true;
    notifyListeners();
    var passwordUpdated = false;
    try {
      await _passwordChangeService.changePassword(newPassword: newPassword);
      passwordUpdated = true;
      if (_profile?.mustChangePassword == true) {
        await _repository.clearMustChangePassword(uid);
      }
      await load();
      return true;
    } on AuthFailure catch (failure) {
      _passwordError = failure.message;
      return false;
    } on UserProfileRepositoryException catch (error) {
      _passwordError = passwordUpdated
          ? 'Tu contraseña cambió, pero no pudimos actualizar tu perfil. '
                'Intenta nuevamente.'
          : error.message;
      return false;
    } catch (_) {
      _passwordError = 'No pudimos cambiar tu contraseña. Intenta nuevamente.';
      return false;
    } finally {
      _isChangingPassword = false;
      notifyListeners();
    }
  }

  /// Guarda el nombre y el teléfono. Devuelve `true` si la nube los aceptó.
  Future<bool> update({
    required String fullName,
    required String phoneNumber,
  }) async {
    final uid = _currentUserId()?.trim() ?? '';
    if (uid.isEmpty) {
      _errorMessage = 'No hay una sesión activa.';
      notifyListeners();
      return false;
    }

    final name = fullName.trim();
    if (name.length < 3) {
      _errorMessage = 'Ingresa tu nombre completo.';
      notifyListeners();
      return false;
    }

    final phone = phoneNumber.trim();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      _errorMessage =
          'Ingresa un teléfono válido con indicativo, por ejemplo '
          '+573001234567.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.updateProfile(
        uid: uid,
        fullName: name,
        phoneNumber: phone,
      );
      await load();
      return true;
    } on UserProfileRepositoryException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'No se pudo guardar tu perfil. Intenta de nuevo.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
