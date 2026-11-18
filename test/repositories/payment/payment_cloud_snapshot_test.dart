import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/repositories/payment/payment_cloud_repository.dart';

void main() {
  PaymentRecord payment(String id) => PaymentRecord(
    id: id,
    bookingId: 'booking-$id',
    bookingReference: 'RES-$id',
    clientId: 'client-1',
    client: 'Cliente de prueba',
    motelId: 'motel-1',
    motel: 'Motel de prueba',
    roomId: 'room-1',
    room: 'Habitación 1',
    reservationDate: DateTime.utc(2026, 11, 17),
    amount: 80000,
    status: PaymentStatus.pending,
  );

  test(
    'solo una respuesta de servidor sin escrituras pendientes es confirmada',
    () {
      expect(PaymentCloudSnapshot(payments: []).isConfirmed, isTrue);
      expect(
        PaymentCloudSnapshot(payments: [], isFromCache: true).isConfirmed,
        isFalse,
      );
      expect(
        PaymentCloudSnapshot(payments: [], hasPendingWrites: true).isConfirmed,
        isFalse,
      );
    },
  );

  test('excluye únicamente los seis fixtures históricos, no pagos reales', () {
    final snapshot = PaymentCloudSnapshot(
      payments: [
        for (final id in PaymentCloudSnapshot.legacyDemoIds) payment(id),
        payment('pay-real-reservation'),
        payment('uuid-existing-payment'),
      ],
    );
    expect(snapshot.payments.map((payment) => payment.id), [
      'pay-real-reservation',
      'uuid-existing-payment',
    ]);
  });

  test('conserva una copia inmutable de los pagos y sus nombres remotos', () {
    final records = [payment('real')];
    final names = {'real': 'Transferencia bancaria'};
    final snapshot = PaymentCloudSnapshot(
      payments: records,
      methodNames: names,
    );
    records.clear();
    names.clear();

    expect(snapshot.payments.single.id, 'real');
    expect(snapshot.methodNames['real'], 'Transferencia bancaria');
    expect(() => snapshot.payments.clear(), throwsUnsupportedError);
    expect(() => snapshot.methodNames.clear(), throwsUnsupportedError);
  });
}
