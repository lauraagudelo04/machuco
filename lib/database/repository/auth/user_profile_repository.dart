import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

/// Category of a [UserProfileRepositoryException], so callers can treat
/// network errors (retryable, session kept) differently from the rest.
enum UserProfileFailureType { permissionDenied, network, unknown }

/// Error of a [UserProfileRepository]; [message] is safe to show (Spanish).
class UserProfileRepositoryException implements Exception {
  const UserProfileRepositoryException(this.type, this.message);

  final UserProfileFailureType type;
  final String message;

  @override
  String toString() => message;
}

/// Contract to persist and read user profiles, independent of the provider.
abstract interface class UserProfileRepository {
  /// Creates `users/{profile.uid}`. Fails if the backend rules reject it.
  Future<void> createProfile(UserProfile profile);

  /// Returns the profile or `null` when no document exists.
  Future<UserProfile?> getProfile(String uid);

  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
  });

  /// Clears `mustChangePassword` after the user replaces the temporary
  /// password. `firestore.rules` only allows it when it was `true`.
  Future<void> clearMustChangePassword(String uid);

  /// Deletes `users/{uid}`. Idempotent: succeeds if the document is already
  /// gone. Only the owner of the profile may delete it (`firestore.rules`).
  Future<void> deleteProfile(String uid);
}

/// [UserProfileRepository] backed by Cloud Firestore. Authorization is
/// enforced by `firestore.rules`, not by this class.
class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection(FirestoreCollections.users).doc(uid);

  @override
  Future<void> createProfile(UserProfile profile) async {
    try {
      await _doc(profile.uid).set(profile.toFirestore());
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<UserProfile?> getProfile(String uid) async {
    try {
      final snapshot = await _doc(uid).get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return UserProfile.fromFirestore(uid, data);
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
  }) async {
    try {
      await _doc(
        uid,
      ).update({'fullName': fullName, 'phoneNumber': phoneNumber});
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> clearMustChangePassword(String uid) async {
    try {
      await _doc(uid).update({'mustChangePassword': false});
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> deleteProfile(String uid) async {
    try {
      await _doc(uid).delete();
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  UserProfileRepositoryException _map(FirebaseException e) {
    debugPrint('Firestore users error: ${e.code}');
    return switch (e.code) {
      'permission-denied' ||
      'unauthenticated' => const UserProfileRepositoryException(
        UserProfileFailureType.permissionDenied,
        'No tienes permisos para realizar esta operación.',
      ),
      'unavailable' ||
      'deadline-exceeded' => const UserProfileRepositoryException(
        UserProfileFailureType.network,
        'No hay conexión. Revisa tu internet e intenta nuevamente.',
      ),
      _ => const UserProfileRepositoryException(
        UserProfileFailureType.unknown,
        'Ocurrió un error inesperado. Intenta nuevamente.',
      ),
    };
  }
}
