import 'package:flutter/material.dart';

/// Tipos de documento admitidos para identificar a un propietario.
///
/// Cada valor define cómo se valida y cómo se captura el número asociado, para
/// evitar cadenas libres y condicionales dispersos en la vista.
enum DocumentType {
  citizenshipCard('CC', 'Cédula de ciudadanía', r'^\d{6,10}$', '1020304050'),
  foreignerCard('CE', 'Cédula de extranjería', r'^\d{6,12}$', '345678'),
  taxId(
    'NIT',
    'Número de identificación tributaria',
    r'^\d{9,10}(-\d)?$',
    '900123456-7',
  ),
  passport('Pasaporte', 'Pasaporte', r'^[A-Za-z0-9]{6,12}$', 'AV123456');

  const DocumentType(
    this.shortLabel,
    this.description,
    this.pattern,
    this.example,
  );

  final String shortLabel;
  final String description;
  final String pattern;
  final String example;

  TextInputType get keyboardType => switch (this) {
    DocumentType.passport => TextInputType.text,
    _ => TextInputType.number,
  };

  bool acceptsDocumentNumber(String value) => RegExp(pattern).hasMatch(value);
}

/// Datos de un propietario tal como los maneja la capa de presentación.
///
/// Es una representación temporal: cuando exista la capa de modelos debe
/// reemplazarse por el modelo de dominio correspondiente.
@immutable
class OwnerFormData {
  const OwnerFormData({
    required this.fullName,
    required this.documentType,
    required this.documentNumber,
    required this.email,
    required this.phone,
    this.address,
    this.isActive = true,
  });

  final String fullName;
  final DocumentType documentType;
  final String documentNumber;
  final String email;
  final String phone;
  final String? address;
  final bool isActive;

  /// Documento completo listo para mostrar, por ejemplo `CC 1020304050`.
  String get documentLabel => '${documentType.shortLabel} $documentNumber';

  OwnerFormData copyWith({String? phone, bool? isActive}) => OwnerFormData(
    fullName: fullName,
    documentType: documentType,
    documentNumber: documentNumber,
    email: email,
    phone: phone ?? this.phone,
    address: address,
    isActive: isActive ?? this.isActive,
  );
}
