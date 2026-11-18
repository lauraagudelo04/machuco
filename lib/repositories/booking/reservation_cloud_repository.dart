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

class FirestoreReservationCloudRepository
    implements ReservationCloudRepository {
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
      if (reservation.status == ReservationStatus.cancelled &&
          reservation.cancellationActor != null) {
        try {
          await _commitCancellation(
            ownerId,
            reservation,
          ).timeout(requestTimeout);
        } on FirebaseException catch (error) {
          // Never silently cancel a paid card without its refund when the
          // server still has older rules or rejects the atomic ledger change.
          if (error.code == 'permission-denied' &&
              reservation.cancellationActor == 'client' &&
              ['Tarjeta de crédito', 'Tarjeta de débito']
                  .contains(reservation.paymentMethod)) {
            rethrow;
          }
          if (!['not-found', 'permission-denied'].contains(error.code)) {
            rethrow;
          }
          // A payment removed in the console must not prevent cancellation.
          // Rules only permit this fallback if no pending payment needs updating.
          await _commitCancellation(
            ownerId,
            reservation,
            skipPendingPayment: true,
          ).timeout(requestTimeout);
        }
        return;
      }
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

  Future<void> _commitCancellation(
    String ownerId,
    Reservation reservation, {
    bool skipPendingPayment = false,
  }) async {
    final reservationRef = _reservations.doc(reservation.id);
    final paymentRef = _firestore
        .collection(FirestoreCollections.payments)
        .doc('pay-${reservation.id}');
    await _firestore.runTransaction((transaction) async {
      final before = (await transaction.get(reservationRef)).data();
      if (before == null ||
          before['ownerId'] != ownerId ||
          before['guestId'] != reservation.guestId ||
          before['motelId'] != reservation.motelId) {
        throw const ReservationCloudRepositoryException(
          ReservationCloudFailureType.invalidData,
          'La reserva no coincide con Firebase. Actualiza antes de cancelar.',
        );
      }
      final actor = reservation.cancellationActor;
      if (before['status'] == 'cancelled') {
        if (before['cancellationActor'] == actor &&
            before['cancellationReason'] == reservation.cancellationReason) {
          return;
        }
        throw const ReservationCloudRepositoryException(
          ReservationCloudFailureType.invalidData,
          'La reserva ya fue cancelada. Actualiza para consultar su estado.',
        );
      }
      if (!['pending', 'upcoming'].contains(before['status'])) {
        throw const ReservationCloudRepositoryException(
          ReservationCloudFailureType.invalidData,
          'La reserva ya no se puede cancelar. Actualiza para consultar su estado.',
        );
      }
      String? paymentStatus;
      if (actor == 'owner' && !skipPendingPayment) {
        final payment = (await transaction.get(paymentRef)).data();
        if (payment != null) {
          if (payment['bookingId'] != reservation.id ||
              payment['ownerId'] != ownerId ||
              payment['clientId'] != reservation.guestId ||
              payment['motelId'] != reservation.motelId ||
              payment['roomId'] != before['roomId'] ||
              payment['amount'] != before['total']) {
            throw const ReservationCloudRepositoryException(
              ReservationCloudFailureType.invalidData,
              'El pago no corresponde a esta reserva. Actualiza los datos.',
            );
          }
          if (payment['status'] == 'paid') paymentStatus = 'refunded';
          if (payment['status'] == 'pending') paymentStatus = 'cancelled';
        }
      } else if (actor == 'client' &&
          before['status'] == 'upcoming' &&
          [
            'Tarjeta de crédito',
            'Tarjeta de débito',
          ].contains(before['paymentMethod']) &&
          !skipPendingPayment) {
        // Clients cannot read Payment. Rules validate the paid card ledger and
        // commit the refund together with this reservation's cancellation.
        paymentStatus = 'refunded';
      } else if (actor == 'client' &&
          before['status'] == 'pending' &&
          before['paymentMethod'] == 'En el Local' &&
          !skipPendingPayment) {
        // Client has no Payment read access. The rules validate the existing
        // pending record and both changes together.
        paymentStatus = 'cancelled';
      }
      transaction.update(reservationRef, {
        'status': 'cancelled',
        'cancellationReason': reservation.cancellationReason,
        'cancellationActor': actor,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (paymentStatus != null) {
        transaction.update(paymentRef, {
          'status': paymentStatus,
          'cancellationActor': actor,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
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
      final snapshot = await query
          .get(const GetOptions(source: Source.server))
          .timeout(requestTimeout);
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        throw _offline;
      }
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
