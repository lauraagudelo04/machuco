import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
      await _payments
          .doc(payment.id)
          .set(document.toFirestore())
          .timeout(requestTimeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const PaymentCloudRepositoryException(
        PaymentCloudFailureType.network,
        'Sin conexión: el pago permanece guardado en este dispositivo.',
      );
    }
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
