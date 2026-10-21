import 'package:flutter/foundation.dart';

import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/models/owner_management/owner_status_filter.dart';
import 'package:machuco/service/owner/owner_service.dart';

const _minimumFullNameLength = 3;

final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
final _phonePattern = RegExp(r'^\+?\d{7,15}$');
final _phoneSeparatorsPattern = RegExp(r'[\s\-()]');

// Se comparan las cadenas sin tildes para que "gomez" encuentre a "Gómez".
const _accentedCharacters = 'áàäâãéèëêíìïîóòöôõúùüûñç';
const _plainCharacters = 'aaaaaeeeeiiiiooooouuuunc';

String _normalize(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final character = String.fromCharCode(rune);
    final index = _accentedCharacters.indexOf(character);
    buffer.write(index == -1 ? character : _plainCharacters[index]);
  }
  return buffer.toString();
}

/// Coordina la gestión de propietarios de moteles.
///
/// Concentra el estado del módulo y delega la persistencia en [OwnerService],
/// que a su vez usa el repositorio local (SQLite vía Floor). Las vistas sólo
/// presentan la información y le delegan las acciones.
///
/// Usa [instance] para que todas las pantallas compartan el mismo estado;
/// en tests se puede crear una instancia aislada inyectando un [OwnerService]
/// con su propio repositorio.
class OwnerController extends ChangeNotifier {
  OwnerController({OwnerService? service}) : _service = service ?? OwnerService();

  /// Instancia única compartida por las pantallas del módulo.
  static final OwnerController instance = OwnerController();

  final OwnerService _service;

  final List<Owner> _owners = [];

  String _searchQuery = '';
  OwnerStatusFilter _statusFilter = OwnerStatusFilter.all;
  bool _isLoading = false;
  String? _lastError;

  /// Propietarios registrados. La lista es de solo lectura: para modificarla
  /// se usan las acciones del controlador.
  List<Owner> get owners => List.unmodifiable(_owners);

  /// Indica que una operación de persistencia está en curso.
  bool get isLoading => _isLoading;

  /// Mensaje del último error de persistencia, si lo hubo.
  String? get lastError => _lastError;

  /// Propietarios que sobreviven a la búsqueda y al filtro por estado.
  ///
  /// Es lo que debe pintar el listado; [owners] sigue siendo el total.
  List<Owner> get visibleOwners {
    final query = _normalize(_searchQuery.trim());
    return List.unmodifiable(
      _owners.where(
        (owner) => _statusFilter.matches(owner) && _matchesQuery(owner, query),
      ),
    );
  }

  String get searchQuery => _searchQuery;

  OwnerStatusFilter get statusFilter => _statusFilter;

  bool get hasOwners => _owners.isNotEmpty;

  /// Indica si queda algo por mostrar con los criterios actuales.
  ///
  /// Se distingue de [hasOwners] para separar el listado aún vacío de una
  /// búsqueda sin resultados: cada caso merece su propio mensaje.
  bool get hasVisibleOwners => visibleOwners.isNotEmpty;

  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty || _statusFilter != OwnerStatusFilter.all;

  /// Carga los propietarios desde la base local.
  ///
  /// La primera vez siembra los datos demo; las siguientes sólo lee lo
  /// guardado. Es seguro llamarla varias veces: recarga el listado.
  Future<void> init() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final loaded = await _service.cargarPropietarios();
      _owners
        ..clear()
        ..addAll(loaded);
    } catch (_) {
      _lastError = 'No se pudieron cargar los propietarios.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filtra el listado por nombre, número de documento o correo.
  void search(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void filterByStatus(OwnerStatusFilter filter) {
    if (_statusFilter == filter) return;
    _statusFilter = filter;
    notifyListeners();
  }

  /// Devuelve el listado a su estado completo.
  void clearFilters() {
    if (!hasActiveFilters) return;
    _searchQuery = '';
    _statusFilter = OwnerStatusFilter.all;
    notifyListeners();
  }

  bool _matchesQuery(Owner owner, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    return _normalize(owner.fullName).contains(normalizedQuery) ||
        _normalize(owner.documentNumber).contains(normalizedQuery) ||
        _normalize(owner.email).contains(normalizedQuery);
  }

  /// Registra un propietario en la base local y devuelve el resultado.
  ///
  /// Devuelve `null` si la persistencia falla; el mensaje queda en [lastError].
  Future<Owner?> createOwner({
    required String fullName,
    required DocumentType documentType,
    required String documentNumber,
    required String email,
    required String phone,
    String? address,
    bool isActive = true,
  }) async {
    return _runAction(() async {
      final created = await _service.crearPropietario(
        fullName: fullName,
        documentType: documentType,
        documentNumber: documentNumber,
        email: email,
        phone: phone,
        address: address,
        isActive: isActive,
      );
      _owners.add(created);
      return created;
    });
  }

  /// Actualiza el teléfono de un propietario y devuelve cómo quedó.
  ///
  /// Es el único dato editable después del registro: los demás identifican
  /// legalmente al propietario. Devuelve `null` si falla la persistencia.
  Future<Owner?> updateOwnerPhone(String ownerId, String phone) async {
    return _runAction(() async {
      final updated = await _service.actualizarTelefono(ownerId, phone);
      _replaceOwnerInMemory(ownerId, (_) => updated);
      return updated;
    });
  }

  /// Activa o inactiva a un propietario y devuelve cómo quedó.
  ///
  /// Un propietario inactivo no administra sus moteles ni recibe reservas.
  /// Devuelve `null` si falla la persistencia.
  Future<Owner?> setActiveState(
    String ownerId, {
    required bool isActive,
  }) async {
    return _runAction(() async {
      final updated = await _service.cambiarEstado(
        ownerId,
        isActive: isActive,
      );
      _replaceOwnerInMemory(ownerId, (_) => updated);
      return updated;
    });
  }

  /// Elimina un propietario de forma permanente y devuelve el que se quitó.
  ///
  /// A diferencia de [setActiveState], la operación no se puede deshacer.
  /// Devuelve `null` si falla la persistencia.
  Future<Owner?> deleteOwner(String ownerId) async {
    // Tipo explícito: sin él Dart inferiría T = Owner y el `return null` del
    // closure (propietario ya inexistente) no sería admitido.
    return _runAction<Owner?>(() async {
      final index = _owners.indexWhere((owner) => owner.id == ownerId);
      if (index == -1) return null;
      await _service.eliminarPropietario(ownerId);
      return _owners.removeAt(index);
    });
  }

  /// Ejecuta una acción persistente marcando el estado de carga y exponiendo
  /// cualquier error en [lastError] sin dejar excepciones escapar a la UI.
  Future<T?> _runAction<T>(Future<T> Function() action) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final result = await action();
      return result;
    } catch (error) {
      _lastError = error is StateError
          ? error.message.toString()
          : 'No se pudo completar la operación.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _replaceOwnerInMemory(String ownerId, Owner Function(Owner owner) update) {
    final index = _owners.indexWhere((owner) => owner.id == ownerId);
    if (index == -1) return;
    _owners[index] = update(_owners[index]);
  }

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
