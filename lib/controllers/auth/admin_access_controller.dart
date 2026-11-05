import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/database/repository/auth/admin_access_repository.dart';
import 'package:machuco/models/auth/owner_approval_request.dart';

/// Aprobación de propietarios por parte de un administrador.
///
/// Ocultar estas pantallas a otros roles es solo UX: quien autoriza es
/// `firestore.rules` (solo un administrador activo puede cambiar el estado de
/// un propietario pendiente).
class AdminAccessController extends ChangeNotifier {
  AdminAccessController({required this._repository});

  final AdminAccessRepository _repository;

  List<OwnerApplication> _pendingOwners = const [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  List<OwnerApplication> get pendingOwners => List.unmodifiable(_pendingOwners);

  int get pendingCount => _pendingOwners.length;

  bool get isLoading => _isLoading;

  bool get isSubmitting => _isSubmitting;

  /// Último error legible (español) o `null`.
  String? get error => _error;

  /// Solicitud pendiente por uid, o `null` si ya no está en la lista.
  OwnerApplication? findPending(String uid) {
    for (final owner in _pendingOwners) {
      if (owner.uid == uid) return owner;
    }
    return null;
  }

  /// Carga (o reintenta cargar) las solicitudes pendientes.
  Future<void> loadPendingOwners() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _pendingOwners = await _repository.listPendingOwners();
    } on AdminAccessRepositoryException catch (e) {
      _error = e.message;
    } catch (e) {
      debugPrint('Error inesperado al cargar solicitudes: ${e.runtimeType}');
      _error = 'No pudimos cargar las solicitudes. Intenta nuevamente.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// `true` si se aprobó. Si falla, [error] explica el motivo.
  Future<bool> approveOwner(String uid) {
    return _submit(uid, () => _repository.approveOwner(uid));
  }

  /// `true` si se rechazó. [reason] se valida (10 a 300 caracteres).
  Future<bool> rejectOwner(String uid, {required String reason}) {
    final validation = AuthValidators.rejectionReason(reason);
    if (validation != null) {
      _error = validation;
      notifyListeners();
      return Future.value(false);
    }
    return _submit(uid, () => _repository.rejectOwner(uid, reason: reason));
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _submit(String uid, Future<void> Function() action) async {
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      _pendingOwners = [
        for (final owner in _pendingOwners)
          if (owner.uid != uid) owner,
      ];
      return true;
    } on AdminAccessRepositoryException catch (e) {
      _error = e.message;
      if (e.type == AdminAccessFailureType.alreadyHandled) {
        // Ya la atendió otro administrador: sale de la lista local.
        _pendingOwners = [
          for (final owner in _pendingOwners)
            if (owner.uid != uid) owner,
        ];
      }
      return false;
    } catch (e) {
      debugPrint('Error inesperado al atender solicitud: ${e.runtimeType}');
      _error = 'No pudimos completar la operación. Intenta nuevamente.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
