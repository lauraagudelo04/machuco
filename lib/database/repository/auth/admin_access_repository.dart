import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/owner_approval_request.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

enum AdminAccessFailureType {
  /// La solicitud ya no está pendiente (otro administrador la atendió).
  alreadyHandled,
  permissionDenied,
  network,
  invalidInput,
  unknown,
}

/// Error de un [AdminAccessRepository]; [message] es seguro de mostrar.
class AdminAccessRepositoryException implements Exception {
  const AdminAccessRepositoryException(this.type, this.message);

  final AdminAccessFailureType type;
  final String message;

  @override
  String toString() => message;
}

/// Contrato para que un administrador atienda las solicitudes de cuenta de
/// propietarios. La autorización real está en `firestore.rules`.
abstract interface class AdminAccessRepository {
  /// Propietarios con `accountStatus == pending_approval`, del más antiguo al
  /// más reciente.
  Future<List<OwnerApplication>> listPendingOwners();

  /// Pasa la cuenta a `active`. Falla con
  /// [AdminAccessFailureType.alreadyHandled] si ya no estaba pendiente.
  Future<void> approveOwner(String uid);

  /// Pasa la cuenta a `rejected` con [reason] (10 a 300 caracteres).
  Future<void> rejectOwner(String uid, {required String reason});

  /// `true` si otra cuenta de propietario (distinta de [excludeUid]) ya usa
  /// ese NIT (formato canónico `base-DV`). Solo informa: no bloquea.
  Future<bool> isNitUsedByAnotherOwner({
    required String nit,
    required String excludeUid,
  });
}

/// [AdminAccessRepository] sobre Cloud Firestore (`users`).
class FirestoreAdminAccessRepository implements AdminAccessRepository {
  FirestoreAdminAccessRepository({
    FirebaseFirestore? firestore,
    String? Function()? currentAdminUid,
  }) : _injectedFirestore = firestore,
       _injectedAdminUid = currentAdminUid;

  static const alreadyHandledMessage = 'La solicitud ya fue atendida';

  final FirebaseFirestore? _injectedFirestore;
  final String? Function()? _injectedAdminUid;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  String? get _adminUid =>
      (_injectedAdminUid ?? () => FirebaseAuth.instance.currentUser?.uid)();

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);

  @override
  Future<List<OwnerApplication>> listPendingOwners() async {
    try {
      // Requiere el índice compuesto de `firestore.indexes.json`.
      final snapshot = await _users
          .where('role', isEqualTo: RegisteredUserRole.owner.metadataValue)
          .where(
            'accountStatus',
            isEqualTo: AccountStatus.pendingApproval.storageValue,
          )
          .orderBy('createdAt')
          .limit(100)
          .get();
      return [
        for (final doc in snapshot.docs)
          OwnerApplication.fromProfile(
            UserProfile.fromFirestore(doc.id, doc.data()),
          ),
      ];
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> approveOwner(String uid) => _resolve(uid, (adminUid) {
    return {
      'accountStatus': AccountStatus.active.storageValue,
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
    };
  });

  @override
  Future<void> rejectOwner(String uid, {required String reason}) {
    final trimmed = reason.trim();
    if (trimmed.length < 10 || trimmed.length > 300) {
      throw const AdminAccessRepositoryException(
        AdminAccessFailureType.invalidInput,
        'El motivo debe tener entre 10 y 300 caracteres.',
      );
    }
    return _resolve(uid, (adminUid) {
      return {
        'accountStatus': AccountStatus.rejected.storageValue,
        'rejectionReason': trimmed,
        'rejectedBy': adminUid,
        'rejectedAt': FieldValue.serverTimestamp(),
      };
    });
  }

  @override
  Future<bool> isNitUsedByAnotherOwner({
    required String nit,
    required String excludeUid,
  }) async {
    try {
      final snapshot = await _users
          .where('role', isEqualTo: RegisteredUserRole.owner.metadataValue)
          .where('nit', isEqualTo: nit)
          .limit(5)
          .get();
      return snapshot.docs.any((doc) => doc.id != excludeUid);
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  /// Transacción: solo actualiza si el propietario sigue pendiente.
  Future<void> _resolve(
    String uid,
    Map<String, Object?> Function(String adminUid) changes,
  ) async {
    final adminUid = _adminUid;
    if (adminUid == null || adminUid.isEmpty || uid.trim().isEmpty) {
      throw const AdminAccessRepositoryException(
        AdminAccessFailureType.permissionDenied,
        'No tienes permisos para realizar esta operación.',
      );
    }
    final ref = _users.doc(uid);
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final data = snapshot.data();
        final isPending =
            snapshot.exists &&
            data != null &&
            accountStatusFromStorage(data['accountStatus']?.toString()) ==
                AccountStatus.pendingApproval &&
            roleFromMetadataValue(data['role']?.toString() ?? '') ==
                RegisteredUserRole.owner;
        if (!isPending) {
          throw const AdminAccessRepositoryException(
            AdminAccessFailureType.alreadyHandled,
            alreadyHandledMessage,
          );
        }
        transaction.update(ref, changes(adminUid));
      });
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  AdminAccessRepositoryException _map(FirebaseException e) {
    debugPrint('Firestore admin access error: ${e.code}');
    return switch (e.code) {
      'permission-denied' ||
      'unauthenticated' => const AdminAccessRepositoryException(
        AdminAccessFailureType.permissionDenied,
        'No tienes permisos para realizar esta operación.',
      ),
      'unavailable' ||
      'deadline-exceeded' => const AdminAccessRepositoryException(
        AdminAccessFailureType.network,
        'No hay conexión. Revisa tu internet e intenta nuevamente.',
      ),
      'failed-precondition' => const AdminAccessRepositoryException(
        AdminAccessFailureType.unknown,
        'Falta configurar un índice en la base de datos. Avisa al equipo.',
      ),
      _ => const AdminAccessRepositoryException(
        AdminAccessFailureType.unknown,
        'Ocurrió un error inesperado. Intenta nuevamente.',
      ),
    };
  }
}

/// Implementación en memoria para pruebas y desarrollo sin Firebase.
class InMemoryAdminAccessRepository implements AdminAccessRepository {
  InMemoryAdminAccessRepository(Iterable<OwnerApplication> pending)
    : _pending = List.of(pending);

  final List<OwnerApplication> _pending;

  /// NIT (`base-DV`) -> uids de los propietarios que lo usan.
  final Map<String, Set<String>> nitOwners = {};

  /// Para simular fallos: si no es `null` se lanza en la siguiente operación.
  AdminAccessRepositoryException? failNext;

  final List<String> approvedUids = [];
  final Map<String, String> rejected = {};

  @override
  Future<List<OwnerApplication>> listPendingOwners() async {
    _throwIfFailing();
    return List.unmodifiable(_pending);
  }

  @override
  Future<void> approveOwner(String uid) async {
    _throwIfFailing();
    _removePending(uid);
    approvedUids.add(uid);
  }

  @override
  Future<void> rejectOwner(String uid, {required String reason}) async {
    _throwIfFailing();
    _removePending(uid);
    rejected[uid] = reason.trim();
  }

  @override
  Future<bool> isNitUsedByAnotherOwner({
    required String nit,
    required String excludeUid,
  }) async {
    _throwIfFailing();
    return (nitOwners[nit] ?? const <String>{}).any((uid) => uid != excludeUid);
  }

  void _removePending(String uid) {
    final index = _pending.indexWhere((owner) => owner.uid == uid);
    if (index == -1) {
      throw const AdminAccessRepositoryException(
        AdminAccessFailureType.alreadyHandled,
        FirestoreAdminAccessRepository.alreadyHandledMessage,
      );
    }
    _pending.removeAt(index);
  }

  void _throwIfFailing() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }
}
