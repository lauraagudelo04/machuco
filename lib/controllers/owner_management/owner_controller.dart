import 'package:flutter/foundation.dart';

import 'package:machuco/database/repository/owner/owner_repository.dart';
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
/// Mantiene el estado que consumen las vistas y delega todas las reglas de
/// negocio en [OwnerService]; la persistencia vive en el repositorio (SQLite
/// vía Floor). Cada operación de escritura recarga el listado desde la base
/// para que la interfaz refleje exactamente lo que quedó guardado.
class OwnerController extends ChangeNotifier {
  OwnerController({OwnerService? service})
    : _service = service ?? OwnerService();

  /// Instancia compartida por las pantallas del módulo (listado, formulario y
  /// moteles del propietario) para que todas vean el mismo estado.
  static final OwnerController instance = OwnerController();

  final OwnerService _service;

  final List<Owner> _owners = [];
  String _searchQuery = '';
  OwnerStatusFilter _statusFilter = OwnerStatusFilter.all;
  bool _isLoading = false;
  String? _lastError;
  Future<void>? _load;
  bool _seededOnce = false;

  /// Propietarios cargados desde la base. Solo lectura: para modificarlos se
  /// usan las acciones del controlador.
  List<Owner> get owners => List.unmodifiable(_owners);

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

  /// Indica si hay una operación en curso (carga o escritura).
  bool get isLoading => _isLoading;

  /// Último error de negocio, o `null` si la última operación salió bien.
  String? get lastError => _lastError;

  bool get hasOwners => _owners.isNotEmpty;

  /// Indica si queda algo por mostrar con los criterios actuales.
  ///
  /// Se distingue de [hasOwners] para separar el listado aún vacío de una
  /// búsqueda sin resultados: cada caso merece su propio mensaje.
  bool get hasVisibleOwners => visibleOwners.isNotEmpty;

  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty || _statusFilter != OwnerStatusFilter.all;

  /// Carga los propietarios guardados. La primera vez siembra los datos demo.
  ///
  /// Varias pantallas comparten esta instancia, así que si ya hay una carga en
  /// curso se reutiliza el mismo futuro en lugar de lanzar otra consulta.
  Future<void> init() =>
      _load ??= _loadOwners().whenComplete(() => _load = null);

  Future<void> _loadOwners() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      // La siembra es solo para la primera carga del proceso: si el usuario
      // elimina todos los propietarios, volver a la pantalla no los repone.
      if (!_seededOnce) {
        await _service.sembrarDatosDemo();
        _seededOnce = true;
      }
      await _reload();
    } catch (error) {
      _lastError = _messageFor(error);
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

  /// Registra un propietario y devuelve el resultado ya persistido.
  ///
  /// Devuelve `null` si la validación de negocio falla; el motivo queda en
  /// [lastError].
  Future<Owner?> createOwner({
    required String fullName,
    required DocumentType documentType,
    required String documentNumber,
    required String email,
    required String phone,
    String? address,
    bool isActive = true,
  }) => _runAction(
    () => _service.crearPropietario(
      fullName: fullName,
      documentType: documentType,
      documentNumber: documentNumber,
      email: email,
      phone: phone,
      address: address,
      isActive: isActive,
    ),
  );

  /// Actualiza el teléfono de un propietario existente y devuelve cómo quedó.
  Future<Owner?> updateOwnerPhone(String ownerId, String phone) =>
      _runAction(() => _service.actualizarTelefono(ownerId, phone));

  /// Activa o inactiva a un propietario y devuelve cómo quedó.
  ///
  /// Un propietario inactivo no administra sus moteles ni recibe reservas.
  Future<Owner?> setActiveState(String ownerId, {required bool isActive}) =>
      _runAction(() => _service.cambiarEstado(ownerId, isActive: isActive));

  /// Elimina un propietario de forma permanente y devuelve el que se quitó.
  ///
  /// A diferencia de [setActiveState], la operación no se puede deshacer.
  Future<Owner?> deleteOwner(String ownerId) async {
    final owner = _findOwner(ownerId);
    if (owner == null) {
      _lastError = 'El propietario ya no existe.';
      notifyListeners();
      return null;
    }
    return _runAction(() async {
      await _service.eliminarPropietario(ownerId);
      return owner;
    });
  }

  bool _matchesQuery(Owner owner, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    return _normalize(owner.fullName).contains(normalizedQuery) ||
        _normalize(owner.documentNumber).contains(normalizedQuery) ||
        _normalize(owner.email).contains(normalizedQuery);
  }

  Future<void> _reload() async {
    final loaded = await _service.cargarPropietarios();
    _owners
      ..clear()
      ..addAll(loaded);
  }

  /// Ejecuta una escritura, recarga el listado y centraliza el manejo de
  /// errores: las vistas solo leen [lastError] para informar al usuario.
  Future<T?> _runAction<T>(Future<T> Function() action) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final result = await action();
      await _reload();
      return result;
    } catch (error) {
      _lastError = _messageFor(error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Owner? _findOwner(String id) {
    for (final owner in _owners) {
      if (owner.id == id) return owner;
    }
    return null;
  }

  String _messageFor(Object error) {
    if (error is StateError) return error.message;
    if (error is OwnerRepositoryException) return error.message;
    return 'No se pudo completar la operación. Intenta de nuevo.';
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
