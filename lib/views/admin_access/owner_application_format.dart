import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/owner_approval_request.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/widgets/auth/auth_date_format.dart';

/// Nombre a mostrar de una solicitud: razón social si es persona jurídica.
String ownerApplicationTitle(OwnerApplication application) {
  final company = application.companyName;
  if (application.personType == PersonType.juridica &&
      company != null &&
      company.isNotEmpty) {
    return company;
  }
  return application.fullName;
}

String formatApplicationDate(DateTime? date) =>
    date == null ? 'Fecha no disponible' : formatDate(date);

/// Texto que se muestra cuando el administrador que aprobó o rechazó una
/// solicitud (`approvedBy` / `rejectedBy`) fue eliminado y su cuenta quedó
/// anonimizada (AG-13).
const deletedAdministratorLabel = 'Administrador eliminado';

/// Nombre del administrador revisor. Si el perfil ya no existe o está
/// anonimizado, devuelve [deletedAdministratorLabel] en lugar de datos vacíos.
String reviewerDisplayName(UserProfile? reviewer) {
  if (reviewer == null || reviewer.accountStatus == AccountStatus.anonymized) {
    return deletedAdministratorLabel;
  }
  final name = reviewer.fullName.trim();
  return name.isEmpty ? deletedAdministratorLabel : name;
}
