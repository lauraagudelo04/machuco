import 'package:floor/floor.dart';
import 'package:machuco/models/booking/reservation_entity.dart';
import 'package:machuco/models/booking/reservation_payment_terms.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_catalog_entry.dart';

class PaymentReservationException implements Exception {
  const PaymentReservationException(this.message);
  final String message;
}

@dao
abstract class PaymentDao {
  @Query('SELECT * FROM payments ORDER BY reservationDate DESC, id DESC')
  Future<List<PaymentRecord>> findAll();

  @Query('SELECT * FROM payments WHERE id = :id LIMIT 1')
  Future<PaymentRecord?> findById(String id);

  @Query(
    'SELECT * FROM payments WHERE clientId = :clientId '
    'ORDER BY reservationDate DESC, id DESC',
  )
  Future<List<PaymentRecord>> findByClient(String clientId);

  @Query(
    'SELECT * FROM payments WHERE motelId = :motelId '
    'ORDER BY reservationDate DESC, id DESC',
  )
  Future<List<PaymentRecord>> findByMotel(String motelId);

  /// Un ID repetido es un error; insertar no debe sobrescribir un pago pagado.
  @insert
  Future<void> insertPayment(PaymentRecord payment);

  @update
  Future<void> updatePayment(PaymentRecord payment);

  @Query('SELECT * FROM reservations WHERE id = :id LIMIT 1')
  Future<ReservationEntity?> findReservationForPayment(String id);

  @Query('UPDATE reservations SET paymentMethod = :place WHERE id = :id')
  Future<void> selectPaymentPlace(String id, String place);

  @Query(
    'UPDATE reservations SET status = :status, paymentMethod = :method, '
    "invoiceAccessStatus = 'pending' WHERE id = :id",
  )
  Future<void> updateReservationAfterReceipt(
    String id,
    String status,
    String method,
  );

  /// Both records change in one SQLite transaction, including on retry.
  @transaction
  Future<PaymentRecord> createPendingReservationPayment(
    PaymentRecord payment,
    int nowMilliseconds,
  ) async {
    final reservation = _validateReservation(
      payment,
      await findReservationForPayment(payment.bookingId),
    );
    if (reservation.status != 'pending') {
      throw const PaymentReservationException(
        'La reserva ya no está pendiente de pago.',
      );
    }
    if (reservation.paymentMethod != ReservationPaymentTerms.payAtProperty &&
        nowMilliseconds - reservation.createdAt >=
            ReservationPaymentTerms.checkoutTimeout.inMilliseconds) {
      throw const PaymentReservationException(
        'El tiempo para elegir el pago de esta reserva expiró.',
      );
    }
    final existing = await findById(payment.id);
    if (existing != null) {
      _validateReservation(existing, reservation);
      if (existing.status != PaymentStatus.pending) {
        throw const PaymentReservationException(
          'Esta reserva ya tiene un pago procesado.',
        );
      }
    } else {
      await insertPayment(payment);
    }
    await selectPaymentPlace(
      reservation.id,
      ReservationPaymentTerms.payAtProperty,
    );
    return existing ?? payment;
  }

  ReservationEntity _validateReservation(
    PaymentRecord payment,
    ReservationEntity? reservation,
  ) {
    if (reservation == null ||
        payment.id != ReservationPaymentTerms.paymentId(reservation.id) ||
        payment.bookingId != reservation.id ||
        payment.clientId != reservation.guestId ||
        payment.motelId != reservation.motelId ||
        payment.roomId != reservation.roomId ||
        payment.amount != reservation.total ||
        payment.reservationDate.millisecondsSinceEpoch != reservation.checkIn) {
      throw const PaymentReservationException(
        'El pago no corresponde a los datos de una reserva guardada. Actualiza las reservas.',
      );
    }
    return reservation;
  }

  /// Retira fixtures históricos que llegaron a SQLite antes de habilitar la
  /// sincronización real. No coincide con IDs UUID de pagos reales.
  @Query(
    "DELETE FROM payments WHERE id IN ('pay-001', 'pay-002', 'pay-003', "
    "'owner-pay-001', 'owner-pay-002', 'owner-pay-003')",
  )
  Future<void> deleteLegacyDemoPayments();

  @Query('SELECT * FROM payment_method_catalog ORDER BY id')
  Future<List<PaymentCatalogEntry>> findCatalogEntries();

  @Insert(onConflict: OnConflictStrategy.ignore)
  Future<void> insertCatalogEntries(List<PaymentCatalogEntry> entries);

  @update
  Future<void> updateCatalogEntries(List<PaymentCatalogEntry> entries);

  /// Actualiza nombres sin REPLACE ni borrar métodos referenciados por pagos.
  @transaction
  Future<void> saveCatalogEntries(List<PaymentCatalogEntry> entries) async {
    await insertCatalogEntries(entries);
    await updateCatalogEntries(entries);
  }

  /// Confirma la recepción, no procesa un cobro bancario.
  /// Una sola sentencia impide que dos confirmaciones modifiquen el mismo pago.
  @Query(
    "UPDATE payments SET status = 'paid', method = NULL, "
    'paymentMethodId = :paymentMethodId, paidAt = :paidAt, '
    'receiptNumber = :receiptNumber '
    "WHERE id = :id AND motelId = :motelId AND status = 'pending' "
    'AND EXISTS (SELECT 1 FROM payment_method_catalog '
    'WHERE id = :paymentMethodId)',
  )
  Future<void> updatePendingPayment(
    String id,
    String motelId,
    int paymentMethodId,
    DateTime paidAt,
    String receiptNumber,
  );

  @Query('SELECT changes()')
  Future<int?> findAffectedRows();

  /// Lee changes() en la misma transacción que el UPDATE para obtener un
  /// resultado fiable incluso si llegan dos confirmaciones simultáneas.
  @transaction
  Future<int> registerLocalPayment(
    String id,
    String motelId,
    int paymentMethodId,
    DateTime paidAt,
    String receiptNumber,
  ) async {
    final payment = await findById(id);
    ReservationEntity? linkedReservation;
    if (payment != null &&
        payment.id == ReservationPaymentTerms.paymentId(payment.bookingId)) {
      final reservation = _validateReservation(
        payment,
        await findReservationForPayment(payment.bookingId),
      );
      linkedReservation = reservation;
      if (reservation.status != 'pending' ||
          reservation.paymentMethod != ReservationPaymentTerms.payAtProperty) {
        throw const PaymentReservationException(
          'La reserva no admite recibir este pago. Actualiza las reservas.',
        );
      }
    }
    await updatePendingPayment(
      id,
      motelId,
      paymentMethodId,
      paidAt,
      receiptNumber,
    );
    final changed = await findAffectedRows() ?? 0;
    if (changed == 1 && linkedReservation != null) {
      final catalog = await findCatalogEntries();
      final method = catalog.firstWhere((entry) => entry.id == paymentMethodId);
      await updateReservationAfterReceipt(
        linkedReservation.id,
        paidAt.millisecondsSinceEpoch >= linkedReservation.checkIn
            ? 'active'
            : 'upcoming',
        method.name,
      );
    }
    return changed;
  }

  /// Imports cloud records without letting an older pending copy regress a
  /// payment that was already processed on this device.
  @transaction
  Future<void> mergeRemotePayments(List<PaymentRecord> payments) async {
    for (final remote in payments) {
      final local = await findById(remote.id);
      if (local == null) {
        await insertPayment(remote);
      } else if (_acceptRemoteStatus(local.status, remote.status)) {
        await updatePayment(remote);
      }
      final saved = await findById(remote.id);
      if (saved == null ||
          saved.status != PaymentStatus.paid ||
          saved.paidAt == null ||
          saved.id != ReservationPaymentTerms.paymentId(saved.bookingId)) {
        continue;
      }
      final reservation = await findReservationForPayment(saved.bookingId);
      if (reservation == null || reservation.status != 'pending') continue;
      _validateReservation(saved, reservation);
      final methods = await findCatalogEntries();
      for (final method in methods) {
        if (method.id != saved.paymentMethodId) continue;
        await updateReservationAfterReceipt(
          reservation.id,
          saved.paidAt!.millisecondsSinceEpoch >= reservation.checkIn
              ? 'active'
              : 'upcoming',
          method.name,
        );
      }
    }
  }

  bool _acceptRemoteStatus(PaymentStatus local, PaymentStatus remote) {
    if (local == remote) return true;
    if (local == PaymentStatus.pending) return true;
    return local == PaymentStatus.paid && remote == PaymentStatus.refunded;
  }
}
