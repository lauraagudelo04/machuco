import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_catalog_entry.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/repositories/payment/payment_repository.dart';
import 'package:machuco/repositories/payment/payment_cloud_repository.dart';
import 'package:machuco/service/firebase/current_user.dart';

class OwnerPaymentController extends ChangeNotifier {
  OwnerPaymentController({
    required this.motelId,
    PaymentRepository? repository,
    PaymentCloudRepository? cloudRepository,
    String? Function()? currentUserId,
    Future<void> Function()? refreshReservations,
  }) : _repository = repository ?? PaymentRepository(),
       _cloudRepository =
           cloudRepository ??
           (repository == null ? FirestorePaymentCloudRepository() : null),
       _currentUserId = currentUserId ?? (() => CurrentUser.uid),
       _refreshReservations =
           refreshReservations ??
           (repository == null
               ? () async {
                   await BookingRepositoryProvider.instance.getAll();
                 }
               : null) {
    ready = load();
  }

  final String motelId;
  final PaymentRepository _repository;
  final PaymentCloudRepository? _cloudRepository;
  final String? Function() _currentUserId;
  final Future<void> Function()? _refreshReservations;
  late final Future<void> ready;
  List<PaymentRecord> _payments = [];
  final Map<int, String> _methodNames = {};
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isSyncing = false;
  bool _disposed = false;
  String? _errorMessage;
  String? _syncWarningMessage;
  List<PaymentRecord>? _confirmedPayments;
  final Map<String, String> _remoteMethodNames = {};
  StreamSubscription<PaymentCloudSnapshot>? _cloudSubscription;
  Future<void> _pendingSnapshot = Future.value();
  String? _watchOwnerId;
  bool _isFinanceCurrent = false;
  DateTime? _lastFinanceUpdate;
  String? _financeOwnerId;
  String? _watchWarningMessage;
  final Map<String, String> _clientNames = {};
  final Set<String> _loadingClientNames = {};

  String clientName(PaymentRecord payment) {
    final name = _clientNames[payment.clientId] ?? payment.client.trim();
    return name.isNotEmpty && !name.contains('@')
        ? name
        : 'Nombre no disponible';
  }

  Future<void> _loadClientName(String clientId, String ownerId) async {
    if (_clientNames.containsKey(clientId) ||
        !_loadingClientNames.add(clientId))
      return;
    try {
      final profile = await FirestoreUserProfileRepository()
          .getProfile(clientId)
          .timeout(const Duration(seconds: 10));
      if (_disposed || _currentUserId() != ownerId) return;
      final name = profile?.fullName.trim();
      if (name != null && name.isNotEmpty && !name.contains('@')) {
        _clientNames[clientId] = name;
        _notify();
      }
    } catch (_) {
      debugPrint('No se pudo consultar el nombre del cliente de los pagos.');
    } finally {
      _loadingClientNames.remove(clientId);
    }
  }

  List<PaymentRecord> get payments {
    final confirmedIds = _confirmedPayments
        ?.map((payment) => payment.id)
        .toSet();
    final records = {
      for (final payment in _payments)
        if (confirmedIds == null || confirmedIds.contains(payment.id))
          payment.id: payment,
    };
    for (final remote in _confirmedPayments ?? const <PaymentRecord>[]) {
      final local = records[remote.id];
      // Preserve a durable local receipt while the server still has a pending
      // copy. Other confirmed remote transitions (including refunds) win.
      if (local != null &&
          local.status != PaymentStatus.pending &&
          remote.status == PaymentStatus.pending) {
        continue;
      }
      records[remote.id] = remote;
    }
    final result = records.values.toList()
      ..sort((first, second) {
        final date = second.reservationDate.compareTo(first.reservationDate);
        return date == 0 ? second.id.compareTo(first.id) : date;
      });
    return List.unmodifiable(result);
  }

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String? get syncWarningMessage => _syncWarningMessage ?? _watchWarningMessage;
  bool get usesFirebase => _cloudRepository != null;
  bool get hasFinanceSnapshot => !usesFirebase || _confirmedPayments != null;
  bool get isFinanceCurrent => _isFinanceCurrent;
  DateTime? get lastFinanceUpdate => _lastFinanceUpdate;

  List<PaymentRecord> get _financePayments =>
      usesFirebase ? _confirmedPayments ?? const [] : _payments;

  bool isPaymentConfirmed(PaymentRecord payment) {
    if (!usesFirebase) return true;
    return _confirmedPayments?.any(
          (remote) =>
              remote.id == payment.id &&
              remote.status == payment.status &&
              remote.amount == payment.amount &&
              remote.paymentMethodId == payment.paymentMethodId &&
              remote.paidAt == payment.paidAt &&
              remote.receiptNumber == payment.receiptNumber &&
              remote.cancellationActor == payment.cancellationActor,
        ) ??
        false;
  }

  int get unconfirmedPayments =>
      usesFirebase ? payments.where((p) => !isPaymentConfirmed(p)).length : 0;

  List<PaymentRecord> get pendingPayments => List.unmodifiable(
    payments.where((payment) => payment.status == PaymentStatus.pending),
  );

  List<PaymentRecord> get completedPayments => List.unmodifiable(
    payments.where(
      (payment) =>
          payment.status == PaymentStatus.paid ||
          (payment.cancellationActor == 'owner' &&
              (payment.status == PaymentStatus.refunded ||
                  payment.status == PaymentStatus.cancelled)),
    ),
  );

  List<PaymentRecord> get otherPayments => List.unmodifiable(
    payments.where(
      (payment) =>
          payment.cancellationActor != 'owner' &&
          (payment.status == PaymentStatus.cancelled ||
              payment.status == PaymentStatus.refunded),
    ),
  );

  int get pendingAmount => _financePayments
      .where((payment) => payment.status == PaymentStatus.pending)
      .fold(0, (total, payment) => total + payment.amount);

  int get totalIncome => _financePayments
      .where((payment) => payment.status == PaymentStatus.paid)
      .fold(0, (total, payment) => total + payment.amount);

  int get paymentsReceived => _financePayments
      .where((payment) => payment.status == PaymentStatus.paid)
      .length;

  int get refundedAmount => _financePayments
      .where((payment) => payment.status == PaymentStatus.refunded)
      .fold(0, (total, payment) => total + payment.amount);

  List<FrequentClient> get frequentClients {
    final clients = <String, List<PaymentRecord>>{};
    for (final payment in _financePayments) {
      if (payment.status == PaymentStatus.cancelled) continue;
      (clients[payment.clientId] ??= []).add(payment);
    }
    final summaries = clients.entries.map((entry) {
      final records = entry.value;
      final name = clientName(records.first);
      final initials = name
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .take(2)
          .map((part) => String.fromCharCode(part.runes.first))
          .join()
          .toUpperCase();
      return FrequentClient(
        clientId: entry.key,
        motelId: motelId,
        name: name,
        initials: initials,
        reservations: records
            .map((payment) => payment.bookingId)
            .toSet()
            .length,
        totalPaid: records
            .where((payment) => payment.status == PaymentStatus.paid)
            .fold(0, (total, payment) => total + payment.amount),
      );
    }).toList();
    summaries.sort((first, second) {
      final count = second.reservations.compareTo(first.reservations);
      return count == 0 ? first.name.compareTo(second.name) : count;
    });
    return List.unmodifiable(summaries);
  }

  String methodName(PaymentRecord payment) {
    final remoteName = _remoteMethodNames[payment.id];
    if (remoteName != null && isPaymentConfirmed(payment)) return remoteName;
    final methodId = payment.paymentMethodId;
    if (methodId != null) return _methodNames[methodId] ?? 'Método #$methodId';
    return switch (payment.method) {
      PaymentMethod.cash => 'Efectivo',
      PaymentMethod.online => 'Pago en línea',
      null => 'Sin método registrado',
    };
  }

  Future<void> load() async {
    if (_isLoading || _isSaving || _isSyncing || _disposed) return;
    _isLoading = true;
    _errorMessage = null;
    var localLoaded = false;
    _notify();
    try {
      await _repository.deleteLegacyDemoPayments();
      final payments = await _repository.findPaymentsByMotel(motelId);
      final methods = await _repository.findCachedPaymentMethods();
      if (_disposed) return;
      _payments = payments;
      _methodNames.addEntries(
        methods.map((entry) => MapEntry(entry.id, entry.name)),
      );
      localLoaded = true;
    } on PaymentRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage =
          'No se pudieron cargar los pagos del motel. Inténtalo nuevamente.';
    } finally {
      _isLoading = false;
      _notify();
    }
    if (localLoaded || usesFirebase) await _synchronizeWithCloud();
    if (!_disposed && usesFirebase && hasFinanceSnapshot && !localLoaded) {
      _syncWarningMessage ??=
          'El resumen de Firebase está disponible, pero no se pudo leer '
          'la copia local. Actualiza para reintentar.';
      _errorMessage = null;
      _notify();
    }
  }

  Future<List<PaymentCatalogEntry>> loadPaymentMethods() async {
    final methods = await _repository.findPaymentMethods();
    final confirmed = _confirmedPayments;
    if (confirmed != null) {
      // A fresh device may have no catalog when the first remote payment
      // arrives. Import it after Supabase has supplied its foreign-key entries.
      await _repository.mergeRemotePayments(
        motelId: motelId,
        payments: confirmed,
      );
    }
    if (!_disposed) {
      _methodNames.addEntries(
        methods.map((entry) => MapEntry(entry.id, entry.name)),
      );
      _notify();
    }
    return methods;
  }

  Future<PaymentRecord> registerLocalPayment({
    required String paymentId,
    required int paymentMethodId,
  }) async {
    if (_isLoading || _isSaving || _isSyncing || _disposed) {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.invalidPayment,
        'Espera a que termine la operación de pagos actual.',
      );
    }
    _isSaving = true;
    _notify();
    try {
      final saved = await _repository.registerLocalPayment(
        paymentId: paymentId,
        motelId: motelId,
        paymentMethodId: paymentMethodId,
      );
      if (!_disposed) {
        _payments = [
          for (final payment in _payments)
            if (payment.id == saved.id) saved else payment,
        ];
      }
      unawaited(_synchronizePayment(saved));
      return saved;
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  Future<void> _synchronizeWithCloud() async {
    final cloud = _cloudRepository;
    if (cloud == null || _disposed) return;
    final ownerId = _currentUserId();
    if (_financeOwnerId != ownerId) {
      _clientNames.clear();
      await _cloudSubscription?.cancel();
      _cloudSubscription = null;
      _watchOwnerId = null;
      _confirmedPayments = null;
      _remoteMethodNames.clear();
      _isFinanceCurrent = false;
      _lastFinanceUpdate = null;
      _watchWarningMessage = null;
      _financeOwnerId = ownerId;
    }
    if (ownerId == null || ownerId.trim().isEmpty) {
      await _cloudSubscription?.cancel();
      _cloudSubscription = null;
      _watchOwnerId = null;
      _confirmedPayments = null;
      _remoteMethodNames.clear();
      _isFinanceCurrent = false;
      _syncWarningMessage =
          'Inicia sesión con Firebase para sincronizar los pagos.';
      _notify();
      return;
    }

    _isSyncing = true;
    _syncWarningMessage = null;
    _notify();
    try {
      // Confirm the summary from the server before touching local dependencies.
      // A missing Supabase catalog must not hide real Firebase balances.
      final remote = PaymentCloudSnapshot(
        payments: await cloud.listForOwnerAndMotel(
          ownerId: ownerId,
          motelId: motelId,
        ),
      ).payments;
      if (_disposed || _currentUserId() != ownerId) return;
      _acceptFinanceSnapshot(remote);
      _startWatching(ownerId);
      try {
        final methods = await _repository.findPaymentMethods();
        _methodNames.addEntries(
          methods.map((entry) => MapEntry(entry.id, entry.name)),
        );
      } on PaymentRepositoryException {
        // La caché existente sigue siendo válida; Firebase se reintenta sin
        // convertir un fallo del maestro en pérdida de los pagos locales.
      }
      await _refreshReservations?.call();
      // Pull first: a stale pending copy must not stop the whole upload loop
      // or overwrite a receipt already confirmed on another device.
      await _repository.mergeRemotePayments(motelId: motelId, payments: remote);
      final local = await _repository.findPaymentsByMotel(motelId);
      if (!_disposed) _payments = local;
      final remoteById = {for (final payment in remote) payment.id: payment};
      for (final payment in local) {
        final remotePayment = remoteById[payment.id];
        // A missing document may have been deleted deliberately in Firebase.
        // Never recreate it from SQLite while refreshing this screen.
        if (remotePayment == null || remotePayment.status == payment.status) {
          continue;
        }
        await cloud.savePayment(
          ownerId: ownerId,
          payment: payment,
          paymentMethodName: _paymentMethodNameForCloud(payment),
        );
      }
      final merged = await _repository.findPaymentsByMotel(motelId);
      if (!_disposed) _payments = merged;
      final confirmed = await cloud.listForOwnerAndMotel(
        ownerId: ownerId,
        motelId: motelId,
      );
      if (!_disposed && _currentUserId() == ownerId) {
        _acceptFinanceSnapshot(confirmed);
      }
    } on PaymentCloudRepositoryException catch (error) {
      _isFinanceCurrent = false;
      _syncWarningMessage = error.message;
    } on PaymentRepositoryException catch (error) {
      _syncWarningMessage =
          'Los pagos están en Firebase, pero no se pudieron actualizar en '
          'este dispositivo: ${error.message}';
    } catch (_) {
      _isFinanceCurrent = false;
      _syncWarningMessage =
          'Los pagos locales están disponibles, pero no se pudieron '
          'sincronizar con Firebase.';
    } finally {
      _isSyncing = false;
      _notify();
    }
  }

  Future<void> _synchronizePayment(PaymentRecord payment) async {
    final cloud = _cloudRepository;
    if (cloud == null || _disposed) return;
    final ownerId = _currentUserId();
    if (ownerId == null || ownerId.trim().isEmpty) {
      _syncWarningMessage =
          'El pago quedó guardado localmente. Inicia sesión para sincronizarlo.';
      _notify();
      return;
    }
    _isSyncing = true;
    _syncWarningMessage = null;
    _notify();
    try {
      await cloud.savePayment(
        ownerId: ownerId,
        payment: payment,
        paymentMethodName: _paymentMethodNameForCloud(payment),
      );
      final confirmed = await cloud.listForOwnerAndMotel(
        ownerId: ownerId,
        motelId: motelId,
      );
      if (!_disposed && _currentUserId() == ownerId) {
        _acceptFinanceSnapshot(confirmed);
      }
    } on PaymentCloudRepositoryException catch (error) {
      _isFinanceCurrent = false;
      _syncWarningMessage = error.message;
    } catch (_) {
      _isFinanceCurrent = false;
      _syncWarningMessage =
          'El pago quedó guardado localmente y se sincronizará al reintentar.';
    } finally {
      _isSyncing = false;
      _notify();
    }
  }

  void _acceptFinanceSnapshot(List<PaymentRecord> payments) {
    payments = PaymentCloudSnapshot(payments: payments).payments;
    if (payments.any((payment) => payment.motelId != motelId) ||
        payments.map((payment) => payment.id).toSet().length !=
            payments.length) {
      throw const PaymentCloudRepositoryException(
        PaymentCloudFailureType.invalidData,
        'Firebase devolvió pagos fuera del motel o duplicados.',
      );
    }
    _confirmedPayments = List.unmodifiable(payments);
    _isFinanceCurrent = true;
    _lastFinanceUpdate = DateTime.now();
    final ownerId = _currentUserId();
    if (ownerId != null && CurrentUser.uidOrNull != null) {
      for (final id in payments.map((payment) => payment.clientId).toSet()) {
        unawaited(_loadClientName(id, ownerId));
      }
    }
    _notify();
  }

  void _startWatching(String ownerId) {
    final cloud = _cloudRepository;
    if (cloud == null || cloud is! PaymentCloudWatchRepository || _disposed) {
      return;
    }
    final watcher = cloud as PaymentCloudWatchRepository;
    if (_watchOwnerId == ownerId && _cloudSubscription != null) return;
    unawaited(_cloudSubscription?.cancel());
    _watchOwnerId = ownerId;
    _cloudSubscription = watcher
        .watchForOwnerAndMotel(ownerId: ownerId, motelId: motelId)
        .listen(
          (snapshot) {
            // Serialize cache imports so an older event cannot win a race.
            _pendingSnapshot = _pendingSnapshot.then(
              (_) => _applyCloudSnapshot(ownerId, snapshot),
            );
          },
          onError: (Object error) {
            if (_disposed || _currentUserId() != ownerId) return;
            _isFinanceCurrent = false;
            _watchWarningMessage = error is PaymentCloudRepositoryException
                ? error.message
                : 'No se pudieron actualizar los pagos en tiempo real.';
            _notify();
          },
          onDone: () {
            _cloudSubscription = null;
            _watchOwnerId = null;
          },
        );
  }

  Future<void> _applyCloudSnapshot(
    String ownerId,
    PaymentCloudSnapshot snapshot,
  ) async {
    if (_disposed || _currentUserId() != ownerId) return;
    if (!snapshot.isConfirmed) {
      _isFinanceCurrent = false;
      _notify();
      return;
    }
    try {
      _acceptFinanceSnapshot(snapshot.payments);
      _watchWarningMessage = null;
      _remoteMethodNames
        ..clear()
        ..addAll(snapshot.methodNames);
      await _repository.mergeRemotePayments(
        motelId: motelId,
        payments: snapshot.payments,
      );
      final local = await _repository.findPaymentsByMotel(motelId);
      if (_disposed || _currentUserId() != ownerId) return;
      _payments = local;
    } on PaymentCloudRepositoryException catch (error) {
      _isFinanceCurrent = false;
      _syncWarningMessage = error.message;
    } catch (_) {
      _syncWarningMessage =
          'El resumen de Firebase está disponible, pero no se pudo actualizar '
          'la copia local. Actualiza para reintentar.';
    }
    _notify();
  }

  String? _paymentMethodNameForCloud(PaymentRecord payment) {
    final methodId = payment.paymentMethodId;
    if (methodId != null) return _methodNames[methodId];
    return switch (payment.method) {
      PaymentMethod.cash => 'Efectivo',
      PaymentMethod.online => 'Pago en línea',
      null => null,
    };
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_cloudSubscription?.cancel());
    super.dispose();
  }
}
