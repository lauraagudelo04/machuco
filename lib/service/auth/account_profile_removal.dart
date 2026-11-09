import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/service/auth/auth_service.dart';

/// Removes the Firestore side of "Eliminar cuenta", shared by the password
/// and the social services. Call it AFTER reauthenticating and BEFORE
/// `User.delete()`.
///
/// - Administrator: anonymizes `users/{uid}` (decisions stay auditable) and
///   fails with [AuthFailureType.lastAdministrator], without changes, if it is
///   the only active one. An already anonymized profile (retry after
///   `User.delete()` failed) is skipped, so the retry only deletes the user.
/// - Any other role (or no profile): deletes `users/{uid}` as before.
Future<void> removeOrAnonymizeProfile({
  required UserProfileRepository profiles,
  required AdministratorsRepository administrators,
  required String uid,
}) async {
  try {
    final profile = await profiles.getProfile(uid);
    if (profile != null && profile.role == RegisteredUserRole.admin) {
      if (profile.accountStatus != AccountStatus.anonymized) {
        await administrators.anonymizeOwnAccount();
      }
      return;
    }
    await profiles.deleteProfile(uid);
  } on UserProfileRepositoryException catch (e) {
    throw AuthFailure(
      e.type == UserProfileFailureType.network
          ? AuthFailureType.network
          : AuthFailureType.unknown,
      e.message,
    );
  } on AdministratorsRepositoryException catch (e) {
    throw AuthFailure(switch (e.type) {
      AdministratorsFailureType.lastAdmin => AuthFailureType.lastAdministrator,
      AdministratorsFailureType.network => AuthFailureType.network,
      _ => AuthFailureType.unknown,
    }, e.message);
  }
}
