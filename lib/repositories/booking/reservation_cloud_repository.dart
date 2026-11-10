import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_firestore_document.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

enum ReservationCloudFailureType {
  permissionDenied,
  network,
  invalidData,
  unknown,
}

class ReservationCloudRepositoryException implements Exception {
  const ReservationCloudRepositoryException(this.type, this.message);

  final ReservationCloudFailureType type;
  final String message;

  @override
  String toString() => message;
}

/// Remote reservation contract. Each read is scoped to what the security
/// rules let that role see, because Firestore rejects unscoped queries.
abstract interface class ReservationCloudRepository {
  /// Creates or replaces `reservations/{reservation.id}`. [ownerId] is the
  /// owner of the reservation's motel.
  Future<void> saveReservation({
    required String ownerId,
    required Reservation reservation,
  });

  /// Reservations made by the client [guestId].
  Future<List<Reservation>> listForGuest(String guestId);

  /// Reservations of the motels owned by [ownerId].
  Future<List<Reservation>> listForOwner(String ownerId);

  /// Every reservation (system administrator only).
  Future<List<Reservation>> listAll();
}

class FirestoreReservationCloudRepository implements ReservationCloudRepository {
  FirestoreReservationCloudRepository({
    FirebaseFirestore? firestore,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Duration requestTimeout;

  CollectionReference<Map<String, dynamic>> get _reservations =>
      _firestore.collection(FirestoreCollections.reservations);

  @override
  Future<void> saveReservation({
    required String ownerId,
    required Reservation reservation,
  }) async {
    _validateId(ownerId);
    _validateId(reservation.guestId);
    try {
      await _reservations
          .doc(reservation.id)
          .set(
            ReservationFirestoreDocument(
              ownerId: ownerId,
              reservation: reservation,
            ).toFirestore(),
          )
          .timeout(requestTimeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw _offline;
    }
  }

  @override
  Future<List<Reservation>> listForGuest(String guestId) {
    _validateId(guestId);
    return _list(
      _reservations.where('guestId', isEqualTo: guestId),
      (document) => document.reservation.guestId == guestId,
    );
  }

  @override
  Future<List<Reservation>> listForOwner(String ownerId) {
    _validateId(ownerId);
    return _list(
      _reservations.where('ownerId', isEqualTo: ownerId),
      (document) => document.ownerId == ownerId,
    );
  }

  @override
  Future<List<Reservation>> listAll() => _list(_reservations, (_) => true);

  Future<List<Reservation>> _list(
    Query<Map<String, dynamic>> query,
    bool Function(ReservationFirestoreDocument document) inScope,
  ) async {
    try {
      final snapshot = await query.get().timeout(requestTimeout);
      return List.unmodifiable(
        snapshot.docs.map((snapshotDocument) {
          final document = ReservationFirestoreDocument.fromFirestore(
            snapshotDocument.id,
            snapshotDocument.data(),
          );
          if (!inScope(document)) {
            throw const FormatException(
              'Reserva remota fuera del alcance solicitado.',
            );
          }
          return document.reservation;
        }),
      );
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw _offline;
    } on FormatException {
      throw const ReservationCloudRepositoryException(
        ReservationCloudFailureType.invalidData,
        'Firebase devolvió reservas con datos inválidos.',
      );
    }
  }

  static const _offline = ReservationCloudRepositoryException(
    ReservationCloudFailureType.network,
    'Sin conexión: se usan las reservas guardadas en este dispositivo.',
  );

  void _validateId(String value) {
    if (value.trim().isEmpty || value != value.trim()) {
      throw const ReservationCloudRepositoryException(
        ReservationCloudFailureType.invalidData,
        'Se requiere un identificador válido para sincronizar las reservas.',
      );
    }
  }

  ReservationCloudRepositoryException _map(FirebaseException error) {
    debugPrint('Firestore reservations error: ${error.code}');
    return switch (error.code) {
      'permission-denied' ||
      'unauthenticated' => const ReservationCloudRepositoryException(
        ReservationCloudFailureType.permissionDenied,
        'No tienes permisos para sincronizar estas reservas.',
      ),
      'unavailable' || 'deadline-exceeded' => _offline,
      _ => const ReservationCloudRepositoryException(
        ReservationCloudFailureType.unknown,
        'No se pudieron sincronizar las reservas con Firebase.',
      ),
    };
  }
}
