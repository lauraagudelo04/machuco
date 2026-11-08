import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_firestore_document.dart';

Reservation _reservation({
  String? cancellationReason,
  String? paymentMethod,
  int? categoryId = 3,
}) => Reservation(
  id: 'res-1',
  requestId: 'req-1',
  motelId: '2',
  motelName: 'Motel El Edén',
  roomId: 'room-208',
  roomName: 'Deluxe',
  roomNumber: '208',
  checkIn: DateTime(2026, 11, 10, 17),
  checkOut: DateTime(2026, 11, 10, 21),
  stayMode: StayMode.dateWithHourBlock,
  guestCount: 2,
  services: const [
    ReservationLineItem(id: 'svc-1', name: 'Jacuzzi', unitPrice: 30000),
  ],
  products: const [
    ReservationLineItem(
      id: 'prd-1',
      name: 'Agua',
      unitPrice: 4000,
      quantity: 2,
    ),
  ],
  roomTotal: 120000,
  total: 158000,
  status: ReservationStatus.upcoming,
  createdAt: DateTime(2026, 11, 7, 12),
  guestId: 'uid-client',
  guestName: 'cliente@machuco.com',
  categoryId: categoryId,
  cancellationReason: cancellationReason,
  invoiceAccessStatus: InvoiceAccessStatus.available,
  paymentMethod: paymentMethod,
);

void main() {
  test('round-trips every reservation field through Firestore data', () {
    final original = _reservation(
      cancellationReason: 'Cambio de planes',
      paymentMethod: 'Tarjeta de crédito',
    );
    final data = ReservationFirestoreDocument(
      ownerId: 'uid-owner',
      reservation: original,
    ).toFirestore();

    expect(data['ownerId'], 'uid-owner');
    expect(data['guestId'], 'uid-client');
    expect(data['checkIn'], isA<Timestamp>());
    expect(data['updatedAt'], isA<FieldValue>());

    final restored = ReservationFirestoreDocument.fromFirestore(
      'res-1',
      data..remove('updatedAt'),
    );

    expect(restored.ownerId, 'uid-owner');
    final r = restored.reservation;
    expect(r.id, original.id);
    expect(r.requestId, original.requestId);
    expect(r.motelId, original.motelId);
    expect(r.motelName, original.motelName);
    expect(r.roomId, original.roomId);
    expect(r.roomName, original.roomName);
    expect(r.roomNumber, original.roomNumber);
    expect(r.checkIn, original.checkIn);
    expect(r.checkOut, original.checkOut);
    expect(r.stayMode, original.stayMode);
    expect(r.guestCount, original.guestCount);
    expect(r.services.single.name, 'Jacuzzi');
    expect(r.products.single.quantity, 2);
    expect(r.roomTotal, original.roomTotal);
    expect(r.total, original.total);
    expect(r.status, original.status);
    expect(r.createdAt, original.createdAt);
    expect(r.guestId, original.guestId);
    expect(r.guestName, original.guestName);
    expect(r.categoryId, 3);
    expect(r.cancellationReason, 'Cambio de planes');
    expect(r.invoiceAccessStatus, InvoiceAccessStatus.available);
    expect(r.paymentMethod, 'Tarjeta de crédito');
  });

  test('omits the optional fields that are null', () {
    final data = ReservationFirestoreDocument(
      ownerId: 'uid-owner',
      reservation: _reservation(categoryId: null),
    ).toFirestore();

    expect(data.containsKey('categoryId'), isFalse);
    expect(data.containsKey('cancellationReason'), isFalse);
    expect(data.containsKey('paymentMethod'), isFalse);
  });

  test('rejects documents with an unknown status or missing owner', () {
    Map<String, dynamic> valid() => ReservationFirestoreDocument(
      ownerId: 'uid-owner',
      reservation: _reservation(),
    ).toFirestore()..remove('updatedAt');

    expect(
      () => ReservationFirestoreDocument.fromFirestore(
        'res-1',
        valid()..['status'] = 'lost',
      ),
      throwsFormatException,
    );
    expect(
      () => ReservationFirestoreDocument.fromFirestore(
        'res-1',
        valid()..remove('ownerId'),
      ),
      throwsFormatException,
    );
  });
}
