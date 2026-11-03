import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_firestore_document.dart';

void main() {
  PaymentRecord payment({PaymentStatus status = PaymentStatus.paid}) =>
      PaymentRecord(
        id: 'pay-1',
        bookingId: 'booking-1',
        bookingReference: 'RES-1',
        clientId: 'client-1',
        client: 'Ana Pérez',
        motelId: 'motel-1',
        motel: 'Motel Central',
        roomId: 'room-1',
        room: 'Suite 1',
        reservationDate: DateTime.utc(2026, 10, 16),
        amount: 120000,
        status: status,
        paymentMethodId: status == PaymentStatus.paid ? 1 : null,
        paidAt: status == PaymentStatus.paid
            ? DateTime.utc(2026, 10, 16, 21, 30)
            : null,
        receiptNumber: status == PaymentStatus.paid ? 'LOCAL-pay-1' : null,
      );

  test('convierte un pago a Firestore sin datos bancarios', () {
    final data = PaymentFirestoreDocument(
      ownerId: 'owner-uid',
      payment: payment(),
      paymentMethodName: 'Efectivo',
    ).toFirestore();

    expect(data['ownerId'], 'owner-uid');
    expect(data['status'], 'paid');
    expect(data['reservationDate'], isA<Timestamp>());
    expect(data['paidAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<FieldValue>());
    expect(data['receiptNumber'], 'LOCAL-pay-1');
    expect(data['paymentMethodId'], 1);
    expect(data['paymentMethodName'], 'Efectivo');
    expect(data, isNot(contains('cardNumber')));
    expect(data, isNot(contains('cvv')));
  });

  test('reconstruye un pago tolerando campos opcionales ausentes', () {
    final source = payment(status: PaymentStatus.pending);
    final data = PaymentFirestoreDocument(
      ownerId: 'owner-uid',
      payment: source,
    ).toFirestore()..remove('updatedAt');

    final decoded = PaymentFirestoreDocument.fromFirestore('pay-1', data);

    expect(decoded.ownerId, 'owner-uid');
    expect(decoded.payment.id, 'pay-1');
    expect(decoded.payment.status, PaymentStatus.pending);
    expect(decoded.payment.paymentMethodId, isNull);
    expect(decoded.payment.paidAt, isNull);
    expect(decoded.paymentMethodName, isNull);
  });

  test('rechaza estados y cantidades inválidos', () {
    final data = PaymentFirestoreDocument(
      ownerId: 'owner-uid',
      payment: payment(),
    ).toFirestore()..remove('updatedAt');

    expect(
      () => PaymentFirestoreDocument.fromFirestore(
        'pay-1',
        Map<String, dynamic>.of(data)..['status'] = 'unknown',
      ),
      throwsFormatException,
    );
    expect(
      () => PaymentFirestoreDocument.fromFirestore(
        'pay-1',
        Map<String, dynamic>.of(data)..['amount'] = 0,
      ),
      throwsFormatException,
    );
  });
}
