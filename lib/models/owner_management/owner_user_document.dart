import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';

/// Mapeo entre el modelo de dominio [Owner] y el documento `users/{uid}`.
///
/// Los propietarios son usuarios registrados: comparten documento con
/// clientes y administradores y se distinguen por `role == 'owner'`. Por eso
/// aquí conviven los campos del perfil (`fullName`, `email`, `phoneNumber`,
/// `accountStatus`...) con los datos legales que administra el panel
/// (`documentType`, `documentNumber`, `address`).
///
/// `nit` y `personType` se escriben junto a `documentType`/`documentNumber`
/// para que el documento siga siendo válido para el registro público y para
/// las reglas de aprobación (`hasValidOwnerExtras`).
abstract final class OwnerUserDocument {
  /// Campos que el administrador puede escribir al crear la cuenta.
  static const createKeys = <String>{
    'role',
    'accountStatus',
    'createdAt',
    'createdBy',
    'mustChangePassword',
    'fullName',
    'email',
    'phone',
    'phoneNumber',
    'phoneCountryCodeId',
    'documentType',
    'documentNumber',
    'nit',
    'personType',
    'address',
    'countryCode',
    'countryName',
    'companyName',
    'planId',
    'updatedBy',
    'updatedAt',
  };

  /// Campos que el administrador puede modificar después (el correo, el rol y
  /// el estado de la cuenta tienen sus propias reglas).
  static const updateKeys = <String>{
    'fullName',
    'phone',
    'phoneNumber',
    'phoneCountryCodeId',
    'documentType',
    'documentNumber',
    'nit',
    'personType',
    'address',
    'countryCode',
    'countryName',
    'companyName',
    'planId',
    'updatedBy',
    'updatedAt',
  };

  static Owner fromFirestore(String uid, Map<String, dynamic> data) {
    final accountStatus = accountStatusFromStorage(
      _optionalString(data, 'accountStatus'),
    );
    final documentNumber =
        _optionalString(data, 'documentNumber') ??
        _optionalString(data, 'nit') ??
        '';
    final documentType =
        _parseDocumentType(_optionalString(data, 'documentType')) ??
        _documentTypeFromPersonType(_optionalString(data, 'personType'));

    final phoneNumber = _optionalString(data, 'phoneNumber');

    return Owner(
      id: uid,
      fullName: _requiredString(data, 'fullName'),
      documentType: documentType,
      documentNumber: documentNumber,
      email: _requiredString(data, 'email'),
      // Si el documento no separa el indicativo (perfiles del registro), el
      // teléfono queda completo; el formulario lo divide con el catálogo.
      phone: _optionalString(data, 'phone') ?? phoneNumber ?? '',
      countryCode: _optionalString(data, 'countryCode'),
      countryName: _optionalString(data, 'countryName'),
      address: _optionalString(data, 'address'),
      isActive: accountStatus == AccountStatus.active,
      accountStatus: accountStatus,
      isSynchronized: true,
    );
  }

  /// Documento completo para crear la cuenta desde el panel.
  ///
  /// [phoneCountryCodeId] es el id del maestro de indicativos; se omite si el
  /// catálogo aún no cargó para no inventar un valor.
  static Map<String, dynamic> createMap({
    required Owner owner,
    required AccountStatus accountStatus,
    required String adminId,
    int? phoneCountryCodeId,
    String? companyName,
    int? planId,
  }) {
    final map = <String, dynamic>{
      'role': 'owner',
      'accountStatus': accountStatus.storageValue,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': adminId,
      'mustChangePassword': true,
      'fullName': owner.fullName,
      'email': owner.email.trim(),
      'phone': owner.phone,
      'phoneNumber': phoneNumberFor(owner),
      'documentType': owner.documentType.name,
      'documentNumber': owner.documentNumber,
      'nit': owner.documentNumber,
      'personType': personTypeFor(owner.documentType),
      'updatedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (phoneCountryCodeId != null && phoneCountryCodeId > 0) {
      map['phoneCountryCodeId'] = phoneCountryCodeId;
    }
    if (owner.countryCode != null) map['countryCode'] = owner.countryCode;
    if (owner.countryName != null) map['countryName'] = owner.countryName;
    if (owner.address != null) map['address'] = owner.address;
    if (companyName != null && companyName.trim().isNotEmpty) {
      map['companyName'] = companyName.trim();
    }
    if (planId != null && planId > 0) map['planId'] = planId;
    return map;
  }

  /// Documento para actualizar los datos legales y de contacto.
  ///
  /// El correo no se toca: identifica la cuenta de Firebase Auth.
  static Map<String, dynamic> updateMap({
    required Owner owner,
    required String adminId,
    int? phoneCountryCodeId,
  }) {
    final map = <String, dynamic>{
      'fullName': owner.fullName,
      'phone': owner.phone,
      'phoneNumber': phoneNumberFor(owner),
      'documentType': owner.documentType.name,
      'documentNumber': owner.documentNumber,
      'nit': owner.documentNumber,
      'personType': personTypeFor(owner.documentType),
      'updatedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (phoneCountryCodeId != null && phoneCountryCodeId > 0) {
      map['phoneCountryCodeId'] = phoneCountryCodeId;
    }
    if (owner.countryCode != null) map['countryCode'] = owner.countryCode;
    if (owner.countryName != null) map['countryName'] = owner.countryName;
    if (owner.address != null) map['address'] = owner.address;
    return map;
  }

  /// Teléfono completo (`+57` + número nacional) que usa el resto de la app.
  static String phoneNumberFor(Owner owner) {
    final digits = owner.phone.replaceAll(RegExp(r'\D'), '');
    final dial = owner.countryCode?.trim() ?? '';
    return '$dial$digits'.isEmpty ? owner.phone : '$dial$digits';
  }

  /// `personType` del perfil: las empresas (NIT) son jurídicas.
  static String personTypeFor(DocumentType documentType) =>
      documentType == DocumentType.taxId ? 'juridica' : 'natural';

  static DocumentType _documentTypeFromPersonType(String? personType) =>
      personType == 'juridica'
      ? DocumentType.taxId
      : DocumentType.citizenshipCard;

  static DocumentType? _parseDocumentType(String? value) {
    if (value == null) return null;
    for (final type in DocumentType.values) {
      if (type.name == value || type.code == value) return type;
    }
    return null;
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty || value != value.trim()) {
      throw FormatException('Campo remoto inválido: $key.');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty || value != value.trim()) {
      throw FormatException('Campo remoto inválido: $key.');
    }
    return value;
  }
}
