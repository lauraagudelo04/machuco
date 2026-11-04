import 'package:machuco/models/auth/registered_user.dart';

/// Lifecycle state of a user account.
///
/// Stored in `users/{uid}.accountStatus` using [storageValue] (snake_case).
enum AccountStatus { active, pendingApproval, rejected, disabled }

/// Maps an [AccountStatus] to the snake_case value stored in Firestore.
extension AccountStatusStorage on AccountStatus {
  String get storageValue => switch (this) {
    AccountStatus.active => 'active',
    AccountStatus.pendingApproval => 'pending_approval',
    AccountStatus.rejected => 'rejected',
    AccountStatus.disabled => 'disabled',
  };
}

/// Parses a stored status. Missing or unknown values return `null` so the
/// caller decides the safe fallback instead of silently granting access.
AccountStatus? accountStatusFromStorage(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'active' => AccountStatus.active,
    'pending_approval' => AccountStatus.pendingApproval,
    'rejected' => AccountStatus.rejected,
    'disabled' => AccountStatus.disabled,
    _ => null,
  };
}

/// Roles that may be requested through the public sign-up. Admins are never
/// created from the app. Mirrors the `create` rule in `firestore.rules`.
bool isPublicRegistrationRole(RegisteredUserRole role) =>
    role == RegisteredUserRole.client || role == RegisteredUserRole.owner;

/// Initial status for a new public sign-up: clients are active immediately,
/// owners wait for admin approval. Mirrors `firestore.rules`.
AccountStatus initialAccountStatusFor(RegisteredUserRole role) =>
    role == RegisteredUserRole.owner
    ? AccountStatus.pendingApproval
    : AccountStatus.active;
