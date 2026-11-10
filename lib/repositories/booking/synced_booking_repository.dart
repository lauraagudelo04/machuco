import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/repositories/booking/booking_seed_data.dart';
import 'package:machuco/repositories/booking/reservation_cloud_repository.dart';

/// Keeps the local reservations in sync with Firestore.
///
/// Without a session it is exactly the local repository (demo seed, no
/// Firebase calls). With a session:
/// - [getAll] first pulls what the user's role may read (client: their own,
///   owner: their motels', admin: all) into the local cache, and hides the
///   demo seed. The remote copy wins over the cached one, except for
///   reservations whose push has not succeeded yet: those are pushed again
///   first and keep their local state. Offline, the cache is returned.
/// - [add] and [update] write locally and then push in the background, so the
///   UI never waits for the network. A failed push keeps the local copy.
///   Unsynced changes are tracked in memory only, so a restart forgets them.
class SyncedBookingRepository implements BookingRepository {
  SyncedBookingRepository({
    required BookingRepository local,
    required ReservationCloudRepository cloud,
    required String? Function() currentUid,
    required Future<RegisteredUserRole?> Function(String uid) roleOf,
    required Future<String?> Function(String motelId) ownerIdForMotel,
    this.reconcilePayment,
  }) : _local = local,
       _cloud = cloud,
       _currentUid = currentUid,
       _roleOf = roleOf,
       _ownerIdForMotel = ownerIdForMotel;

  final BookingRepository _local;
  final ReservationCloudRepository _cloud;
  final String? Function() _currentUid;
  final Future<RegisteredUserRole?> Function(String uid) _roleOf;
  final Future<String?> Function(String motelId) _ownerIdForMotel;
  final Future<Reservation> Function(Reservation reservation)? reconcilePayment;

  final Map<String, RegisteredUserRole> _roles = {};
  final Set<Future<void>> _pendingPushes = {};

  /// Ids whose latest local change has not reached Firestore yet.
  final Set<String> _unsynced = {};
  Future<void>? _pulling;

  @override
  Future<List<Reservation>> getAll() async {
    final uid = _currentUid();
    if (uid == null) return _local.getAll();
    await (_pulling ??= _pull(uid).whenComplete(() => _pulling = null));
    final all = await _local.getAll();
    return List.unmodifiable(
      all.where((reservation) => !isSeedReservationId(reservation.id)),
    );
  }

  @override
  Future<Reservation?> getById(String id) => _local.getById(id);

  @override
  Future<Reservation?> findByRequestId(String requestId) =>
      _local.findByRequestId(requestId);

  @override
  Future<void> add(Reservation reservation) async {
    await _local.add(reservation);
    _push(reservation);
  }

  @override
  Future<void> update(Reservation reservation) async {
    await _local.update(reservation);
    _push(reservation);
  }

  /// Completes when every background push started so far has finished.
  Future<void> waitForPendingSync() => Future.wait(List.of(_pendingPushes));

  Future<void> _pull(String uid) async {
    try {
      final role = await _role(uid);
      if (role == null) return;
      await _retryUnsynced();
      final remote = switch (role) {
        RegisteredUserRole.client => await _cloud.listForGuest(uid),
        RegisteredUserRole.owner => await _cloud.listForOwner(uid),
        RegisteredUserRole.admin => await _cloud.listAll(),
      };
      for (final reservation in remote) {
        // A local change that is still unsynced wins over the server copy.
        if (_unsynced.contains(reservation.id)) continue;
        final reconciled =
            await reconcilePayment?.call(reservation) ?? reservation;
        if (await _local.getById(reservation.id) == null) {
          await _local.add(reconciled);
        } else {
          await _local.update(reconciled);
        }
        if (reconciled.paymentMethod != reservation.paymentMethod ||
            reconciled.status != reservation.status) {
          _push(reconciled);
        }
      }
    } catch (error) {
      debugPrint('Reservation pull skipped: $error');
    }
  }

  /// Role from the user profile, cached per uid once it is known.
  Future<RegisteredUserRole?> _role(String uid) async {
    final cached = _roles[uid];
    if (cached != null) return cached;
    final role = await _roleOf(uid);
    if (role != null) _roles[uid] = role;
    return role;
  }

  void _push(Reservation reservation) {
    if (_currentUid() == null) return;
    if (isSeedReservationId(reservation.id)) return;
    _unsynced.add(reservation.id);
    late final Future<void> push;
    push = _save(reservation).whenComplete(() => _pendingPushes.remove(push));
    _pendingPushes.add(push);
  }

  Future<void> _retryUnsynced() async {
    for (final id in List.of(_unsynced)) {
      final reservation = await _local.getById(id);
      if (reservation == null) {
        _unsynced.remove(id);
      } else {
        await _save(reservation);
      }
    }
  }

  /// Pushes [reservation] and clears its unsynced mark on success.
  Future<void> _save(Reservation reservation) async {
    try {
      final ownerId = await _ownerIdForMotel(reservation.motelId);
      // A motel outside the shared catalog (demo data) has no owner account.
      if (ownerId == null) {
        _unsynced.remove(reservation.id);
        return;
      }
      await _cloud.saveReservation(ownerId: ownerId, reservation: reservation);
      _unsynced.remove(reservation.id);
    } catch (error) {
      debugPrint('Reservation push failed, kept locally: $error');
    }
  }
}
