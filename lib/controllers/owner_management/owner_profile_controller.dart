import 'package:flutter/foundation.dart';

import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/firebase/current_user.dart';

/// Estado del perfil del propietario autenticado.
///
/// Carga y actualiza `users/{uid}`. Las reglas de Firestore solo permiten que
/// el propio usuario cambie `fullName` y `phoneNumber`; el documento, el rol y
/// el estado los administra el panel de administración.
class OwnerProfileController extends ChangeNotifier {
  OwnerProfileController({
    UserProfileRepository? repository,
    String? Function()? currentUserId,
  }) : _repository = repository ?? FirestoreUserProfileRepository(),
       _currentUserId = currentUserId ?? (() => CurrentUser.uid);

  final UserProfileRepository _repository;
  final String? Function() _currentUserId;

  UserProfile? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  UserProfile? get profile => _profile;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

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
