import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs.dart';

/// Presentation of the PQRS enums: the model stays pure Dart, so every label,
/// colour and icon lives here in the view layer.

extension PqrsTypePresentation on PqrsType {
  String get label => switch (this) {
    PqrsType.peticion => 'Petición',
    PqrsType.queja => 'Queja',
    PqrsType.reclamo => 'Reclamo',
    PqrsType.sugerencia => 'Sugerencia',
  };

  IconData get icon => switch (this) {
    PqrsType.peticion => Icons.request_page_outlined,
    PqrsType.queja => Icons.sentiment_dissatisfied_outlined,
    PqrsType.reclamo => Icons.report_gmailerrorred_outlined,
    PqrsType.sugerencia => Icons.lightbulb_outline,
  };
}

extension PqrsStatusPresentation on PqrsStatus {
  String get label => switch (this) {
    PqrsStatus.pending => 'Pendiente',
    PqrsStatus.inProgress => 'En trámite',
    PqrsStatus.resolved => 'Solucionada',
    PqrsStatus.closed => 'Cerrada',
    PqrsStatus.rejected => 'Rechazada',
  };

  Color get color => switch (this) {
    PqrsStatus.pending => AppColors.maintenance,
    PqrsStatus.inProgress => AppColors.reserved,
    PqrsStatus.resolved => AppColors.available,
    PqrsStatus.closed => AppColors.violet,
    PqrsStatus.rejected => AppColors.rose,
  };

  IconData get icon => switch (this) {
    PqrsStatus.pending => Icons.hourglass_empty_outlined,
    PqrsStatus.inProgress => Icons.autorenew,
    PqrsStatus.resolved => Icons.verified_outlined,
    PqrsStatus.closed => Icons.lock_outline,
    PqrsStatus.rejected => Icons.cancel_outlined,
  };
}

extension PqrsActorPresentation on PqrsActor {
  String get label => switch (this) {
    PqrsActor.client => 'Cliente',
    PqrsActor.owner => 'Propietario',
    PqrsActor.systemAdmin => 'Administrador',
  };

  IconData get icon => switch (this) {
    PqrsActor.client => Icons.person_outline,
    PqrsActor.owner => Icons.storefront_outlined,
    PqrsActor.systemAdmin => Icons.admin_panel_settings_outlined,
  };

  Color get color => switch (this) {
    PqrsActor.client => AppColors.fuchsia,
    PqrsActor.owner => AppColors.reserved,
    PqrsActor.systemAdmin => AppColors.violet,
  };
}

/// Shared date formatting so the three profiles show identical timestamps.
String formatPqrsDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String formatPqrsDateTime(DateTime date) =>
    '${formatPqrsDate(date)} · ${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';
