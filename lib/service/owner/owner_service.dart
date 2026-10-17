import 'package:sqflite/sqflite.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/service/persistence/sqlite/owner_dao.dart';

/// Capa de servicio que concentra la lógica de negocio del módulo de propietarios.
///
/// Decide el destino de los datos (SQLite local o nube), gestiona validaciones
/// de duplicados y orquesta la persistencia. El controlador llama a esta capa
/// y presenta el estado resultante; las vistas sólo muestran información.
class OwnerService {
  final OwnerDao _dao = OwnerDao.instance;

  /// Verifica si ya existe un propietario con el mismo documento.
  Future<String?> validarDuplicado(DocumentType tipo, String numero) async {
    final existe = await _dao.existsByDocument(tipo, numero);
    if (existe) {
      return 'Ya existe un propietario con ${tipo.shortLabel} $numero.';
    }
    return null;
  }

  /// Crea un nuevo propietario y lo persiste en SQLite.
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
    final emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
    if (!emailPattern.hasMatch(email)) {
      throw StateError('Ingresa un correo válido, por ejemplo nombre@dominio.com.');
    }

    final dupMsg = await validarDuplicado(documentType, documentNumber);
    if (dupMsg != null) {
      throw StateError(dupMsg);
    }

    final owner = Owner(
      id: '_owner-${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      documentType: documentType,
      documentNumber: documentNumber,
      email: email,
      phone: phone,
      address: address,
      isActive: isActive,
    );

    await _dao.insert(owner);
    return owner;
  }

  /// Actualiza el teléfono de un propietario existente.
  Future<void> actualizarTelefono(String ownerId, String nuevoTelefono) async {
    final phonePattern = RegExp(r'^\+\d{1,3}\s?\d{7,15}$');
    if (!phonePattern.hasMatch(nuevoTelefono)) {
      throw StateError('Formato de teléfono no válido. Ejemplo: +57 300 123 4567.');
    }

    await _dao.update(Owner(
      id: ownerId,
      fullName: '',
      documentType: DocumentType.citizenshipCard,
      documentNumber: '',
      email: '',
      phone: nuevoTelefono,
      address: '',
      isActive: true,
    ));
  }

  /// Marca un propietario como sincronizado (para futura capa Supabase).
  Future<void> marcarSincronizado(String ownerId) async {
    await _dao.markSynchronized(ownerId);
  }
}