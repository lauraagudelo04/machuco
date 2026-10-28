import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';

/// Profile of a user stored in Firestore at `users/{uid}`.
///
/// Single model for all roles (the role is a field). It deliberately holds no
/// identity document or other sensitive data.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.accountStatus,
    this.createdAt,
  });

  final String uid;
  final String fullName;
  final String email;

  /// Phone number including the country dial code.
  final String phoneNumber;
  final RegisteredUserRole role;

  /// `null` when the stored value is missing or unknown; consumers must not
  /// treat it as active without deciding explicitly.
  final AccountStatus? accountStatus;

  /// `null` for a profile not yet written (the server assigns it).
  final DateTime? createdAt;

  /// Builds a profile from a Firestore document, tolerating missing fields.
  /// A missing/unknown role falls back to client (least privilege).
  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    final rawCreatedAt = data['createdAt'];
    return UserProfile(
      uid: uid,
      fullName: data['fullName']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phoneNumber: data['phoneNumber']?.toString() ?? '',
      role: roleFromMetadataValue(data['role']?.toString() ?? ''),
      accountStatus: accountStatusFromStorage(
        data['accountStatus']?.toString(),
      ),
      createdAt: switch (rawCreatedAt) {
        Timestamp() => rawCreatedAt.toDate().toUtc(),
        DateTime() => rawCreatedAt.toUtc(),
        _ => null,
      },
    );
  }

  /// Document written on creation. `createdAt` is assigned by the server.
  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'fullName': fullName,
    'email': email,
    'phoneNumber': phoneNumber,
    'role': role.metadataValue,
    'accountStatus':
        (accountStatus ?? AccountStatus.pendingApproval).storageValue,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
