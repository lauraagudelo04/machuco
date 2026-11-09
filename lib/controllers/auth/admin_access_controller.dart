import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/auth/validators/auth_input_normalizer.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/database/repository/auth/admin_access_repository.dart';
import 'package:machuco/models/auth/owner_approval_request.dart';
import 'package:machuco/models/auth/owner_request_alert.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';

/// Aprobación de propietarios por parte de un administrador.
///
/// Ocultar estas pantallas a otros roles es solo UX: quien autoriza es
/// `firestore.rules` (solo un administrador activo puede cambiar el estado de
/// un propietario pendiente).
class AdminAccessController extends ChangeNotifier {
  /// [loadPlans] devuelve los planes activos del catálogo (p. ej.
  /// `AuthCatalogRepository.getSubscriptionPlans`); sin él, la alerta de plan
  /// no se puede comprobar y se informa como tal.
  AdminAccessController({required this._repository, this._loadPlans});

  final AdminAccessRepository _repository;
  final Future<List<SubscriptionPlanOption>> Function()? _loadPlans;

  List<OwnerApplication> _pendingOwners = const [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  final Map<String, OwnerRequestAlerts> _alerts = {};
  final Set<String> _checkingAlerts = {};

  List<OwnerApplication> get pendingOwners => List.unmodifiable(_pendingOwners);

  int get pendingCount => _pendingOwners.length;

  bool get isLoading => _isLoading;

  bool get isSubmitting => _isSubmitting;

  /// Último error legible (español) o `null`.
  String? get error => _error;

  /// Alertas ya calculadas de la solicitud [uid], o `null` si aún no se
  /// comprueban (ver [loadAlerts]).
  OwnerRequestAlerts? alertsFor(String uid) => _alerts[uid];

  /// `true` mientras se comprueban las alertas de [uid].
  bool isCheckingAlerts(String uid) => _checkingAlerts.contains(uid);

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

  /// Comprueba el dígito de verificación del NIT, si otro propietario ya usa
  /// ese NIT y si el plan de interés sigue disponible. Solo informa: nunca
  /// bloquea [approveOwner]. Una comprobación que falla por red se informa
  /// como [OwnerRequestAlertType.verificationUnavailable]. Si ya hay una en
  /// curso para [application], no hace nada.
  Future<OwnerRequestAlerts> loadAlerts(OwnerApplication application) async {
    final uid = application.uid;
    if (_checkingAlerts.contains(uid)) {
      return _alerts[uid] ?? OwnerRequestAlerts.none;
    }
    _checkingAlerts.add(uid);
    notifyListeners();
    try {
      final alerts = <OwnerRequestAlert>[
        ?_nitCheckDigitAlert(application.nit),
        ?await _duplicateNitAlert(application),
        ?await _planAlert(application.planId),
      ];
      final result = OwnerRequestAlerts(List.unmodifiable(alerts));
      _alerts[uid] = result;
      return result;
    } finally {
      _checkingAlerts.remove(uid);
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

  // ---------------------------------------------------------------- alertas

  OwnerRequestAlert? _nitCheckDigitAlert(String? nit) {
    final canonical = AuthInputNormalizer.nit(nit);
    final match = canonical == null
        ? null
        : RegExp(r'^(\d+)-(\d)$').firstMatch(canonical);
    if (match == null) {
      return const OwnerRequestAlert(
        OwnerRequestAlertType.invalidNitCheckDigit,
        'El NIT no tiene un formato reconocible.',
      );
    }
    final base = match.group(1) ?? '';
    final check = int.parse(match.group(2) ?? '0');
    if (AuthValidators.nitCheckDigit(base) == check) return null;
    return const OwnerRequestAlert(
      OwnerRequestAlertType.invalidNitCheckDigit,
      'El dígito de verificación del NIT no es válido.',
    );
  }

  Future<OwnerRequestAlert?> _duplicateNitAlert(
    OwnerApplication application,
  ) async {
    final nit = AuthInputNormalizer.nit(application.nit);
    if (nit == null) return null;
    try {
      final used = await _repository.isNitUsedByAnotherOwner(
        nit: nit,
        excludeUid: application.uid,
      );
      return used
          ? const OwnerRequestAlert(
              OwnerRequestAlertType.duplicateNit,
              'Este NIT ya está registrado en otra cuenta de propietario.',
            )
          : null;
    } catch (e) {
      debugPrint('No se pudo comprobar el NIT duplicado: ${e.runtimeType}');
      return const OwnerRequestAlert(
        OwnerRequestAlertType.verificationUnavailable,
        'No pudimos comprobar si el NIT ya está registrado.',
      );
    }
  }

  Future<OwnerRequestAlert?> _planAlert(int? planId) async {
    if (planId == null) {
      return const OwnerRequestAlert(
        OwnerRequestAlertType.planNotAvailable,
        'La solicitud no indica un plan de suscripción.',
      );
    }
    final loadPlans = _loadPlans;
    if (loadPlans == null) {
      return const OwnerRequestAlert(
        OwnerRequestAlertType.verificationUnavailable,
        'No pudimos comprobar si el plan sigue disponible.',
      );
    }
    try {
      final plans = await loadPlans();
      return plans.any((plan) => plan.id == planId)
          ? null
          : const OwnerRequestAlert(
              OwnerRequestAlertType.planNotAvailable,
              'El plan elegido ya no está disponible.',
            );
    } catch (e) {
      debugPrint('No se pudo comprobar el plan: ${e.runtimeType}');
      return const OwnerRequestAlert(
        OwnerRequestAlertType.verificationUnavailable,
        'No pudimos comprobar si el plan sigue disponible.',
      );
    }
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
