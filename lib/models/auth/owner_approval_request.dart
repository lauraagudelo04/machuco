import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/models/owner_management/document_type.dart';

/// Solicitud de cuenta de propietario pendiente de aprobación por un
/// administrador (perfil `users/{uid}` con `accountStatus: pending_approval`).
class OwnerApplication {
  const OwnerApplication({
    required this.uid,
    required this.firstNames,
    required this.lastNames,
    required this.email,
    required this.phoneNumber,
    required this.personType,
    required this.nit,
    required this.createdAt,
    this.companyName,
    this.planId,
    this.documentType,
    this.documentNumber,
  });

  /// Construye la solicitud desde un perfil; tolera perfiles antiguos que solo
  /// tienen `fullName`.
  factory OwnerApplication.fromProfile(UserProfile profile) {
    final hasSplitNames =
        (profile.firstNames ?? '').isNotEmpty ||
        (profile.lastNames ?? '').isNotEmpty;
    return OwnerApplication(
      uid: profile.uid,
      firstNames: hasSplitNames ? profile.firstNames ?? '' : profile.fullName,
      lastNames: hasSplitNames ? profile.lastNames ?? '' : '',
      email: profile.email,
      phoneNumber: profile.phoneNumber,
      personType: profile.personType,
      nit: profile.nit,
      companyName: profile.companyName,
      planId: profile.planId,
      documentType: profile.documentType,
      documentNumber: profile.documentNumber,
      createdAt: profile.createdAt,
    );
  }

  final String uid;
  final String firstNames;
  final String lastNames;
  final String email;

  /// Celular con indicativo.
  final String phoneNumber;

  /// `null` si el perfil no lo trae (datos anteriores al registro por rol).
  final PersonType? personType;
  final String? nit;
  final String? companyName;
  final int? planId;

  /// Documento de identidad (del representante legal si es persona jurídica).
  final DocumentType? documentType;
  final String? documentNumber;
  final DateTime? createdAt;

  String get fullName => '$firstNames $lastNames'.trim();
}
