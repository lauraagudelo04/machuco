import 'package:flutter/foundation.dart';

import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';

const _minimumFullNameLength = 3;

final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
final _phonePattern = RegExp(r'^\+?\d{7,15}$');
final _phoneSeparatorsPattern = RegExp(r'[\s\-()]');

/// Coordina la gestión de propietarios de moteles.
///
/// Concentra el estado del módulo y las reglas de validación del registro,
/// para que las vistas solo presenten información y deleguen las acciones.
///
/// Mientras no exista capa de datos, los propietarios viven en memoria y los
/// cambios se pierden al reiniciar la aplicación.
class OwnerController extends ChangeNotifier {
  final List<Owner> _owners = [
    const Owner(
      id: 'owner-1020304050',
      fullName: 'Laura Gómez Restrepo',
      documentType: DocumentType.citizenshipCard,
      documentNumber: '1020304050',
      email: 'laura.gomez@machuco.com',
      phone: '+57 300 123 4567',
      address: 'Calle 10 # 43-25, Medellín',
    ),
    const Owner(
      id: 'owner-900123456',
      fullName: 'Inversiones Machuco S.A.S.',
      documentType: DocumentType.taxId,
      documentNumber: '900123456-7',
      email: 'contacto@inversionesmachuco.com',
      phone: '+57 604 444 5566',
      address: 'Carrera 50 # 12-80, Rionegro',
    ),
    const Owner(
      id: 'owner-345678',
      fullName: 'Simón Restrepo Vélez',
      documentType: DocumentType.foreignerCard,
      documentNumber: '345678',
      email: 'simon.restrepo@machuco.com',
      phone: '+57 311 987 6543',
      isActive: false,
    ),
  ];

  /// Propietarios registrados. La lista es de solo lectura: para modificarla
  /// se usan las acciones del controlador.
  List<Owner> get owners => List.unmodifiable(_owners);

  bool get hasOwners => _owners.isNotEmpty;

  /// Registra un propietario y devuelve el resultado ya identificado.
  Owner createOwner({
    required String fullName,
    required DocumentType documentType,
    required String documentNumber,
    required String email,
    required String phone,
    String? address,
    bool isActive = true,
  }) {
    final owner = Owner(
      id: _generateOwnerId(),
      fullName: fullName,
      documentType: documentType,
      documentNumber: documentNumber,
      email: email,
      phone: phone,
      address: address,
      isActive: isActive,
    );
    _owners.add(owner);
    notifyListeners();
    return owner;
  }

  /// Actualiza el teléfono de un propietario y devuelve cómo quedó.
  ///
  /// Es el único dato editable después del registro: los demás identifican
  /// legalmente al propietario. Devuelve `null` si el propietario ya no existe.
  Owner? updateOwnerPhone(String ownerId, String phone) {
    return _replaceOwner(ownerId, (owner) => owner.copyWith(phone: phone));
  }

  /// Activa o inactiva a un propietario y devuelve cómo quedó.
  ///
  /// Un propietario inactivo no administra sus moteles ni recibe reservas.
  /// Devuelve `null` si el propietario ya no existe.
  Owner? setActiveState(String ownerId, {required bool isActive}) {
    return _replaceOwner(
      ownerId,
      (owner) => owner.copyWith(isActive: isActive),
    );
  }

  Owner? _replaceOwner(String ownerId, Owner Function(Owner owner) update) {
    final index = _owners.indexWhere((owner) => owner.id == ownerId);
    if (index == -1) return null;
    final updatedOwner = update(_owners[index]);
    _owners[index] = updatedOwner;
    notifyListeners();
    return updatedOwner;
  }

  /// Identificador provisional. El definitivo lo asignará el backend.
  String _generateOwnerId() => 'owner-${DateTime.now().microsecondsSinceEpoch}';

  static String? validateFullName(String value) {
    final fullName = value.trim();
    if (fullName.isEmpty) return 'Ingresa el nombre completo.';
    if (fullName.length < _minimumFullNameLength) {
      return 'El nombre debe tener al menos $_minimumFullNameLength caracteres.';
    }
    return null;
  }

  static String? validateDocumentNumber(
    String value,
    DocumentType documentType,
  ) {
    final documentNumber = value.trim();
    if (documentNumber.isEmpty) return 'Ingresa el número de documento.';
    if (!documentType.acceptsDocumentNumber(documentNumber)) {
      return 'Número no válido para ${documentType.shortLabel}. '
          'Ejemplo: ${documentType.example}.';
    }
    return null;
  }

  static String? validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Ingresa el correo electrónico.';
    if (!_emailPattern.hasMatch(email)) {
      return 'Ingresa un correo válido, por ejemplo nombre@dominio.com.';
    }
    return null;
  }

  static String? validatePhone(String value) {
    if (value.trim().isEmpty) return 'Ingresa el teléfono.';
    final phone = value.replaceAll(_phoneSeparatorsPattern, '');
    if (!_phonePattern.hasMatch(phone)) {
      return 'Ingresa un teléfono válido, por ejemplo +57 300 123 4567.';
    }
    return null;
  }
}
