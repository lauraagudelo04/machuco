import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/booking/reservation_payment_terms.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_firestore_document.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

enum PaymentCloudFailureType { permissionDenied, network, invalidData, unknown }

class PaymentCloudRepositoryException implements Exception {
  const PaymentCloudRepositoryException(this.type, this.message);

  final PaymentCloudFailureType type;
  final String message;

  @override
  String toString() => message;
}

/// Remote payment contract. Controllers depend on this interface in tests.
abstract interface class PaymentCloudRepository {
  Future<void> savePayment({
    required String ownerId,
    required PaymentRecord payment,
    String? paymentMethodName,
  });

  Future<List<PaymentRecord>> listForOwnerAndMotel({
    required String ownerId,
    required String motelId,
  });
}

class FirestorePaymentCloudRepository implements PaymentCloudRepository {
  FirestorePaymentCloudRepository({
    FirebaseFirestore? firestore,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Duration requestTimeout;

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection(FirestoreCollections.payments);

  @override
  Future<void> savePayment({
    required String ownerId,
    required PaymentRecord payment,
    String? paymentMethodName,
  }) async {
    _validateId(ownerId);
    try {
      final document = PaymentFirestoreDocument(
        ownerId: ownerId,
        payment: payment,
        paymentMethodName: paymentMethodName,
      );
      if (payment.id == ReservationPaymentTerms.paymentId(payment.bookingId)) {
        await _saveLinkedPayment(document).timeout(requestTimeout);
      } else {
        // Historical records keep their id; rules only allow updating them.
        await _payments
            .doc(payment.id)
            .set(document.toFirestore())
            .timeout(requestTimeout);
      }
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const PaymentCloudRepositoryException(
        PaymentCloudFailureType.network,
        'Sin conexión: el pago permanece guardado en este dispositivo.',
      );
    }
  }

  /// The payment and reservation are committed together remotely. A failed
  /// transaction leaves the SQLite receipt intact for an explicit retry.
  Future<void> _saveLinkedPayment(PaymentFirestoreDocument document) async {
    final payment = document.payment;
    final reservationRef = _firestore
        .collection(FirestoreCollections.reservations)
        .doc(payment.bookingId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reservationRef);
      final reservation = snapshot.data();
      if (reservation == null ||
          reservation['ownerId'] != document.ownerId ||
          reservation['guestId'] != payment.clientId ||
          reservation['motelId'] != payment.motelId ||
          reservation['roomId'] != payment.roomId ||
          reservation['total'] != payment.amount ||
          reservation['checkIn'] !=
              Timestamp.fromDate(payment.reservationDate)) {
        throw const PaymentCloudRepositoryException(
          PaymentCloudFailureType.invalidData,
          'El pago no coincide con la reserva en Firebase. Actualiza los datos.',
        );
      }
      final status = reservation['status'];
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (payment.status == PaymentStatus.pending) {
        if (status != 'pending' ||
            (reservation['paymentMethod'] != null &&
                reservation['paymentMethod'] !=
                    ReservationPaymentTerms.payAtProperty)) {
          throw const PaymentCloudRepositoryException(
            PaymentCloudFailureType.invalidData,
            'La reserva ya no admite un pago pendiente. Actualiza los datos.',
          );
        }
        updates['paymentMethod'] = ReservationPaymentTerms.payAtProperty;
      } else if (payment.status == PaymentStatus.paid) {
        if (![
          'pending',
          'upcoming',
          'active',
          'completed',
          'cancelled',
        ].contains(status)) {
          throw const PaymentCloudRepositoryException(
            PaymentCloudFailureType.invalidData,
            'La reserva ya no admite recibir el pago. El comprobante local se conserva.',
          );
        }
        if (document.paymentMethodName == null ||
            payment.paidAt == null ||
            payment.paymentMethodId == null ||
            payment.receiptNumber == null) {
          throw const PaymentCloudRepositoryException(
            PaymentCloudFailureType.invalidData,
            'Faltan el método, la fecha o el comprobante del pago recibido.',
          );
        }
        // Rules distinguish a new receipt from a replay and reject receiving
        // money for a cancelled reservation. No read of a possibly missing
        // payment is needed (the client has no Payment read permission).
        if (status == 'pending') {
          updates['status'] = DateTime.now().isBefore(payment.reservationDate)
              ? 'upcoming'
              : 'active';
          updates['paymentMethod'] = document.paymentMethodName;
          updates['invoiceAccessStatus'] = 'pending';
        }
      }
      transaction.set(_payments.doc(payment.id), document.toFirestore());
      // Never reset a paid/cancelled reservation during an idempotent replay.
      if (updates.length > 1) transaction.update(reservationRef, updates);
    });
  }

  @override
  Future<List<PaymentRecord>> listForOwnerAndMotel({
    required String ownerId,
    required String motelId,
  }) async {
    _validateId(ownerId);
    _validateId(motelId);
    try {
      final snapshot = await _payments
          .where('ownerId', isEqualTo: ownerId)
          .where('motelId', isEqualTo: motelId)
          .get()
          .timeout(requestTimeout);
      return List.unmodifiable(
        snapshot.docs.map((document) {
          final remote = PaymentFirestoreDocument.fromFirestore(
            document.id,
            document.data(),
          );
          if (remote.ownerId != ownerId || remote.payment.motelId != motelId) {
            throw const FormatException(
              'Pago remoto fuera del alcance solicitado.',
            );
          }
          return remote.payment;
        }),
      );
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const PaymentCloudRepositoryException(
        PaymentCloudFailureType.network,
        'Sin conexión: se muestran los pagos guardados en este dispositivo.',
      );
    } on FormatException {
      throw const PaymentCloudRepositoryException(
        PaymentCloudFailureType.invalidData,
        'Firebase devolvió pagos con datos inválidos. Inténtalo nuevamente.',
      );
    }
  }

  void _validateId(String value) {
    if (value.trim().isEmpty || value != value.trim()) {
      throw const PaymentCloudRepositoryException(
        PaymentCloudFailureType.invalidData,
        'Se requiere un identificador válido para sincronizar los pagos.',
      );
    }
  }

  PaymentCloudRepositoryException _map(FirebaseException error) {
    debugPrint('Firestore payments error: ${error.code}');
    return switch (error.code) {
      'permission-denied' ||
      'unauthenticated' => const PaymentCloudRepositoryException(
        PaymentCloudFailureType.permissionDenied,
        'No tienes permisos para sincronizar los pagos de este motel.',
      ),
      'unavailable' ||
      'deadline-exceeded' => const PaymentCloudRepositoryException(
        PaymentCloudFailureType.network,
        'Sin conexión: el pago permanece guardado en este dispositivo.',
      ),
      _ => const PaymentCloudRepositoryException(
        PaymentCloudFailureType.unknown,
        'No se pudieron sincronizar los pagos con Firebase.',
      ),
    };
  }
}
