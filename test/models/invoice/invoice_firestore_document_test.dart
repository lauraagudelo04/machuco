import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/invoice/invoice_firestore_document.dart';
import 'package:machuco/models/invoice/invoice_model.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';

final _reservation = Reservation(
  id: 'res-1',
  requestId: 'req-1',
  motelId: 'motel-1',
  motelName: 'Motel Prueba',
  roomId: 'room-1',
  roomName: 'Suite',
  roomNumber: '101',
  checkIn: DateTime.utc(2026, 10, 19, 20),
  checkOut: DateTime.utc(2026, 10, 19, 23),
  stayMode: StayMode.dateWithHourBlock,
  guestCount: 2,
  services: const [
    ReservationLineItem(id: 's1', name: 'Jacuzzi', unitPrice: 30000),
  ],
  products: const [
    ReservationLineItem(
      id: 'p1',
      name: 'Gaseosa',
      unitPrice: 5000,
      quantity: 2,
    ),
  ],
  roomTotal: 100000,
  total: 140000,
  status: ReservationStatus.completed,
  createdAt: DateTime(2026, 10, 19),
  guestId: 'client-1',
  guestName: 'Ana Pérez',
);

Map<String, dynamic> _stored(Map<String, dynamic> written) => {
  ...written,
  'issuedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 19, 23, 5)),
};

void main() {
  group('InvoiceModel.fromReservation', () {
    test('copia reserva e items y deriva el número de factura', () {
      final invoice = InvoiceModel.fromReservation(_reservation);

      expect(invoice.id, 'res-1');
      expect(invoice.invoiceNumber, 'FAC-RES1');
      expect(invoice.clientId, 'client-1');
      expect(invoice.items.map((item) => item.id), ['s1', 'p1']);
      expect(invoice.total, 140000);
      expect(invoice.payment, isNull);
    });

    test('del pago solo guarda los últimos 4 dígitos', () {
      final invoice = InvoiceModel.fromReservation(
        _reservation,
        paymentMethod: PaymentMethodModel(concept: 'Reserva', amount: 140000)
          ..cardNumber = '4242 4242 4242 4242'
          ..cardHolder = 'Ana Pérez'
          ..expiry = '12/30'
          ..cvv = '123',
      );

      expect(invoice.payment?.cardLast4, '4242');
      final data = InvoiceFirestoreDocument(
        ownerId: 'owner-1',
        invoice: invoice,
      ).toFirestore();
      expect(data.values, isNot(contains('4242 4242 4242 4242')));
      expect(data.values, isNot(contains('123')));
      expect(data.values, isNot(contains('12/30')));
    });
  });

  group('InvoiceFirestoreDocument', () {
    test('ida y vuelta conserva los datos', () {
      final written = InvoiceFirestoreDocument(
        ownerId: 'owner-1',
        invoice: InvoiceModel.fromReservation(_reservation),
      ).toFirestore();

      expect(written['issuedAt'], isA<FieldValue>());
      expect(written['items'], [
        {'id': 's1', 'name': 'Jacuzzi', 'unitPrice': 30000, 'quantity': 1},
        {'id': 'p1', 'name': 'Gaseosa', 'unitPrice': 5000, 'quantity': 2},
      ]);

      final read = InvoiceFirestoreDocument.fromFirestore(
        'res-1',
        _stored(written),
      );
      expect(read.ownerId, 'owner-1');
      expect(read.invoice.invoiceNumber, 'FAC-RES1');
      expect(read.invoice.checkIn.toUtc(), DateTime.utc(2026, 10, 19, 20));
      expect(read.invoice.items.last.subtotal, 10000);
      expect(read.invoice.total, 140000);
      expect(read.invoice.issuedAt.toUtc(), DateTime.utc(2026, 10, 19, 23, 5));
    });

    test('rechaza documentos con datos inválidos', () {
      final written = _stored(
        InvoiceFirestoreDocument(
          ownerId: 'owner-1',
          invoice: InvoiceModel.fromReservation(_reservation),
        ).toFirestore(),
      );

      expect(
        () => InvoiceFirestoreDocument.fromFirestore('otra-reserva', written),
        throwsFormatException,
      );
      expect(
        () => InvoiceFirestoreDocument.fromFirestore('res-1', {
          ...written,
          'total': '140000',
        }),
        throwsFormatException,
      );
      expect(
        () => InvoiceFirestoreDocument.fromFirestore('res-1', {
          ...written,
          'paymentConcept': 'Reserva',
          'paymentAmount': 1,
          'cardLast4': '4242424242424242',
        }),
        throwsFormatException,
      );
    });
  });
}
