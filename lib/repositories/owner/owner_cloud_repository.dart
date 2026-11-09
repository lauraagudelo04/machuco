import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/administrator_models.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/models/owner_management/owner_user_document.dart';
import 'package:machuco/service/auth/auth_account_provisioner.dart';
import 'package:machuco/service/auth/temporary_password_generator.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

enum OwnerCloudFailureType {
  permissionDenied,
  network,
  invalidData,

  /// El correo ya pertenece a otra cuenta: no se creó nada.
  emailInUse,
  unknown,
}

class OwnerCloudRepositoryException implements Exception {
  const OwnerCloudRepositoryException(this.type, this.message);

  final OwnerCloudFailureType type;
  final String message;

  @override
  String toString() => message;
}

/// Resultado de crear un propietario en `users`.
///
/// El [owner] ya lleva el uid definitivo y [temporaryPassword] es la clave que
/// el administrador debe entregar una sola vez: el propietario la cambia en su
/// primer inicio de sesión.
class CreatedOwner {
  const CreatedOwner({required this.owner, required this.temporaryPassword});

  final Owner owner;
  final String temporaryPassword;
}

/// Contrato remoto de propietarios.
///
/// Un propietario es un usuario registrado (`users/{uid}` con
/// `role == 'owner'`), así que crear uno implica crear también su cuenta de
/// Firebase Auth.
abstract interface class OwnerCloudRepository {
  Future<CreatedOwner> createOwner({
    required String adminId,
    required Owner owner,
    required AccountStatus accountStatus,
    int? phoneCountryCodeId,
    String? companyName,
    int? planId,
  });

  Future<void> updateOwner({
    required String adminId,
    required Owner owner,
    int? phoneCountryCodeId,
  });

  /// Cambia `accountStatus` entre `active` y `disabled`.
  Future<void> setOwnerStatus({
    required String ownerId,
    required bool isActive,
  });

  Future<List<Owner>> listOwners();

  Future<void> deleteOwner(String ownerId);
}

class FirestoreOwnerCloudRepository implements OwnerCloudRepository {
  FirestoreOwnerCloudRepository({
    FirebaseFirestore? firestore,
    AuthAccountProvisioner? provisioner,
    String Function()? passwordGenerator,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _provisioner = provisioner ?? FirebaseAuthAccountProvisioner(),
       _generatePassword =
           passwordGenerator ?? (() => TemporaryPasswordGenerator.generate());

  final FirebaseFirestore _firestore;
  final AuthAccountProvisioner _provisioner;
  final String Function() _generatePassword;
  final Duration requestTimeout;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);

  @override
  Future<CreatedOwner> createOwner({
    required String adminId,
    required Owner owner,
    required AccountStatus accountStatus,
    int? phoneCountryCodeId,
    String? companyName,
    int? planId,
  }) async {
    _validateId(adminId, 'administrador');
    _validateEmail(owner.email);

    final password = _generatePassword();
    final ProvisionedAccount account;
    try {
      account = await _provisioner.createAccount(
        email: owner.email.trim(),
        password: password,
      );
    } on AdministratorsRepositoryException catch (error) {
      throw _mapProvisioner(error);
    }

    final created = owner.withId(account.uid);
    try {
      final document = OwnerUserDocument.createMap(
        owner: created,
        accountStatus: accountStatus,
        adminId: adminId,
        phoneCountryCodeId: phoneCountryCodeId,
        companyName: companyName,
        planId: planId,
      );
      await _users.doc(account.uid).set(document).timeout(requestTimeout);
    } on FirebaseException catch (error) {
      // Sin perfil no debe quedar una cuenta de Auth huérfana.
      await account.rollback();
      throw _map(error);
    } on TimeoutException {
      await account.rollback();
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.network,
        'Sin conexión: no se pudo crear el propietario.',
      );
    } finally {
      await account.close();
    }

    return CreatedOwner(
      owner: created.copyWith(
        isSynchronized: true,
        accountStatus: accountStatus,
      ),
      temporaryPassword: password,
    );
  }

  @override
  Future<void> updateOwner({
    required String adminId,
    required Owner owner,
    int? phoneCountryCodeId,
  }) async {
    _validateId(owner.id, 'propietario');
    _validateId(adminId, 'administrador');
    try {
      final document = OwnerUserDocument.updateMap(
        owner: owner,
        adminId: adminId,
        phoneCountryCodeId: phoneCountryCodeId,
      );
      await _users.doc(owner.id).update(document).timeout(requestTimeout);
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
  Future<void> setOwnerStatus({
    required String ownerId,
    required bool isActive,
  }) async {
    _validateId(ownerId, 'propietario');
    try {
      await _users
          .doc(ownerId)
          .update({
            'accountStatus': isActive
                ? AccountStatus.active.storageValue
                : AccountStatus.disabled.storageValue,
          })
          .timeout(requestTimeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.network,
        'Sin conexión: el estado del propietario se actualizará al reintentar.',
      );
    }
  }

  @override
  Future<List<Owner>> listOwners() async {
    try {
      final snapshot = await _users
          .where('role', isEqualTo: RegisteredUserRole.owner.metadataValue)
          .get()
          .timeout(requestTimeout);
      return List.unmodifiable(
        snapshot.docs.map((document) {
          return OwnerUserDocument.fromFirestore(document.id, document.data());
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
      await _users.doc(ownerId).delete().timeout(requestTimeout);
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

  void _validateEmail(String email) {
    final value = email.trim();
    if (value.isEmpty || !value.contains('@')) {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.invalidData,
        'Se requiere un correo válido para crear la cuenta del propietario.',
      );
    }
  }

  OwnerCloudRepositoryException _mapProvisioner(
    AdministratorsRepositoryException error,
  ) => switch (error.type) {
    AdministratorsFailureType.emailInUse => const OwnerCloudRepositoryException(
      OwnerCloudFailureType.emailInUse,
      'Ese correo ya tiene una cuenta. Usa otro correo para el propietario.',
    ),
    AdministratorsFailureType.network => const OwnerCloudRepositoryException(
      OwnerCloudFailureType.network,
      'Sin conexión: no se pudo crear la cuenta del propietario.',
    ),
    _ => const OwnerCloudRepositoryException(
      OwnerCloudFailureType.unknown,
      'No se pudo crear la cuenta del propietario.',
    ),
  };

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
