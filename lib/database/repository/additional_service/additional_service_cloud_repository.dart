import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/models/additional_service/additional_service_firestore_document.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

enum AdditionalServiceCloudFailureType {
  permissionDenied,
  network,
  invalidData,
  unknown,
}

class AdditionalServiceCloudException implements Exception {
  const AdditionalServiceCloudException(this.type, this.message);

  final AdditionalServiceCloudFailureType type;
  final String message;

  @override
  String toString() => message;
}

/// Contrato remoto de servicios adicionales. Los controllers dependen de esta
/// interfaz para poder probarse sin Firebase.
abstract interface class AdditionalServiceCloudRepository {
  Future<List<AdditionalService>> listByMotel(String motelId);

  /// Crea el servicio y fija a [ownerId] como su creador.
  Future<void> create({
    required String ownerId,
    required AdditionalService service,
  });

  /// Edita un servicio existente sin cambiar su creador ni su motel.
  Future<void> update(AdditionalService service);

  Future<void> delete(String serviceId);
}

class FirestoreAdditionalServiceCloudRepository
    implements AdditionalServiceCloudRepository {
  FirestoreAdditionalServiceCloudRepository({
    FirebaseFirestore? firestore,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Duration requestTimeout;

  CollectionReference<Map<String, dynamic>> get _services =>
      _firestore.collection(FirestoreCollections.additionalServices);

  @override
  Future<List<AdditionalService>> listByMotel(String motelId) async {
    _validateId(motelId);
    try {
      final snapshot = await _services
          .where('motelId', isEqualTo: motelId)
          .get()
          .timeout(requestTimeout);
      return List.unmodifiable(
        snapshot.docs.map(
          (document) => AdditionalServiceFirestoreDocument.fromFirestore(
            document.id,
            document.data(),
          ).service,
        ),
      );
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const AdditionalServiceCloudException(
        AdditionalServiceCloudFailureType.network,
        'Sin conexión: se muestran los servicios guardados en este dispositivo.',
      );
    } on FormatException {
      throw const AdditionalServiceCloudException(
        AdditionalServiceCloudFailureType.invalidData,
        'Firebase devolvió servicios con datos inválidos.',
      );
    }
  }

  @override
  Future<void> create({
    required String ownerId,
    required AdditionalService service,
  }) async {
    _validateId(ownerId);
    _validateId(service.id);
    try {
      final document = AdditionalServiceFirestoreDocument(
        ownerId: ownerId,
        service: service,
      );
      await _services
          .doc(service.id)
          .set(document.toFirestore())
          .timeout(requestTimeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const AdditionalServiceCloudException(
        AdditionalServiceCloudFailureType.network,
        'Sin conexión: no se pudo guardar el servicio. Inténtalo de nuevo.',
      );
    }
  }

  @override
  Future<void> update(AdditionalService service) async {
    _validateId(service.id);
    try {
      await _services
          .doc(service.id)
          .update(AdditionalServiceFirestoreDocument.updateData(service))
          .timeout(requestTimeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const AdditionalServiceCloudException(
        AdditionalServiceCloudFailureType.network,
        'Sin conexión: no se pudo guardar el servicio. Inténtalo de nuevo.',
      );
    }
  }

  @override
  Future<void> delete(String serviceId) async {
    _validateId(serviceId);
    try {
      await _services.doc(serviceId).delete().timeout(requestTimeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const AdditionalServiceCloudException(
        AdditionalServiceCloudFailureType.network,
        'Sin conexión: no se pudo eliminar el servicio. Inténtalo de nuevo.',
      );
    }
  }

  void _validateId(String value) {
    if (value.trim().isEmpty || value != value.trim()) {
      throw const AdditionalServiceCloudException(
        AdditionalServiceCloudFailureType.invalidData,
        'Se requiere un identificador válido para sincronizar el servicio.',
      );
    }
  }

  AdditionalServiceCloudException _map(FirebaseException error) {
    debugPrint('Firestore additionalServices error: ${error.code}');
    return switch (error.code) {
      'permission-denied' ||
      'unauthenticated' => const AdditionalServiceCloudException(
        AdditionalServiceCloudFailureType.permissionDenied,
        'No tienes permisos para gestionar los servicios de este motel.',
      ),
      'unavailable' ||
      'deadline-exceeded' => const AdditionalServiceCloudException(
        AdditionalServiceCloudFailureType.network,
        'Sin conexión con Firebase. Inténtalo de nuevo.',
      ),
      _ => const AdditionalServiceCloudException(
        AdditionalServiceCloudFailureType.unknown,
        'No se pudo sincronizar el servicio con Firebase.',
      ),
    };
  }
}
