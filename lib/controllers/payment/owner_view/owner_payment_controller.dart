import 'dart:async';

import 'package:flutter/foundation.dart';
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

  List<PaymentRecord> get payments => List.unmodifiable(_payments);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String? get syncWarningMessage => _syncWarningMessage;

  List<PaymentRecord> get pendingPayments => List.unmodifiable(
    payments.where((payment) => payment.status == PaymentStatus.pending),
  );

  List<PaymentRecord> get completedPayments => List.unmodifiable(
    payments.where((payment) => payment.status == PaymentStatus.paid),
  );

  List<PaymentRecord> get otherPayments => List.unmodifiable(
    payments.where(
      (payment) =>
          payment.status == PaymentStatus.cancelled ||
          payment.status == PaymentStatus.refunded,
    ),
  );

  int get pendingAmount =>
      pendingPayments.fold(0, (total, payment) => total + payment.amount);

  int get totalIncome =>
      completedPayments.fold(0, (total, payment) => total + payment.amount);

  int get paymentsReceived => completedPayments.length;

  List<FrequentClient> get frequentClients {
    final clients = <String, List<PaymentRecord>>{};
    for (final payment in payments) {
      if (payment.status == PaymentStatus.cancelled) continue;
      (clients[payment.clientId] ??= []).add(payment);
    }
    final summaries = clients.entries.map((entry) {
      final records = entry.value;
      final name = records.first.client;
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
    if (localLoaded) await _synchronizeWithCloud();
  }

  Future<List<PaymentCatalogEntry>> loadPaymentMethods() async {
    final methods = await _repository.findPaymentMethods();
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
    if (ownerId == null || ownerId.trim().isEmpty) {
      _syncWarningMessage =
          'Inicia sesión con Firebase para sincronizar los pagos.';
      _notify();
      return;
    }

    _isSyncing = true;
    _syncWarningMessage = null;
    _notify();
    try {
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
      final remote = await cloud.listForOwnerAndMotel(
        ownerId: ownerId,
        motelId: motelId,
      );
      await _repository.mergeRemotePayments(motelId: motelId, payments: remote);
      final local = await _repository.findPaymentsByMotel(motelId);
      if (!_disposed) _payments = local;
      final remoteById = {for (final payment in remote) payment.id: payment};
      for (final payment in local) {
        if (remoteById[payment.id]?.status == payment.status &&
            payment.status != PaymentStatus.paid) {
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
    } on PaymentCloudRepositoryException catch (error) {
      _syncWarningMessage = error.message;
    } on PaymentRepositoryException catch (error) {
      _syncWarningMessage =
          'Los pagos están en Firebase, pero no se pudieron actualizar en '
          'este dispositivo: ${error.message}';
    } catch (_) {
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
    } on PaymentCloudRepositoryException catch (error) {
      _syncWarningMessage = error.message;
    } catch (_) {
      _syncWarningMessage =
          'El pago quedó guardado localmente y se sincronizará al reintentar.';
    } finally {
      _isSyncing = false;
      _notify();
    }
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
    super.dispose();
  }
}
