import 'package:machuco/database/repository/owner/owner_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';

final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

/// Capa de servicio que concentra la lógica de negocio del módulo de
/// propietarios.
///
/// Orquesta el repositorio local (SQLite vía Floor): valida antes de
/// persistir y evita documentos duplicados. El controlador llama a esta capa
/// y presenta el resultado. Ya no siembra datos demo: el listado refleja
/// únicamente los usuarios con `role = owner` de Firestore.
class OwnerService {
  OwnerService({OwnerRepository? repository})
    : _repository = repository ?? OwnerRepository();

  final OwnerRepository _repository;

  /// Carga los propietarios guardados en la caché local.
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
