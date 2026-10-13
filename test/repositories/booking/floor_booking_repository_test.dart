import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_entity.dart';
import 'package:machuco/models/booking/reservation_line_item_entity.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/repositories/booking/booking_seed_data.dart';
import 'package:machuco/repositories/booking/reservation_dao.dart';
import 'package:machuco/repositories/booking/reservation_mapper.dart';

/// Hand-written in-memory DAO: no SQLite involved.
class FakeReservationDao extends ReservationDao {
  final Map<String, ReservationEntity> reservations = {};
  final List<ReservationLineItemEntity> lineItems = [];
  int insertCalls = 0;
  int replaceCalls = 0;
  int _nextRowId = 1;

  void _storeItems(List<ReservationLineItemEntity> items) {
    for (final item in items) {
      lineItems.add(
        ReservationLineItemEntity(
          rowId: _nextRowId++,
          reservationId: item.reservationId,
          kind: item.kind,
          itemId: item.itemId,
          name: item.name,
          unitPrice: item.unitPrice,
          quantity: item.quantity,
          position: item.position,
        ),
      );
    }
  }

  @override
  Future<int?> countReservations() async => reservations.length;

  @override
  Future<List<ReservationEntity>> findAllReservations() async =>
      reservations.values.toList();

  @override
  Future<ReservationEntity?> findReservationById(String id) async =>
      reservations[id];

  @override
  Future<ReservationEntity?> findReservationByRequestId(
    String requestId,
  ) async {
    for (final r in reservations.values) {
      if (r.requestId == requestId) return r;
    }
    return null;
  }

  @override
  Future<List<ReservationLineItemEntity>> findAllLineItems() async =>
      List.of(lineItems);

  @override
  Future<List<ReservationLineItemEntity>> findLineItems(
    String reservationId,
  ) async => lineItems.where((i) => i.reservationId == reservationId).toList();

  @override
  Future<void> deleteLineItems(String id) async =>
      lineItems.removeWhere((i) => i.reservationId == id);

  @override
  Future<void> insertReservationRow(ReservationEntity reservation) async =>
      reservations[reservation.id] = reservation;

  @override
  Future<void> updateReservationRow(ReservationEntity reservation) async =>
      reservations[reservation.id] = reservation;

  @override
  Future<void> insertLineItems(List<ReservationLineItemEntity> items) async =>
      _storeItems(items);

  @override
  Future<void> insertReservation(
    ReservationEntity reservation,
    List<ReservationLineItemEntity> items,
  ) async {
    insertCalls++;
    await insertReservationRow(reservation);
    await deleteLineItems(reservation.id);
    await insertLineItems(items);
  }

  @override
  Future<void> replaceReservation(
    ReservationEntity reservation,
    List<ReservationLineItemEntity> items,
  ) async {
    replaceCalls++;
    await updateReservationRow(reservation);
    await deleteLineItems(reservation.id);
    await insertLineItems(items);
  }
}

void main() {
  final now = DateTime(2026, 6, 1, 12);
  late FakeReservationDao dao;
  late FloorBookingRepository repository;

  setUp(() {
    dao = FakeReservationDao();
    repository = FloorBookingRepository(dao, now: () => now);
  });

  test('seeds an empty table once and returns the seed', () async {
    final seed = buildSeedReservations(now);

    final all = await repository.getAll();
    await repository.getAll();

    expect(all.map((r) => r.id).toSet(), seed.map((r) => r.id).toSet());
    expect(dao.insertCalls, seed.length);
    expect(dao.lineItems, isNotEmpty);
  });

  test('does not seed when the table already has data', () async {
    final seed = buildSeedReservations(now);
    await dao.insertReservation(
      ReservationMapper.toEntity(seed.first),
      ReservationMapper.toLineItemEntities(seed.first),
    );
    dao.insertCalls = 0;

    final other = FloorBookingRepository(dao, now: () => now);
    final all = await other.getAll();

    expect(all.length, 1);
    expect(dao.insertCalls, 0);
  });

  test('add then getById and findByRequestId', () async {
    final r = buildSeedReservations(
      now,
    ).firstWhere((r) => r.products.isNotEmpty);
    final fresh = Reservation(
      id: 'new-1',
      requestId: 'new-req',
      motelId: r.motelId,
      motelName: r.motelName,
      roomId: r.roomId,
      roomName: r.roomName,
      roomNumber: r.roomNumber,
      checkIn: r.checkIn,
      checkOut: r.checkOut,
      stayMode: r.stayMode,
      guestCount: 1,
      services: r.services,
      products: r.products,
      roomTotal: r.roomTotal,
      total: r.total,
      status: ReservationStatus.pending,
      createdAt: now,
    );

    await repository.add(fresh);

    final byId = await repository.getById('new-1');
    expect(byId?.requestId, 'new-req');
    expect(byId?.products.length, fresh.products.length);
    expect((await repository.findByRequestId('new-req'))?.id, 'new-1');
    expect(await repository.getById('missing'), isNull);
    expect(await repository.findByRequestId('missing'), isNull);
  });

  test('update replaces fields and line items, ignoring unknown ids', () async {
    final all = await repository.getAll();
    final target = all.firstWhere((r) => r.status == ReservationStatus.pending);
    final count = all.length;
    final itemsBefore = dao.lineItems.length;

    await repository.update(
      target.copyWith(
        status: ReservationStatus.upcoming,
        paymentMethod: 'Tarjeta',
      ),
    );

    final stored = await repository.getById(target.id);
    expect(stored?.status, ReservationStatus.upcoming);
    expect(stored?.paymentMethod, 'Tarjeta');
    expect(stored?.products.length, target.products.length);
    expect(dao.lineItems.length, itemsBefore);
    expect(dao.replaceCalls, 1);

    final ghost = Reservation(
      id: 'ghost',
      requestId: 'ghost',
      motelId: 'x',
      motelName: 'x',
      roomId: 'x',
      roomName: 'x',
      roomNumber: 'x',
      checkIn: now,
      checkOut: now,
      stayMode: StayMode.dateTimeRange,
      guestCount: 1,
      services: const [],
      products: const [],
      roomTotal: 0,
      total: 0,
      status: ReservationStatus.pending,
      createdAt: now,
    );
    await repository.update(ghost);

    expect(dao.replaceCalls, 1);
    expect((await repository.getAll()).length, count);
  });
}
