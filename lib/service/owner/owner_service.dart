import 'package:machuco/database/repository/owner/owner_repository.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';

final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

/// Datos demo que se siembran la primera vez que se abre el módulo.
///
/// Se quedan en la base local mientras no exista backend; no se pierden al
/// reiniciar la aplicación porque viven en SQLite.
List<Owner> buildSeedOwners() => const [
  Owner(
    id: 'owner-1020304050',
    fullName: 'Laura Gómez Restrepo',
    documentType: DocumentType.citizenshipCard,
    documentNumber: '1020304050',
    email: 'laura.gomez@machuco.com',
    phone: '+57 300 123 4567',
    address: 'Calle 10 # 43-25, Medellín',
  ),
  Owner(
    id: 'owner-900123456',
    fullName: 'Inversiones Machuco S.A.S.',
    documentType: DocumentType.taxId,
    documentNumber: '900123456-7',
    email: 'contacto@inversionesmachuco.com',
    phone: '+57 604 444 5566',
    address: 'Carrera 50 # 12-80, Rionegro',
  ),
  Owner(
    id: 'owner-345678',
    fullName: 'Simón Restrepo Vélez',
    documentType: DocumentType.foreignerCard,
    documentNumber: '345678',
    email: 'simon.restrepo@machuco.com',
    phone: '+57 311 987 6543',
    isActive: false,
  ),
];

/// Capa de servicio que concentra la lógica de negocio del módulo de
/// propietarios.
///
/// Orquesta el repositorio local (SQLite vía Floor): valida antes de
/// persistir, evita documentos duplicados y siembra los datos demo la
/// primera vez. El controlador llama a esta capa y presenta el resultado.
class OwnerService {
  OwnerService({OwnerRepository? repository})
    : _repository = repository ?? OwnerRepository();

  final OwnerRepository _repository;

  /// Carga los propietarios guardados.
  ///
  /// La siembra inicial vive en [sembrarDatosDemo] para que una lectura (por
  /// ejemplo tras eliminar al último propietario) no reponga datos borrados.
  Future<List<Owner>> cargarPropietarios() => _repository.findAll();

  /// Siembra los datos demo solo la primera vez, cuando la tabla está vacía.
  Future<void> sembrarDatosDemo() => _repository.seedIfEmpty(buildSeedOwners());

  /// Devuelve un mensaje si ya existe un propietario con ese documento.
  Future<String?> validarDuplicado(DocumentType tipo, String numero) async {
    final existe = await _repository.existsByDocument(tipo, numero);
    if (existe) {
      return 'Ya existe un propietario con ${tipo.shortLabel} $numero.';
    }
    return null;
  }

  /// Registra un propietario validando correo y duplicados.
  Future<Owner> crearPropietario({
    required String fullName,
    required DocumentType documentType,
    required String documentNumber,
    required String email,
    required String phone,
    String? address,
    bool isActive = true,
  }) async {
    if (email.isEmpty) {
      throw StateError('Ingresa el correo electrónico.');
    }
    if (!_emailPattern.hasMatch(email)) {
      throw StateError(
        'Ingresa un correo válido, por ejemplo nombre@dominio.com.',
      );
    }

    final dupMsg = await validarDuplicado(documentType, documentNumber);
    if (dupMsg != null) {
      throw StateError(dupMsg);
    }

    final owner = Owner(
      // Identificador provisional: el definitivo lo asignará el backend.
      id: 'owner-${DateTime.now().microsecondsSinceEpoch}',
      fullName: fullName,
      documentType: documentType,
      documentNumber: documentNumber,
      email: email,
      phone: phone,
      address: address,
      isActive: isActive,
    );

    await _repository.insert(owner);
    return owner;
  }

  /// Actualiza el teléfono de un propietario existente.
  Future<Owner> actualizarTelefono(String ownerId, String nuevoTelefono) async {
    final owner = await _repository.findById(ownerId);
    if (owner == null) {
      throw StateError('El propietario ya no existe.');
    }
    final updated = owner.copyWith(phone: nuevoTelefono);
    await _repository.update(updated);
    return updated;
  }

  /// Activa o inactiva a un propietario.
  Future<Owner> cambiarEstado(String ownerId, {required bool isActive}) async {
    final owner = await _repository.findById(ownerId);
    if (owner == null) {
      throw StateError('El propietario ya no existe.');
    }
    final updated = owner.copyWith(isActive: isActive);
    await _repository.update(updated);
    return updated;
  }

  /// Elimina un propietario de forma permanente.
  Future<void> eliminarPropietario(String ownerId) async {
    await _repository.deleteById(ownerId);
  }
}
