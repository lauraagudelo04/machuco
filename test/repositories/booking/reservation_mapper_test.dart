import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_line_item_entity.dart';
import 'package:machuco/repositories/booking/booking_seed_data.dart';
import 'package:machuco/repositories/booking/reservation_mapper.dart';

Reservation _reservation({
  StayMode stayMode = StayMode.dateTimeRange,
  ReservationStatus status = ReservationStatus.pending,
  InvoiceAccessStatus invoice = InvoiceAccessStatus.notApplicable,
  List<ReservationLineItem> services = const [],
  List<ReservationLineItem> products = const [],
  int? categoryId,
  String? cancellationReason,
  String? paymentMethod,
}) {
  return Reservation(
    id: 'r1',
    requestId: 'req1',
    motelId: 'm1',
    motelName: 'Motel',
    roomId: 'room1',
    roomName: 'Suite',
    roomNumber: '101',
    checkIn: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    checkOut: DateTime.fromMillisecondsSinceEpoch(1700007200000),
    stayMode: stayMode,
    guestCount: 2,
    services: services,
    products: products,
    roomTotal: 1000,
    total: 1500,
    status: status,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1699990000000),
    guestId: 'g1',
    guestName: 'Guest',
    categoryId: categoryId,
    cancellationReason: cancellationReason,
    invoiceAccessStatus: invoice,
    paymentMethod: paymentMethod,
  );
}

Reservation _roundTrip(Reservation r) => ReservationMapper.toDomain(
  ReservationMapper.toEntity(r),
  ReservationMapper.toLineItemEntities(r),
);

void _expectSame(Reservation a, Reservation b) {
  expect(b.id, a.id);
  expect(b.requestId, a.requestId);
  expect(b.motelId, a.motelId);
  expect(b.motelName, a.motelName);
  expect(b.roomId, a.roomId);
  expect(b.roomName, a.roomName);
  expect(b.roomNumber, a.roomNumber);
  expect(b.checkIn, a.checkIn);
  expect(b.checkOut, a.checkOut);
  expect(b.stayMode, a.stayMode);
  expect(b.guestCount, a.guestCount);
  expect(b.roomTotal, a.roomTotal);
  expect(b.total, a.total);
  expect(b.status, a.status);
  expect(b.createdAt, a.createdAt);
  expect(b.guestId, a.guestId);
  expect(b.guestName, a.guestName);
  expect(b.categoryId, a.categoryId);
  expect(b.cancellationReason, a.cancellationReason);
  expect(b.invoiceAccessStatus, a.invoiceAccessStatus);
  expect(b.paymentMethod, a.paymentMethod);
  List<List<Object>> flat(List<ReservationLineItem> l) => [
    for (final i in l) [i.id, i.name, i.unitPrice, i.quantity],
  ];
  expect(flat(b.services), flat(a.services));
  expect(flat(b.products), flat(a.products));
}

void main() {
  group('ReservationMapper', () {
    test('round-trips empty services and products with null optionals', () {
      final r = _reservation();
      final entity = ReservationMapper.toEntity(r);

      expect(ReservationMapper.toLineItemEntities(r), isEmpty);
      expect(entity.categoryId, isNull);
      expect(entity.cancellationReason, isNull);
      expect(entity.paymentMethod, isNull);
      _expectSame(r, _roundTrip(r));
    });

    test('round-trips populated optionals, services and products in order', () {
      final r = _reservation(
        services: const [
          ReservationLineItem(id: 's2', name: 'Spa', unitPrice: 200),
          ReservationLineItem(id: 's1', name: 'Masaje', unitPrice: 300),
        ],
        products: const [
          ReservationLineItem(
            id: 'p1',
            name: 'Agua',
            unitPrice: 50,
            quantity: 3,
          ),
        ],
        categoryId: 3,
        cancellationReason: 'Cambio de planes',
        paymentMethod: 'Efectivo',
      );
      final items = ReservationMapper.toLineItemEntities(r);

      expect(items.map((i) => i.kind), [
        ReservationLineItemEntity.kindService,
        ReservationLineItemEntity.kindService,
        ReservationLineItemEntity.kindProduct,
      ]);
      _expectSame(r, _roundTrip(r));
    });

    test('restores order even when rows come back shuffled', () {
      final r = _reservation(
        services: const [
          ReservationLineItem(id: 'a', name: 'A', unitPrice: 1),
          ReservationLineItem(id: 'b', name: 'B', unitPrice: 2),
          ReservationLineItem(id: 'c', name: 'C', unitPrice: 3),
        ],
      );
      final items = ReservationMapper.toLineItemEntities(r).reversed.toList();

      final back = ReservationMapper.toDomain(
        ReservationMapper.toEntity(r),
        items,
      );

      expect(back.services.map((i) => i.id), ['a', 'b', 'c']);
    });

    test('round-trips every enum value', () {
      for (final mode in StayMode.values) {
        _expectSame(
          _reservation(stayMode: mode),
          _roundTrip(_reservation(stayMode: mode)),
        );
      }
      for (final status in ReservationStatus.values) {
        final r = _reservation(status: status);
        expect(ReservationMapper.toEntity(r).status, status.name);
        _expectSame(r, _roundTrip(r));
      }
      for (final invoice in InvoiceAccessStatus.values) {
        final r = _reservation(invoice: invoice);
        _expectSame(r, _roundTrip(r));
      }
    });

    test('round-trips the whole seed', () {
      for (final r in buildSeedReservations(DateTime(2026, 1, 1, 12))) {
        _expectSame(r, _roundTrip(r));
      }
    });
  });
}
