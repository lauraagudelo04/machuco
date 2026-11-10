import 'package:machuco/models/auth/owner_approval_request.dart';
import 'package:machuco/models/auth/person_type.dart';
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
