import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/repositories/payment/payment_cloud_repository.dart';
import 'package:machuco/repositories/payment/payment_repository.dart';
import 'package:machuco/service/firebase/current_user.dart';

class PaymentCheckoutResult {
  const PaymentCheckoutResult({required this.payment, this.syncWarning});

  final PaymentRecord payment;

  /// Presente cuando el pago quedó guardado en el dispositivo pero no se pudo
  /// sincronizar con Firebase.
  final String? syncWarning;
}

/// Registra el pago de una reserva al finalizar la selección del método:
/// «En el Local» nace pendiente y sin método (lo confirma el propietario);
/// con tarjeta nace pagado con el método del maestro (crédito o débito).
class PaymentCheckoutController {
  PaymentCheckoutController({
    PaymentRepository? repository,
    PaymentCloudRepository? cloudRepository,
    Future<String?> Function(String motelId)? ownerIdForMotel,
    String? Function()? currentUserId,
    String? Function()? currentUserName,
    DateTime Function()? now,
  }) : _repository = repository ?? PaymentRepository(),
       _cloudRepository =
           cloudRepository ??
           (repository == null ? FirestorePaymentCloudRepository() : null),
       _ownerIdForMotel = ownerIdForMotel ?? _ownerIdFromMotelCatalog,
       _currentUserId = currentUserId ?? _firebaseUid,
       _currentUserName = currentUserName ?? _firebaseEmail,
       _now = now ?? DateTime.now;

  final PaymentRepository _repository;
  final PaymentCloudRepository? _cloudRepository;
  final Future<String?> Function(String motelId) _ownerIdForMotel;
  final String? Function() _currentUserId;
  final String? Function() _currentUserName;
  final DateTime Function() _now;

  Future<PaymentCheckoutResult> registerPendingLocalPayment(
    Reservation reservation,
  ) => _register(reservation, kind: null);

  Future<PaymentCheckoutResult> registerCardPayment(
    Reservation reservation, {
    required CardPaymentKind kind,
  }) => _register(reservation, kind: kind);

  Future<PaymentCheckoutResult> _register(
    Reservation reservation, {
    required CardPaymentKind? kind,
  }) async {
    final paymentId = 'pay-${reservation.id}';
    final method = kind == null ? null : await _findCardMethod(kind);

    final existing = await _repository.findPayment(paymentId);
    if (existing != null) {
      final sameOperation = method == null
          ? existing.status == PaymentStatus.pending
          : existing.status == PaymentStatus.paid &&
                existing.paymentMethodId == method.id;
      if (sameOperation) return PaymentCheckoutResult(payment: existing);
      throw const PaymentRepositoryException(
        PaymentRepositoryError.alreadyProcessed,
        'Esta reserva ya tiene un pago registrado.',
      );
    }

    final uid = _currentUserId();
    final clientId = uid ?? _nonBlank(reservation.guestId) ?? 'guest-$paymentId';
    final client =
        _nonBlank(reservation.guestName) ??
        _nonBlank(_currentUserName()) ??
        'Cliente';

    final payment = PaymentRecord(
      id: paymentId,
      bookingId: reservation.id,
      bookingReference: reservation.id,
      clientId: clientId,
      client: client,
      motelId: reservation.motelId,
      motel: reservation.motelName,
      roomId: reservation.roomId,
      room: 'Habitación ${reservation.roomNumber} · ${reservation.roomName}',
      reservationDate: reservation.checkIn,
      amount: reservation.total,
      status: method == null ? PaymentStatus.pending : PaymentStatus.paid,
      paymentMethodId: method?.id,
      paidAt: method == null ? null : _now(),
      receiptNumber: method == null ? null : 'CARD-$paymentId',
    );
    await _repository.createPayment(payment);

    return PaymentCheckoutResult(
      payment: payment,
      syncWarning: await _synchronize(
        payment,
        uid: uid,
        methodName: method?.name,
      ),
    );
  }

  Future<String?> _synchronize(
    PaymentRecord payment, {
    required String? uid,
    required String? methodName,
  }) async {
    final cloud = _cloudRepository;
    if (cloud == null) return null;
    if (uid == null) {
      return 'El pago quedó guardado en este dispositivo. Inicia sesión con '
          'Firebase para sincronizarlo.';
    }

    String? ownerId;
    try {
      ownerId = _nonBlank(await _ownerIdForMotel(payment.motelId));
    } catch (_) {
      ownerId = null;
    }
    if (ownerId == null) {
      return 'El pago quedó guardado en este dispositivo, pero no se encontró '
          'el propietario del motel para sincronizarlo.';
    }

    try {
      await cloud.savePayment(
        ownerId: ownerId,
        payment: payment,
        paymentMethodName: methodName,
      );
      return null;
    } on PaymentCloudRepositoryException catch (error) {
      return error.message;
    } catch (_) {
      return 'El pago quedó guardado en este dispositivo y no se pudo '
          'sincronizar con Firebase.';
    }
  }

  Future<({int id, String name})> _findCardMethod(CardPaymentKind kind) async {
    final keyword = kind == CardPaymentKind.credit ? 'credito' : 'debito';
    final methods = await _repository.findPaymentMethods();
    for (final entry in methods) {
      final normalized = entry.name
          .toLowerCase()
          .replaceAll('é', 'e')
          .replaceAll('í', 'i');
      if (normalized.contains('tarjeta') && normalized.contains(keyword)) {
        return (id: entry.id, name: entry.name);
      }
    }
    throw PaymentRepositoryException(
      PaymentRepositoryError.invalidCatalog,
      'El maestro de métodos de pago no tiene una opción de tarjeta de '
      '${kind == CardPaymentKind.credit ? 'crédito' : 'débito'}.',
    );
  }

  static String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static Future<String?> _ownerIdFromMotelCatalog(String motelId) async =>
      (await MotelController.persistent().getMotelById(motelId))?.ownerId;

  static String? _firebaseUid() {
    try {
      return CurrentUser.uid;
    } catch (_) {
      return null;
    }
  }

  static String? _firebaseEmail() {
    try {
      return CurrentUser.email;
    } catch (_) {
      return null;
    }
  }
}
