import 'package:machuco/database/repository/owner/owner_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
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
    countryCode: '+57',
    countryName: 'Colombia',
    phone: '300 123 4567',
    address: 'Calle 10 # 43-25, Medellín',
  ),
  Owner(
    id: 'owner-900123456',
    fullName: 'Inversiones Machuco S.A.S.',
    documentType: DocumentType.taxId,
    documentNumber: '900123456-7',
    email: 'contacto@inversionesmachuco.com',
    countryCode: '+57',
    countryName: 'Colombia',
    phone: '604 444 5566',
    address: 'Carrera 50 # 12-80, Rionegro',
  ),
  Owner(
    id: 'owner-345678',
    fullName: 'Simón Restrepo Vélez',
    documentType: DocumentType.foreignerCard,
    documentNumber: '345678',
    email: 'simon.restrepo@machuco.com',
    countryCode: '+57',
    countryName: 'Colombia',
    phone: '311 987 6543',
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

  /// Propietarios que todavía no se enviaron a Firestore.
  Future<List<Owner>> propietariosSinSincronizar() =>
      _repository.findUnsynchronized();

  /// Propietarios eliminados en este dispositivo que faltan por borrar en
  /// Firestore.
  Future<List<Owner>> propietariosPendientesDeEliminar() =>
      _repository.findPendingDeletes();

  /// Confirma que la nube ya recibió al propietario.
  Future<void> marcarSincronizado(String ownerId) =>
      _repository.markSynchronized(ownerId);

  /// Deja el borrado pendiente sin perder la fila (para reintentarlo después).
  Future<void> marcarPendienteDeEliminar(String ownerId) =>
      _repository.markPendingDelete(ownerId);

  /// Incorpora a SQLite los propietarios que existen en la nube.
  Future<void> incorporarRemotos(List<Owner> owners) =>
      _repository.mergeRemoteOwners(owners);

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

  /// Registra un propietario en SQLite que ya existe en `users/{uid}`.
  Future<void> guardarCreado(Owner owner) =>
      _repository.insertSynchronized(owner);

  /// Construye y valida un propietario nuevo sin persistirlo.
  ///
  /// La creación real la completa el controlador: primero crea la cuenta en
  /// Firebase Auth y después guarda la fila local ya con el uid definitivo.
  Owner prepararPropietario({
    required String fullName,
    required DocumentType documentType,
    required String documentNumber,
    required String email,
    required String phone,
    String? countryCode,
    String? countryName,
    String? address,
    bool isActive = true,
    AccountStatus? accountStatus,
  }) {
    if (email.isEmpty) {
      throw StateError('Ingresa el correo electrónico.');
    }
    if (!_emailPattern.hasMatch(email)) {
      throw StateError(
        'Ingresa un correo válido, por ejemplo nombre@dominio.com.',
      );
    }

    return Owner(
      // Provisional hasta que Firebase Auth asigne el uid.
      id: 'owner-${DateTime.now().microsecondsSinceEpoch}',
      fullName: fullName,
      documentType: documentType,
      documentNumber: documentNumber,
      email: email,
      phone: phone,
      countryCode: countryCode,
      countryName: countryName,
      address: address,
      isActive: isActive,
      accountStatus: accountStatus,
    );
  }

  /// Registra un propietario validando correo y duplicados.
  ///
  /// [countryCode] y [countryName] viajan aparte de [phone] para que la nube y
  /// los filtros trabajen con el indicativo sin partir un texto concatenado.
  Future<Owner> crearPropietario({
    required String fullName,
    required DocumentType documentType,
    required String documentNumber,
    required String email,
    required String phone,
    String? countryCode,
    String? countryName,
    String? address,
    bool isActive = true,
  }) async {
    final dupMsg = await validarDuplicado(documentType, documentNumber);
    if (dupMsg != null) {
      throw StateError(dupMsg);
    }

    final owner = prepararPropietario(
      fullName: fullName,
      documentType: documentType,
      documentNumber: documentNumber,
      email: email,
      phone: phone,
      countryCode: countryCode,
      countryName: countryName,
      address: address,
      isActive: isActive,
      accountStatus: isActive ? AccountStatus.active : AccountStatus.disabled,
    );

    await _repository.insert(owner);
    return owner;
  }

  /// Actualiza los datos editables de un propietario.
  Future<Owner> actualizarPropietario({
    required String ownerId,
    required String fullName,
    required DocumentType documentType,
    required String documentNumber,
    required String phone,
    String? countryCode,
    String? countryName,
    String? address,
    bool? isActive,
    AccountStatus? accountStatus,
  }) async {
    final owner = await _repository.findById(ownerId);
    if (owner == null) {
      throw StateError('El propietario ya no existe.');
    }
    final updated = Owner(
      id: owner.id,
      fullName: fullName,
      documentType: documentType,
      documentNumber: documentNumber,
      email: owner.email,
      phone: phone,
      countryCode: countryCode,
      countryName: countryName,
      address: address,
      isActive: isActive ?? owner.isActive,
      accountStatus: accountStatus ?? owner.accountStatus,
      isSynchronized: owner.isSynchronized,
    );
    await _repository.update(updated);
    return updated;
  }

  /// Actualiza el teléfono de un propietario existente.
  ///
  /// Si se entrega [countryCode], se actualiza también el indicativo y el
  /// nombre del país; si se omite, se conserva el que ya estaba guardado.
  Future<Owner> actualizarTelefono(
    String ownerId,
    String nuevoTelefono, {
    String? countryCode,
    String? countryName,
  }) async {
    final owner = await _repository.findById(ownerId);
    if (owner == null) {
      throw StateError('El propietario ya no existe.');
    }
    final updated = owner.copyWith(
      phone: nuevoTelefono,
      countryCode: countryCode,
      countryName: countryName,
    );
    await _repository.update(updated);
    return updated;
  }

  /// Activa o inactiva a un propietario.
  Future<Owner> cambiarEstado(String ownerId, {required bool isActive}) async {
    final owner = await _repository.findById(ownerId);
    if (owner == null) {
      throw StateError('El propietario ya no existe.');
    }
    final updated = owner.copyWith(
      isActive: isActive,
      accountStatus: isActive ? AccountStatus.active : AccountStatus.disabled,
    );
    await _repository.update(updated);
    return updated;
  }

  /// Elimina un propietario de forma permanente.
  Future<void> eliminarPropietario(String ownerId) async {
    await _repository.deleteById(ownerId);
  }
}
