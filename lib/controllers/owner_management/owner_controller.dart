import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:machuco/database/repository/auth/auth_catalog_repository.dart';
import 'package:machuco/database/repository/document_type/document_type_repository.dart';
import 'package:machuco/database/repository/owner/owner_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/models/owner_management/owner_status_filter.dart';
import 'package:machuco/repositories/owner/owner_cloud_repository.dart';
import 'package:machuco/service/firebase/current_user.dart';
import 'package:machuco/service/owner/owner_preferences.dart';
import 'package:machuco/service/owner/owner_service.dart';
import 'package:machuco/service/owner/owner_sync_scheduler.dart';

const _minimumFullNameLength = 3;

final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
final _phonePattern = RegExp(r'^\+?\d{7,15}$');

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
  OwnerController({
    OwnerService? service,
    this._catalogRepository,
    DocumentTypeRepository? documentTypeRepository,
    this._preferences,
    OwnerCloudRepository? cloudRepository,
    String? Function()? currentUserId,
    OwnerSyncRetryScheduler? syncRetryScheduler,
  }) : _service = service ?? OwnerService(),
       _documentTypeRepository =
           documentTypeRepository ?? DocumentTypeRepository(),
       _cloudRepository =
           cloudRepository ??
           (service == null ? FirestoreOwnerCloudRepository() : null),
       _currentUserId = currentUserId ?? (() => CurrentUser.uid) {
    _syncRetry =
        syncRetryScheduler ??
        OwnerSyncRetryScheduler(
          attempt: _synchronizeWithCloud,
          onStateChanged: _notifySyncRetryChanged,
        );
  }

  /// Instancia compartida por las pantallas del módulo (listado, formulario y
  /// moteles del propietario) para que todas vean el mismo estado.
  static final OwnerController instance = OwnerController(
    catalogRepository: AuthCatalogRepository.fromEnvironment(),
    preferences: OwnerPreferences(),
  );

  final OwnerService _service;

  /// Nube de propietarios. Es `null` cuando se inyecta un servicio local en
  /// los tests, igual que en pagos, para no salir a la red sin querer.
  final OwnerCloudRepository? _cloudRepository;

  final String? Function() _currentUserId;

  /// Preferencias locales del módulo. Es opcional para que los tests de
  /// persistencia no dependan de `shared_preferences`.
  final OwnerPreferences? _preferences;

  /// Maestro de indicativos. Si es `null` se usa la semilla de desarrollo
  /// (Colombia) para que el formulario funcione sin Supabase ni caché.
  final AuthCatalogRepository? _catalogRepository;

  final DocumentTypeRepository _documentTypeRepository;

  final List<Owner> _owners = [];
  String _searchQuery = '';
  OwnerStatusFilter _statusFilter = OwnerStatusFilter.all;
  bool _isLoading = false;
  String? _lastError;
  Future<void>? _load;
  bool _seededOnce = false;
  bool _isSyncing = false;
  bool _disposed = false;
  String? _syncWarningMessage;
  late final OwnerSyncRetryScheduler _syncRetry;
  bool _lastDeletionIsPending = false;
  Future<void>? _backgroundSync;

  List<CountryPhoneCode> _countryPhoneCodes = const [];
  CountryPhoneCode? _selectedCountryCode;
  bool _isLoadingCountryCodes = false;
  String? _countryCodesError;

  List<DocumentType> _documentTypes = DocumentType.values;
  bool _isLoadingDocumentTypes = false;
  String? _documentTypesError;

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

  /// Indica si hay una sincronización con Firestore en curso.
  bool get isSyncing => _isSyncing;

  /// Aviso no bloqueante cuando la nube falló pero los datos locales siguen
  /// disponibles. La pantalla lo muestra como banner, sin tapar el listado.
  String? get syncWarningMessage => _syncWarningMessage;

  /// `true` mientras hay un reintento automático programado.
  bool get isAutoRetrying => _syncRetry.isScheduled;

  /// Número del intento automático en curso (1..8).
  int get autoRetryAttempt => _syncRetry.attempt;

  /// Total de intentos automáticos antes de rendirse.
  int get autoRetryMaxAttempts => _syncRetry.maxAttempts;

  /// `true` si la última eliminación quedó pendiente de borrar en Firestore.
  bool get lastDeletionIsPending => _lastDeletionIsPending;

  /// Completa cuando termina el envío en segundo plano de la última escritura.
  ///
  /// La interfaz no lo espera (el guardado local ya terminó), pero los tests
  /// lo usan para verificar el resultado sin depender de tiempos.
  Future<void> get pendingSync => _backgroundSync ?? Future<void>.value();

  bool get hasOwners => _owners.isNotEmpty;

  /// Indica si queda algo por mostrar con los criterios actuales.
  ///
  /// Se distingue de [hasOwners] para separar el listado aún vacío de una
  /// búsqueda sin resultados: cada caso merece su propio mensaje.
  bool get hasVisibleOwners => visibleOwners.isNotEmpty;

  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty || _statusFilter != OwnerStatusFilter.all;

  /// Indicativos disponibles para el selector del formulario.
  List<CountryPhoneCode> get countryCodes =>
      List.unmodifiable(_countryPhoneCodes);

  CountryPhoneCode? get selectedCountryCode => _selectedCountryCode;

  bool get isLoadingCountryCodes => _isLoadingCountryCodes;

  /// Error al traer el maestro de indicativos, o `null` si cargó bien.
  String? get countryCodesError => _countryCodesError;

  bool get hasCountryCodes => _countryPhoneCodes.isNotEmpty;

  /// Tipos de documento activos del maestro local.
  ///
  /// Arranca con los valores del enum para que el formulario nunca quede sin
  /// opciones si la tabla todavía no cargó.
  List<DocumentType> get documentTypes => List.unmodifiable(_documentTypes);

  bool get isLoadingDocumentTypes => _isLoadingDocumentTypes;

  String? get documentTypesError => _documentTypesError;

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
    // La nube nunca bloquea el listado local: si falla, queda el aviso.
    if (_lastError == null) await _synchronizeWithCloud();
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

  /// Carga el maestro de indicativos (caché SQLite primero, Supabase después).
  ///
  /// Sin repositorio inyectado usa la semilla de desarrollo, igual que el
  /// login, para que el formulario siga siendo usable sin conexión.
  Future<void> loadCountryCodes({bool forceRefresh = false}) async {
    if (_isLoadingCountryCodes) return;
    _isLoadingCountryCodes = true;
    _countryCodesError = null;
    notifyListeners();
    try {
      final repository = _catalogRepository;
      _countryPhoneCodes = repository == null
          ? const [developmentCountryPhoneCodeSeed]
          : await repository.getCountryPhoneCodes(forceRefresh: forceRefresh);
      _selectedCountryCode = countryCodeForDialCode(
        _selectedCountryCode?.dialCode,
      );
    } on AuthCatalogRepositoryException {
      _countryPhoneCodes = const [];
      _countryCodesError =
          'No pudimos cargar los indicativos. Revisa tu conexión.';
    } finally {
      _isLoadingCountryCodes = false;
      notifyListeners();
    }
  }

  /// Elige el indicativo que se usará al guardar el teléfono.
  void selectCountryCode(CountryPhoneCode code) {
    if (_selectedCountryCode?.id == code.id &&
        _selectedCountryCode?.dialCode == code.dialCode) {
      return;
    }
    _selectedCountryCode = code;
    notifyListeners();
  }

  /// Busca en el maestro el indicativo que corresponde a [dialCode].
  ///
  /// Si no lo encuentra (o el maestro está vacío) devuelve el predeterminado
  /// —Colombia cuando existe— para que el formulario siempre tenga uno.
  CountryPhoneCode? countryCodeForDialCode(String? dialCode) {
    if (dialCode != null && dialCode.trim().isNotEmpty) {
      for (final code in _countryPhoneCodes) {
        if (code.dialCode == dialCode) return code;
      }
    }
    for (final code in _countryPhoneCodes) {
      if (code.isoCode == 'CO') return code;
    }
    return _countryPhoneCodes.isEmpty ? null : _countryPhoneCodes.first;
  }

  /// Indicativo elegido la última vez en este dispositivo.
  ///
  /// Devuelve `null` si no hay preferencia guardada, si el maestro todavía no
  /// cargó o si el id guardado ya no existe en el catálogo. Cualquier fallo de
  /// `shared_preferences` se trata como ausencia de preferencia: la
  /// preselección es una comodidad, no un requisito para guardar.
  Future<CountryPhoneCode?> lastUsedCountryCode() async {
    final id = await _loadLastCountryCodeId();
    if (id == null) return null;
    for (final code in _countryPhoneCodes) {
      if (code.id == id) return code;
    }
    return null;
  }

  /// Recuerda el indicativo elegido para preseleccionarlo la próxima vez.
  Future<void> saveLastCountryCode(int id) async {
    try {
      await _preferences?.saveLastCountryCodeId(id);
    } catch (_) {
      // La preferencia es opcional: si falla, el formulario sigue funcionando.
    }
  }

  Future<int?> _loadLastCountryCodeId() async {
    try {
      return await _preferences?.loadLastCountryCodeId();
    } catch (_) {
      return null;
    }
  }

  /// Carga los tipos de documento activos.
  ///
  /// Con [forceRefresh] consulta Supabase y actualiza la caché local; sin él
  /// responde con la tabla `document_types` de SQLite. Si todo falla se
  /// conservan los valores del enum como respaldo.
  Future<void> loadDocumentTypes({bool forceRefresh = false}) async {
    if (_isLoadingDocumentTypes) return;
    _isLoadingDocumentTypes = true;
    _documentTypesError = null;
    notifyListeners();
    try {
      final loaded = await _documentTypeRepository.getActiveDocumentTypes(
        forceRefresh: forceRefresh,
      );
      if (loaded.isNotEmpty) _documentTypes = loaded;
    } on DocumentTypeRepositoryException {
      _documentTypesError =
          'No pudimos cargar los tipos de documento desde Supabase. '
          'Usamos los del sistema.';
    } catch (_) {
      _documentTypesError =
          'No pudimos cargar los tipos de documento. Usamos los del sistema.';
    } finally {
      _isLoadingDocumentTypes = false;
      notifyListeners();
    }
  }

  /// Crea la cuenta del propietario en `users/{uid}` y devuelve el resultado
  /// con su contraseña temporal.
  ///
  /// Crear un propietario implica crear una cuenta de Firebase Auth, así que
  /// necesita conexión: no se puede completar sin red. Devuelve `null` si la
  /// validación o la nube fallan; el motivo queda en [lastError].
  Future<CreatedOwner?> createOwner({
    required String fullName,
    required DocumentType documentType,
    required String documentNumber,
    required String email,
    required String phone,
    String? countryCode,
    String? countryName,
    String? address,
    bool pendingApproval = false,
  }) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final duplicate = await _service.validarDuplicado(
        documentType,
        documentNumber,
      );
      if (duplicate != null) throw StateError(duplicate);

      final cloud = _cloudRepository;
      final adminId = _currentUserId();
      if (cloud == null || adminId == null || adminId.trim().isEmpty) {
        throw StateError(
          'Inicia sesión con Firebase para crear la cuenta del propietario.',
        );
      }

      final status = pendingApproval
          ? AccountStatus.pendingApproval
          : AccountStatus.active;
      final draft = _service.prepararPropietario(
        fullName: fullName,
        documentType: documentType,
        documentNumber: documentNumber,
        email: email,
        phone: phone,
        countryCode: countryCode,
        countryName: countryName,
        address: address,
        isActive: !pendingApproval,
        accountStatus: status,
      );

      final created = await cloud.createOwner(
        adminId: adminId,
        owner: draft,
        accountStatus: status,
        phoneCountryCodeId: _selectedCountryCode?.id,
      );
      await _service.guardarCreado(created.owner);
      await _reload();
      return created;
    } on OwnerCloudRepositoryException catch (error) {
      _lastError = error.message;
      return null;
    } catch (error) {
      _lastError = _messageFor(error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza los datos editables de un propietario.
  Future<Owner?> updateOwner(
    String ownerId, {
    required String fullName,
    required DocumentType documentType,
    required String documentNumber,
    required String phone,
    String? countryCode,
    String? countryName,
    String? address,
  }) => _runAction(
    () => _service.actualizarPropietario(
      ownerId: ownerId,
      fullName: fullName,
      documentType: documentType,
      documentNumber: documentNumber,
      phone: phone,
      countryCode: countryCode,
      countryName: countryName,
      address: address,
    ),
  );

  /// Actualiza el teléfono de un propietario existente y devuelve cómo quedó.
  Future<Owner?> updateOwnerPhone(
    String ownerId,
    String phone, {
    String? countryCode,
    String? countryName,
  }) async {
    final owner = _findOwner(ownerId);
    if (owner == null) {
      _lastError = 'El propietario ya no existe.';
      notifyListeners();
      return null;
    }
    return updateOwner(
      ownerId,
      fullName: owner.fullName,
      documentType: owner.documentType,
      documentNumber: owner.documentNumber,
      phone: phone,
      countryCode: countryCode ?? owner.countryCode,
      countryName: countryName ?? owner.countryName,
      address: owner.address,
    );
  }

  /// Activa o inactiva a un propietario y devuelve cómo quedó.
  ///
  /// Un propietario inactivo no administra sus moteles ni recibe reservas. Las
  /// cuentas pendientes de aprobación se resuelven desde el módulo de
  /// aprobación, no desde este interruptor.
  Future<Owner?> setActiveState(String ownerId, {required bool isActive}) {
    final owner = _findOwner(ownerId);
    if (owner != null && owner.isPendingApproval && isActive) {
      _lastError =
          'La cuenta está pendiente de aprobación. Apruébala desde el módulo '
          'de propietarios pendientes.';
      notifyListeners();
      return Future.value();
    }
    return _runAction(
      () => _service.cambiarEstado(ownerId, isActive: isActive),
    );
  }

  /// Elimina un propietario de forma permanente y devuelve el que se quitó.
  ///
  /// A diferencia de [setActiveState], la operación no se puede deshacer. Con
  /// conexión se borra primero el documento remoto; sin conexión la fila se
  /// oculta con `pendingDelete = 1` y la sincronización la borra en Firestore
  /// cuando vuelva la red. Así el próximo pull no la resucita y el usuario ve
  /// el listado consistente de inmediato.
  Future<Owner?> deleteOwner(String ownerId) async {
    final owner = _findOwner(ownerId);
    if (owner == null) {
      _lastError = 'El propietario ya no existe.';
      notifyListeners();
      return null;
    }

    _lastDeletionIsPending = false;
    final cloud = _cloudRepository;
    final adminId = _currentUserId();
    final hasSession =
        cloud != null && adminId != null && adminId.trim().isNotEmpty;

    if (!hasSession) {
      await _markPendingDeletion(
        owner,
        '${owner.fullName} se eliminó en este dispositivo. Inicia sesión para '
        'borrarlo de Firebase.',
        scheduleRetry: false,
      );
      return owner;
    }

    try {
      await cloud.deleteOwner(ownerId);
    } on OwnerCloudRepositoryException catch (error) {
      if (error.type == OwnerCloudFailureType.network) {
        await _markPendingDeletion(
          owner,
          '${error.message} Se borrará de Firebase cuando vuelva la conexión.',
        );
        return owner;
      }
      _lastError = '${error.message} No se eliminó en este dispositivo.';
      notifyListeners();
      return null;
    } catch (_) {
      _lastError =
          'No se pudo eliminar el propietario de la nube. Intenta de nuevo.';
      notifyListeners();
      return null;
    }

    return _runAction(() async {
      await _service.eliminarPropietario(ownerId);
      return owner;
    }, sync: false);
  }

  /// Oculta el propietario y deja su borrado pendiente de Firestore.
  Future<void> _markPendingDeletion(
    Owner owner,
    String message, {
    bool scheduleRetry = true,
  }) async {
    try {
      await _service.marcarPendienteDeEliminar(owner.id);
      await _reload();
      _lastDeletionIsPending = true;
      _syncWarningMessage = message;
      if (scheduleRetry) _syncRetry.notifyNetworkFailure();
    } catch (error) {
      _lastError = _messageFor(error);
    }
    notifyListeners();
  }

  /// Fuerza un intento de sincronización (banner y vuelta del segundo plano).
  Future<void> retrySynchronization() {
    _syncRetry.cancel();
    return _synchronizeWithCloud();
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
  ///
  /// Tras una escritura exitosa, [sync] lanza el envío a Firestore en segundo
  /// plano para que la interfaz no espere a la red.
  Future<T?> _runAction<T>(
    Future<T> Function() action, {
    bool sync = true,
  }) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final result = await action();
      await _reload();
      if (sync && result != null) {
        final pending = _synchronizePending();
        _backgroundSync = pending;
        unawaited(pending);
      }
      return result;
    } catch (error) {
      _lastError = _messageFor(error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sube los pendientes y luego trae lo que otros administradores hayan
  /// guardado. La base local manda mientras haya cambios sin sincronizar.
  Future<void> _synchronizeWithCloud() async {
    final cloud = _cloudRepository;
    if (cloud == null || _disposed || _isSyncing) return;
    final adminId = _currentUserId();
    if (adminId == null || adminId.trim().isEmpty) {
      _syncRetry.cancel();
      _syncWarningMessage =
          'Inicia sesión con Firebase para sincronizar los propietarios.';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _syncWarningMessage = null;
    notifyListeners();
    try {
      await _pushPending(cloud, adminId);
      final remote = await cloud.listOwners();
      await _service.incorporarRemotos(remote);
      await _reload();
      _syncRetry.notifySuccess();
    } on OwnerCloudRepositoryException catch (error) {
      _syncWarningMessage = error.message;
      if (error.type == OwnerCloudFailureType.network) {
        _syncRetry.notifyNetworkFailure();
      }
    } on OwnerRepositoryException catch (error) {
      _syncWarningMessage =
          'Los propietarios están en Firebase, pero no se pudieron '
          'actualizar en este dispositivo: ${error.message}';
    } catch (_) {
      _syncWarningMessage =
          'Los propietarios locales están disponibles, pero no se pudieron '
          'sincronizar con Firebase.';
      _syncRetry.notifyNetworkFailure();
    } finally {
      _isSyncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Envía solo los registros nuevos o modificados (`synchronized = 0`).
  Future<void> _synchronizePending() async {
    final cloud = _cloudRepository;
    if (cloud == null || _disposed || _isSyncing) return;
    final adminId = _currentUserId();
    if (adminId == null || adminId.trim().isEmpty) {
      _syncRetry.cancel();
      _syncWarningMessage =
          'El propietario quedó guardado localmente. Inicia sesión para '
          'sincronizarlo.';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _syncWarningMessage = null;
    notifyListeners();
    try {
      await _pushPending(cloud, adminId);
      await _reload();
      _syncRetry.notifySuccess();
    } on OwnerCloudRepositoryException catch (error) {
      _syncWarningMessage = error.message;
      if (error.type == OwnerCloudFailureType.network) {
        _syncRetry.notifyNetworkFailure();
      }
    } catch (_) {
      _syncWarningMessage =
          'El propietario quedó guardado localmente y se sincronizará al '
          'reintentar.';
      _syncRetry.notifyNetworkFailure();
    } finally {
      _isSyncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Borra primero lo que el usuario eliminó sin conexión y después sube los
  /// cambios. El orden importa: un pendiente de borrado no debe reenviarse
  /// como alta.
  Future<void> _pushPending(OwnerCloudRepository cloud, String adminId) async {
    final pendingDeletes = await _service.propietariosPendientesDeEliminar();
    for (final owner in pendingDeletes) {
      await cloud.deleteOwner(owner.id);
      await _service.eliminarPropietario(owner.id);
    }

    final pending = await _service.propietariosSinSincronizar();
    for (final owner in pending) {
      // Los datos demo viven solo en SQLite: nunca crean cuentas reales.
      if (owner.isLocalDemo) {
        await _service.marcarSincronizado(owner.id);
        continue;
      }
      await cloud.updateOwner(
        adminId: adminId,
        owner: owner,
        phoneCountryCodeId: _countryCodeIdFor(owner),
      );
      // Una cuenta pendiente de aprobación no se deshabilita desde el
      // interruptor: su estado lo decide el módulo de aprobación.
      if (!owner.isPendingApproval) {
        await cloud.setOwnerStatus(ownerId: owner.id, isActive: owner.isActive);
      }
      await _service.marcarSincronizado(owner.id);
    }
  }

  /// Id del maestro de indicativos que corresponde al país del propietario.
  int? _countryCodeIdFor(Owner owner) {
    final dial = owner.countryCode;
    if (dial == null) return null;
    for (final code in _countryPhoneCodes) {
      if (code.dialCode == dial) return code.id;
    }
    return null;
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

  /// Valida el número nacional con la longitud del país seleccionado.
  ///
  /// Si el maestro aún no cargó, cae a la validación genérica para no bloquear
  /// el formulario por un problema de red.
  String? validatePhone(String? value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) return 'Ingresa el teléfono.';

    final code = _selectedCountryCode;
    if (code == null) {
      if (!_phonePattern.hasMatch('+$digits')) {
        return 'Ingresa un teléfono válido, por ejemplo 300 123 4567.';
      }
      return null;
    }

    if (digits.length < code.phoneMinLength ||
        digits.length > code.phoneMaxLength) {
      final range = code.phoneMinLength == code.phoneMaxLength
          ? '${code.phoneMinLength}'
          : '${code.phoneMinLength} a ${code.phoneMaxLength}';
      return 'Ingresa un número de $range dígitos para ${code.countryName}.';
    }
    return null;
  }

  void _notifySyncRetryChanged() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _syncRetry.dispose();
    super.dispose();
  }
}
