import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/repositories/booking/booking_seed_data.dart';
import 'package:machuco/repositories/booking/reservation_cloud_repository.dart';
import 'package:machuco/repositories/booking/synced_booking_repository.dart';

class _FakeCloud implements ReservationCloudRepository {
  _FakeCloud({List<Reservation> remote = const []}) : remote = List.of(remote);

  final List<Reservation> remote;
  final saved = <({String ownerId, Reservation reservation})>[];
  final reads = <String>[];
  Object? failure;

  /// Fails only the pushes, while reads keep working.
  Object? saveFailure;

  @override
  Future<void> saveReservation({
    required String ownerId,
    required Reservation reservation,
  }) async {
    if (failure != null) throw failure!;
    if (saveFailure != null) throw saveFailure!;
    saved.add((ownerId: ownerId, reservation: reservation));
    // Like Firestore, later reads return what was saved.
    remote
      ..removeWhere((r) => r.id == reservation.id)
      ..add(reservation);
  }

  @override
  Future<List<Reservation>> listForGuest(String guestId) async {
    reads.add('guest:$guestId');
    if (failure != null) throw failure!;
    return remote.where((r) => r.guestId == guestId).toList();
  }

  @override
  Future<List<Reservation>> listForOwner(String ownerId) async {
    reads.add('owner:$ownerId');
    if (failure != null) throw failure!;
    return remote;
  }

  @override
  Future<List<Reservation>> listAll() async {
    reads.add('all');
    if (failure != null) throw failure!;
    return remote;
  }
}

Reservation _reservation(
  String id, {
  String guestId = 'uid-client',
  String motelId = '2',
  ReservationStatus status = ReservationStatus.pending,
}) => Reservation(
  id: id,
  requestId: 'req-$id',
  motelId: motelId,
  motelName: 'Motel El Edén',
  roomId: 'room-1',
  roomName: 'Deluxe',
  roomNumber: '101',
  checkIn: DateTime(2026, 11, 10, 17),
  checkOut: DateTime(2026, 11, 10, 21),
  stayMode: StayMode.dateWithHourBlock,
  guestCount: 2,
  services: const [],
  products: const [],
  roomTotal: 100000,
  total: 100000,
  status: status,
  createdAt: DateTime(2026, 11, 7, 12),
  guestId: guestId,
);

void main() {
  late InMemoryBookingRepository local;
  late _FakeCloud cloud;
  String? uid;
  RegisteredUserRole? role;
  late int roleLookups;

  SyncedBookingRepository repository() => SyncedBookingRepository(
    local: local,
    cloud: cloud,
    currentUid: () => uid,
    roleOf: (_) async {
      roleLookups++;
      return role;
    },
    ownerIdForMotel: (motelId) async =>
        motelId == '2' ? 'uid-owner' : null,
  );

  setUp(() {
    local = InMemoryBookingRepository(now: () => DateTime(2026, 11, 7, 12));
    cloud = _FakeCloud(remote: [_reservation('res-remote')]);
    uid = null;
    role = null;
    roleLookups = 0;
  });

  group('without a session', () {
    test('behaves like the local repository and never calls Firebase',
        () async {
      final synced = repository();

      final all = await synced.getAll();
      await synced.add(_reservation('res-new'));
      await synced.waitForPendingSync();

      expect(all.map((r) => r.id).where(isSeedReservationId), isNotEmpty);
      expect(all.every((r) => isSeedReservationId(r.id)), isTrue);
      expect(cloud.reads, isEmpty);
      expect(cloud.saved, isEmpty);
      expect(await local.getById('res-new'), isNotNull);
    });
  });

  group('with a session', () {
    test('a client pulls only their reservations and the seed is hidden',
        () async {
      uid = 'uid-client';
      role = RegisteredUserRole.client;

      final all = await repository().getAll();

      expect(cloud.reads, ['guest:uid-client']);
      expect(all.map((r) => r.id), ['res-remote']);
      expect(await local.getById('res-remote'), isNotNull);
    });

    test('an owner pulls the reservations of their motels', () async {
      uid = 'uid-owner';
      role = RegisteredUserRole.owner;

      final all = await repository().getAll();

      expect(cloud.reads, ['owner:uid-owner']);
      expect(all.map((r) => r.id), ['res-remote']);
    });

    test('an admin pulls every reservation', () async {
      uid = 'uid-admin';
      role = RegisteredUserRole.admin;

      await repository().getAll();

      expect(cloud.reads, ['all']);
    });

    test('a pulled reservation replaces the cached copy', () async {
      uid = 'uid-client';
      role = RegisteredUserRole.client;
      await local.add(_reservation('res-remote'));
      cloud.remote
        ..clear()
        ..add(
          _reservation('res-remote', status: ReservationStatus.cancelled),
        );

      final all = await repository().getAll();

      expect(all.single.status, ReservationStatus.cancelled);
    });

    test('offline it returns the cache without the seed', () async {
      uid = 'uid-client';
      role = RegisteredUserRole.client;
      await local.add(_reservation('res-cached'));
      cloud.failure = const ReservationCloudRepositoryException(
        ReservationCloudFailureType.network,
        'offline',
      );

      final all = await repository().getAll();

      expect(all.map((r) => r.id), ['res-cached']);
    });

    test('a failed role lookup skips the pull and is retried', () async {
      uid = 'uid-client';
      final synced = repository();

      await synced.getAll();
      expect(cloud.reads, isEmpty);

      role = RegisteredUserRole.client;
      await synced.getAll();
      await synced.getAll();

      expect(cloud.reads, ['guest:uid-client', 'guest:uid-client']);
      expect(roleLookups, 2);
    });

    test('add saves locally and pushes with the motel owner', () async {
      uid = 'uid-client';
      final synced = repository();

      await synced.add(_reservation('res-new'));
      await synced.waitForPendingSync();

      expect(await local.getById('res-new'), isNotNull);
      expect(cloud.saved.single.ownerId, 'uid-owner');
      expect(cloud.saved.single.reservation.id, 'res-new');
    });

    test('update pushes the new state', () async {
      uid = 'uid-owner';
      final synced = repository();
      await local.add(_reservation('res-1'));

      await synced.update(
        _reservation('res-1', status: ReservationStatus.cancelled),
      );
      await synced.waitForPendingSync();

      expect(cloud.saved.single.reservation.status, ReservationStatus.cancelled);
      expect((await local.getById('res-1'))?.status, ReservationStatus.cancelled);
    });

    test('a failed push keeps the local reservation', () async {
      uid = 'uid-client';
      cloud.failure = const ReservationCloudRepositoryException(
        ReservationCloudFailureType.permissionDenied,
        'denied',
      );
      final synced = repository();

      await synced.add(_reservation('res-new'));
      await synced.waitForPendingSync();

      expect(await local.getById('res-new'), isNotNull);
    });

    test('a pull does not overwrite a change whose push failed', () async {
      uid = 'uid-client';
      role = RegisteredUserRole.client;
      cloud.remote
        ..clear()
        ..add(_reservation('res-1'));
      final synced = repository();
      await synced.getAll();
      cloud.saveFailure = const ReservationCloudRepositoryException(
        ReservationCloudFailureType.permissionDenied,
        'denied',
      );

      await synced.update(
        _reservation('res-1', status: ReservationStatus.upcoming),
      );
      await synced.waitForPendingSync();
      final all = await synced.getAll();

      expect(cloud.saved, isEmpty);
      expect(all.single.status, ReservationStatus.upcoming);
      expect((await local.getById('res-1'))?.status, ReservationStatus.upcoming);
    });

    test('the next read retries a failed push before pulling', () async {
      uid = 'uid-client';
      role = RegisteredUserRole.client;
      cloud.remote
        ..clear()
        ..add(_reservation('res-1'));
      final synced = repository();
      await synced.getAll();

      cloud.failure = const ReservationCloudRepositoryException(
        ReservationCloudFailureType.network,
        'offline',
      );
      await synced.update(
        _reservation('res-1', status: ReservationStatus.upcoming),
      );
      await synced.waitForPendingSync();
      expect(cloud.saved, isEmpty);

      cloud.failure = null;
      final all = await synced.getAll();

      expect(cloud.saved.single.reservation.status, ReservationStatus.upcoming);
      expect(all.single.status, ReservationStatus.upcoming);
    });

    test('seed reservations and unknown motels are not pushed', () async {
      uid = 'uid-client';
      final synced = repository();
      final seed = (await local.getAll()).first;

      await synced.update(seed.copyWith(status: ReservationStatus.cancelled));
      await synced.add(_reservation('res-mock', motelId: 'mock-motel'));
      await synced.waitForPendingSync();

      expect(cloud.saved, isEmpty);
      expect(await local.getById('res-mock'), isNotNull);
    });
  });

  test('every demo seed id is recognized and generated ids are not', () {
    final seeds = buildSeedReservations(DateTime(2026, 11, 7, 12));

    expect(seeds.every((r) => isSeedReservationId(r.id)), isTrue);
    expect(isSeedReservationId('reservation-1794095248660288-req-1'), isFalse);
  });
}
