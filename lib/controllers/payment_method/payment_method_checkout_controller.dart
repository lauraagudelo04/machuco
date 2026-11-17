import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_payment_terms.dart';
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

/// Real checkout: only an authenticated client's pay-at-property request.
/// The card form remains a sandbox and cannot create receipts.
class PaymentCheckoutController {
  PaymentCheckoutController({
    PaymentRepository? repository,
    PaymentCloudRepository? cloudRepository,
    Future<String?> Function(String motelId)? ownerIdForMotel,
    String? Function()? currentUserId,
    String? Function()? currentUserName,
  }) : _repository = repository ?? PaymentRepository(),
       _cloudRepository =
           cloudRepository ??
           (repository == null ? FirestorePaymentCloudRepository() : null),
       _ownerIdForMotel = ownerIdForMotel ?? _ownerIdFromMotelCatalog,
       _currentUserId = currentUserId ?? _firebaseUid,
       _currentUserName = currentUserName ?? _firebaseEmail;

  final PaymentRepository _repository;
  final PaymentCloudRepository? _cloudRepository;
  final Future<String?> Function(String motelId) _ownerIdForMotel;
  final String? Function() _currentUserId;
  final String? Function() _currentUserName;

  Future<PaymentCheckoutResult> registerPendingLocalPayment(
    Reservation reservation,
  ) => _register(reservation);

  Future<PaymentCheckoutResult> registerCardPayment(
    Reservation reservation, {
    required CardPaymentKind kind,
  }) async => throw const PaymentRepositoryException(
    PaymentRepositoryError.invalidPayment,
    'Tarjeta es una simulación: no se ha realizado un cobro. '
    'Elige «En el Local» para registrar una reserva real.',
  );

  Future<PaymentCheckoutResult> _register(Reservation reservation) async {
    final paymentId = ReservationPaymentTerms.paymentId(reservation.id);
    final uid = _currentUserId();
    if (uid == null || uid.trim().isEmpty || reservation.guestId != uid) {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.invalidPayment,
        'Inicia sesión con la cuenta que creó esta reserva para elegir el pago.',
      );
    }
    final client =
        _nonBlank(reservation.guestName) ??
        _nonBlank(_currentUserName()) ??
        'Cliente';

    final payment = PaymentRecord(
      id: paymentId,
      bookingId: reservation.id,
      bookingReference: reservation.requestId,
      clientId: uid,
      client: client,
      motelId: reservation.motelId,
      motel: reservation.motelName,
      roomId: reservation.roomId,
      room: 'Habitación ${reservation.roomNumber} · ${reservation.roomName}',
      reservationDate: reservation.checkIn,
      amount: reservation.total,
      status: PaymentStatus.pending,
    );
    final saved = await _repository.createPendingReservationPayment(payment);

    return PaymentCheckoutResult(
      payment: saved,
      syncWarning: await _synchronize(saved, uid: uid, methodName: null),
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
