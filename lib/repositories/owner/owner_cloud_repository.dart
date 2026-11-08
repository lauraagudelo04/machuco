import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/models/owner_management/owner_firestore_document.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

enum OwnerCloudFailureType { permissionDenied, network, invalidData, unknown }

class OwnerCloudRepositoryException implements Exception {
  const OwnerCloudRepositoryException(this.type, this.message);

  final OwnerCloudFailureType type;
  final String message;

  @override
  String toString() => message;
}

/// Contrato remoto de propietarios. El controlador depende de esta interfaz
/// para poder usar un doble en los tests.
abstract interface class OwnerCloudRepository {
  Future<void> saveOwner({required String adminId, required Owner owner});

  Future<List<Owner>> listOwners();

  Future<void> deleteOwner(String ownerId);
}

class FirestoreOwnerCloudRepository implements OwnerCloudRepository {
  FirestoreOwnerCloudRepository({
    FirebaseFirestore? firestore,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Duration requestTimeout;

  CollectionReference<Map<String, dynamic>> get _owners =>
      _firestore.collection(FirestoreCollections.owners);

  @override
  Future<void> saveOwner({
    required String adminId,
    required Owner owner,
  }) async {
    _validateId(owner.id, 'propietario');
    _validateId(adminId, 'administrador');
    try {
      final document = OwnerFirestoreDocument(owner: owner, updatedBy: adminId);
      await _owners
          .doc(owner.id)
          .set(document.toFirestore())
          .timeout(requestTimeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.network,
        'Sin conexión: el propietario permanece guardado en este dispositivo.',
      );
    }
  }

  @override
  Future<List<Owner>> listOwners() async {
    try {
      final snapshot = await _owners.get().timeout(requestTimeout);
      return List.unmodifiable(
        snapshot.docs.map((document) {
          final remote = OwnerFirestoreDocument.fromFirestore(
            document.id,
            document.data(),
          );
          return remote.owner;
        }),
      );
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.network,
        'Sin conexión: se muestran los propietarios guardados en este dispositivo.',
      );
    } on FormatException {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.invalidData,
        'Firebase devolvió propietarios con datos inválidos. Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> deleteOwner(String ownerId) async {
    _validateId(ownerId, 'propietario');
    try {
      await _owners.doc(ownerId).delete().timeout(requestTimeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.network,
        'Sin conexión: no se pudo eliminar el propietario de la nube.',
      );
    }
  }

  void _validateId(String value, String label) {
    if (value.trim().isEmpty || value != value.trim()) {
      throw OwnerCloudRepositoryException(
        OwnerCloudFailureType.invalidData,
        'Se requiere un identificador válido del $label para sincronizar.',
      );
    }
  }

  OwnerCloudRepositoryException _map(FirebaseException error) {
    debugPrint('Firestore owners error: ${error.code}');
    return switch (error.code) {
      'permission-denied' ||
      'unauthenticated' => const OwnerCloudRepositoryException(
        OwnerCloudFailureType.permissionDenied,
        'No tienes permisos para administrar los propietarios.',
      ),
      'unavailable' ||
      'deadline-exceeded' => const OwnerCloudRepositoryException(
        OwnerCloudFailureType.network,
        'Sin conexión: el propietario permanece guardado en este dispositivo.',
      ),
      _ => const OwnerCloudRepositoryException(
        OwnerCloudFailureType.unknown,
        'No se pudieron sincronizar los propietarios con Firebase.',
      ),
    };
  }
}
