import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/person_type.dart';
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
    this.firstNames,
    this.lastNames,
    this.phoneCountryCodeId,
    this.birthDate,
    this.personType,
    this.nit,
    this.companyName,
    this.planId,
    this.rejectionReason,
    this.mustChangePassword = false,
    this.createdBy,
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

  // The fields below are optional so profiles written before the role-based
  // sign-up (which only have `fullName`) keep loading.

  final String? firstNames;
  final String? lastNames;

  /// Id of the `phone_country_codes` master row chosen at sign-up.
  final int? phoneCountryCodeId;

  /// Clients only. Sensitive: stored in Firestore, never in SQLite or
  /// SharedPreferences.
  final DateTime? birthDate;

  /// Owners only.
  final PersonType? personType;

  /// Owners only (`base-DV`). Sensitive: Firestore only, never local.
  final String? nit;

  /// Legal name; owners with [PersonType.juridica].
  final String? companyName;

  /// Subscription plan chosen by an owner at sign-up (Supabase
  /// `subscription_plans.id`).
  final int? planId;

  /// Reason given by the admin when the account was rejected.
  final String? rejectionReason;

  /// Administrators created by another administrator start with a temporary
  /// password and must replace it on first sign-in. Missing means `false`.
  final bool mustChangePassword;

  /// Uid of the administrator who created this account (admins only).
  final String? createdBy;

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
      createdAt: _dateOrNull(rawCreatedAt),
      firstNames: _textOrNull(data['firstNames']),
      lastNames: _textOrNull(data['lastNames']),
      phoneCountryCodeId: _intOrNull(data['phoneCountryCodeId']),
      birthDate: _dateOrNull(data['birthDate']),
      personType: personTypeFromMetadata(data['personType']?.toString()),
      nit: _textOrNull(data['nit']),
      companyName: _textOrNull(data['companyName']),
      planId: _intOrNull(data['planId']),
      rejectionReason: _textOrNull(data['rejectionReason']),
      mustChangePassword: data['mustChangePassword'] == true,
      createdBy: _textOrNull(data['createdBy']),
    );
  }

  /// Document written on creation. `createdAt` is assigned by the server.
  Map<String, dynamic> toFirestore() {
    final birth = birthDate;
    final type = personType;
    return <String, dynamic>{
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role.metadataValue,
      'accountStatus':
          (accountStatus ?? AccountStatus.pendingApproval).storageValue,
      'createdAt': FieldValue.serverTimestamp(),
      // Optional fields are omitted when null: `firestore.rules` validates the
      // exact key set per role.
      if (firstNames != null) 'firstNames': firstNames,
      if (lastNames != null) 'lastNames': lastNames,
      if (phoneCountryCodeId != null) 'phoneCountryCodeId': phoneCountryCodeId,
      if (birth != null)
        'birthDate': Timestamp.fromDate(
          DateTime.utc(birth.year, birth.month, birth.day),
        ),
      if (type != null) 'personType': type.metadataValue,
      if (nit != null) 'nit': nit,
      if (companyName != null) 'companyName': companyName,
      if (planId != null) 'planId': planId,
    };
  }

  static String? _textOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _intOrNull(Object? value) => switch (value) {
    int() => value,
    num() => value.toInt(),
    String() => int.tryParse(value),
    _ => null,
  };

  static DateTime? _dateOrNull(Object? value) => switch (value) {
    Timestamp() => value.toDate().toUtc(),
    DateTime() => value.toUtc(),
    _ => null,
  };
}
