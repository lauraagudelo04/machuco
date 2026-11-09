import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/auth/administrator_models.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

/// Reads and writes inside one atomic unit. Reads must come before writes
/// (Firestore transactions); the body can run more than once on conflict, so
/// it must only use this object.
abstract interface class AdminTransaction {
  Future<UserProfile?> readProfile(String uid);

  /// `system/adminRegistry.activeAdminCount`, or `null` if the registry does
  /// not exist yet.
  Future<int?> readActiveAdminCount();

  void createAdminProfile(
    String uid,
    NewAdministratorData data, {
    required String createdBy,
  });

  void updateContact(String uid, AdministratorContactChanges changes);

  /// Replaces `users/{uid}` with the anonymized document (see
  /// [FirestoreAdministratorsStore]); [readProfile] must have been called.
  void anonymize(String uid, {required String actorUid});

  void setActiveAdminCount(int count);
}

/// Persistence the administrators repository needs, without the provider.
/// [FirestoreAdministratorsStore] is the real one; tests use an in-memory fake.
abstract interface class AdministratorsStore {
  /// Every `role == admin` profile, anonymized ones included.
  Future<List<UserProfile>> fetchAdministrators();

  Future<UserProfile?> fetchProfile(String uid);

  Future<int> countActiveAdministrators();

  /// Creates `system/adminRegistry` with [initialCount] only if it is missing.
  Future<void> ensureRegistry(int initialCount);

  Future<T> runTransaction<T>(Future<T> Function(AdminTransaction tx) action);

  Future<void> clearMustChangePassword(String uid);
}

/// [AdministratorsStore] on Cloud Firestore. Authorization is enforced by
/// `firestore.rules`, not by this class.
class FirestoreAdministratorsStore implements AdministratorsStore {
  FirestoreAdministratorsStore({FirebaseFirestore? firestore})
    : _injected = firestore;

  /// Collection of `system/adminRegistry` (see `firestore.rules`).
  static const systemCollection = 'system';
  static const registryDocId = 'adminRegistry';
  static const registryField = 'activeAdminCount';

  /// Text kept in `fullName` of an anonymized administrator.
  static const anonymizedName = 'Administrador eliminado';

  final FirebaseFirestore? _injected;

  FirebaseFirestore get _firestore => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);

  DocumentReference<Map<String, dynamic>> get _registry =>
      _firestore.collection(systemCollection).doc(registryDocId);

  @override
  Future<List<UserProfile>> fetchAdministrators() async {
    try {
      final snapshot = await _users
          .where('role', isEqualTo: RegisteredUserRole.admin.metadataValue)
          .get();
      return [
        for (final doc in snapshot.docs)
          UserProfile.fromFirestore(doc.id, doc.data()),
      ];
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<UserProfile?> fetchProfile(String uid) async {
    try {
      final snapshot = await _users.doc(uid).get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return UserProfile.fromFirestore(uid, data);
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<int> countActiveAdministrators() async {
    try {
      final snapshot = await _users
          .where('role', isEqualTo: RegisteredUserRole.admin.metadataValue)
          .where('accountStatus', isEqualTo: 'active')
          .get();
      return snapshot.docs.length;
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> ensureRegistry(int initialCount) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(_registry);
        if (!snapshot.exists) {
          transaction.set(_registry, {
            registryField: initialCount < 1 ? 1 : initialCount,
          });
        }
      });
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(AdminTransaction tx) action,
  ) async {
    try {
      return await _firestore.runTransaction(
        (transaction) =>
            action(_FirestoreAdminTransaction(transaction, _users, _registry)),
      );
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> clearMustChangePassword(String uid) async {
    try {
      await _users.doc(uid).update({'mustChangePassword': false});
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  static AdministratorsRepositoryException _map(FirebaseException e) {
    debugPrint('Firestore administrators error: ${e.code}');
    return switch (e.code) {
      'permission-denied' ||
      'unauthenticated' => const AdministratorsRepositoryException(
        AdministratorsFailureType.permissionDenied,
        'No tienes permisos para realizar esta operación.',
      ),
      'unavailable' ||
      'deadline-exceeded' => const AdministratorsRepositoryException(
        AdministratorsFailureType.network,
        'No hay conexión. Revisa tu internet e intenta nuevamente.',
      ),
      'aborted' => const AdministratorsRepositoryException(
        AdministratorsFailureType.unknown,
        'Otro administrador hizo cambios al mismo tiempo. Intenta nuevamente.',
      ),
      _ => const AdministratorsRepositoryException(
        AdministratorsFailureType.unknown,
        'Ocurrió un error inesperado. Intenta nuevamente.',
      ),
    };
  }
}

final class _FirestoreAdminTransaction implements AdminTransaction {
  _FirestoreAdminTransaction(this._transaction, this._users, this._registry);

  final Transaction _transaction;
  final CollectionReference<Map<String, dynamic>> _users;
  final DocumentReference<Map<String, dynamic>> _registry;

  /// Raw documents read in this attempt (to keep `createdAt` exactly as is).
  final _raw = <String, Map<String, dynamic>>{};

  @override
  Future<UserProfile?> readProfile(String uid) async {
    final snapshot = await _transaction.get(_users.doc(uid));
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    _raw[uid] = data;
    return UserProfile.fromFirestore(uid, data);
  }

  @override
  Future<int?> readActiveAdminCount() async {
    final snapshot = await _transaction.get(_registry);
    if (!snapshot.exists) return null;
    final value = snapshot.data()?[FirestoreAdministratorsStore.registryField];
    if (value is int) return value;
    throw const AdministratorsRepositoryException(
      AdministratorsFailureType.unknown,
      'El registro de administradores es inválido. Avisa al equipo.',
    );
  }

  @override
  void createAdminProfile(
    String uid,
    NewAdministratorData data, {
    required String createdBy,
  }) {
    _transaction.set(_users.doc(uid), {
      'fullName': '${data.firstNames} ${data.lastNames}'.trim(),
      'email': data.email,
      'phoneNumber': data.phoneNumber,
      'role': RegisteredUserRole.admin.metadataValue,
      'accountStatus': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'firstNames': data.firstNames,
      'lastNames': data.lastNames,
      'phoneCountryCodeId': data.phoneCountryCodeId,
      'mustChangePassword': true,
      'createdBy': createdBy,
    });
  }

  @override
  void updateContact(String uid, AdministratorContactChanges changes) {
    _transaction.update(_users.doc(uid), {
      'firstNames': changes.firstNames,
      'lastNames': changes.lastNames,
      'fullName': changes.fullName,
      'phoneCountryCodeId': changes.phoneCountryCodeId,
      'phoneNumber': changes.phoneNumber,
    });
  }

  @override
  void anonymize(String uid, {required String actorUid}) {
    final before = _raw[uid] ?? const <String, dynamic>{};
    // `set` replaces the document: only the allowed keys survive.
    _transaction.set(_users.doc(uid), {
      'fullName': FirestoreAdministratorsStore.anonymizedName,
      'role': RegisteredUserRole.admin.metadataValue,
      'accountStatus': 'anonymized',
      if (before.containsKey('createdAt')) 'createdAt': before['createdAt'],
      if (before.containsKey('createdBy')) 'createdBy': before['createdBy'],
      'anonymizedAt': FieldValue.serverTimestamp(),
      'anonymizedBy': actorUid,
    });
  }

  @override
  void setActiveAdminCount(int count) {
    _transaction.set(_registry, {
      FirestoreAdministratorsStore.registryField: count,
    });
  }
}
