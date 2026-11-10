import 'package:flutter/foundation.dart';
import 'package:machuco/database/repository/additional_service/additional_service_category_repository.dart';
import 'package:machuco/database/repository/additional_service/additional_service_cloud_repository.dart';
import 'package:machuco/database/repository/additional_service/additional_service_repository.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/service/firebase/current_user.dart';

// Datos de salida del controlador: un record de Dart, sin exponer el modelo.
typedef AdditionalServiceData = ({
  String id,
  String motelId,
  String name,
  String description,
  String category,
  int price,
  bool active,
});

class AdditionalServiceSystemAdministratorController extends ChangeNotifier {
  AdditionalServiceSystemAdministratorController({
    required this.motelId,
    AdditionalServiceRepository? serviceRepository,
    AdditionalServiceCategoryRepository? categoryRepository,
    AdditionalServiceCloudRepository? cloudRepository,
    String? Function()? currentUserId,
  }) : _cloudOverride = cloudRepository,
       _currentUserId = currentUserId ?? (() => CurrentUser.uid),
       _serviceRepository = serviceRepository ?? AdditionalServiceRepository(),
       _categoryRepository =
           categoryRepository ?? AdditionalServiceCategoryRepository();

  final String motelId;
  final AdditionalServiceRepository _serviceRepository;
  final AdditionalServiceCategoryRepository _categoryRepository;
  final AdditionalServiceCloudRepository? _cloudOverride;
  final String? Function() _currentUserId;

  // Se crea al primer uso para no tocar Firebase al construir el controller.
  late final AdditionalServiceCloudRepository _cloud =
      _cloudOverride ?? FirestoreAdditionalServiceCloudRepository();

  final List<AdditionalService> _services = [];

  List<String> _categories = const [];
  bool _loading = false;
  String? _categoriesError;
  String? _syncError;

  String? _nameError;
  String? _descriptionError;
  String? _categoryError;
  String? _priceError;

  List<AdditionalServiceData> get services =>
      getAdditionalServicesByMotelId(motelId);

  List<String> get categories => List.unmodifiable(_categories);
  bool get isLoading => _loading;
  String? get categoriesError => _categoriesError;

  /// Último error al hablar con Firestore; `null` si todo salió bien.
  String? get syncError => _syncError;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      final services = await _serviceRepository.findAll();
      _services
        ..clear()
        ..addAll(services);

      // Las categorías vienen de Supabase y no dependen de Firestore: se piden
      // primero para que un fallo o demora de la nube no las bloquee.
      await _loadCategories();
      await _refreshFromCloud();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final loaded = await _categoryRepository.getCategories();
      _categories = loaded
          .map((c) => c.name)
          .where((name) => name.trim().isNotEmpty)
          .toList(growable: false);
      _categoriesError = null;
    } catch (error) {
      _categoriesError = error.toString();
      _categories = const [];
    }
  }

  /// Firestore es la fuente de verdad; SQLite es la copia para uso sin red.
  /// Si la consulta falla se conserva lo local y se informa en [syncError].
  Future<void> _refreshFromCloud() async {
    try {
      final remote = await _cloud.listByMotel(motelId);
      await _serviceRepository.replaceForMotel(motelId, remote);
      _services
        ..removeWhere((service) => service.motelId == motelId)
        ..addAll(remote);
      _syncError = null;
    } on AdditionalServiceCloudException catch (error) {
      _syncError = error.message;
    }
  }

  /// Ejecuta [action] contra Firestore. Devuelve `false` y deja el mensaje en
  /// [syncError] si falla, para no dejar la copia local adelantada a la nube.
  Future<bool> _pushToCloud(
    Future<void> Function(String ownerId) action,
  ) async {
    final ownerId = _currentUserId();
    if (ownerId == null || ownerId.isEmpty) {
      _syncError = 'Inicia sesión para gestionar los servicios adicionales.';
      notifyListeners();
      return false;
    }
    try {
      await action(ownerId);
      _syncError = null;
      return true;
    } on AdditionalServiceCloudException catch (error) {
      _syncError = error.message;
      notifyListeners();
      return false;
    }
  }

  List<AdditionalServiceData> getAdditionalServicesByMotelId(String motelId) =>
      List.unmodifiable(
        _services
            .where((service) => service.motelId == motelId)
            .map(_prepareServiceData),
      );

  /// Consulta solo los servicios activos del motel indicado.
  /// Devuelve una lista de solo lectura, vacia si no hay coincidencias.
  List<AdditionalServiceData> getActiveAdditionalServicesByMotelId(
    String motelId,
  ) => List.unmodifiable(
    getAdditionalServicesByMotelId(motelId).where((service) => service.active),
  );

  AdditionalServiceData _prepareServiceData(AdditionalService service) => (
    id: service.id,
    motelId: service.motelId,
    name: service.name,
    description: service.description,
    category: service.category,
    price: service.price,
    active: service.active,
  );

  AdditionalServiceData? getAdditionalServiceById(String serviceId) {
    for (final service in _services) {
      if (service.id == serviceId && service.motelId == motelId) {
        return _prepareServiceData(service);
      }
    }
    return null;
  }

  List<String> getAdditionalServiceCategoriesByMotelId(String motelId) {
    final categories = getAdditionalServicesByMotelId(
      motelId,
    ).map((service) => service.category).toSet().toList()..sort();
    return List.unmodifiable(categories);
  }

  int get activeCount => services.where((service) => service.active).length;
  int get inactiveCount => services.length - activeCount;
  String? get nameError => _nameError;
  String? get descriptionError => _descriptionError;
  String? get categoryError => _categoryError;
  String? get priceError => _priceError;

  List<AdditionalServiceData> filterAdditionalServices({
    String query = '',
    String? category,
    bool activeOnly = false,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return services
        .where((service) {
          return (!activeOnly || service.active) &&
              (category == null || service.category == category) &&
              (normalizedQuery.isEmpty ||
                  service.name.toLowerCase().contains(normalizedQuery) ||
                  service.description.toLowerCase().contains(normalizedQuery) ||
                  service.category.toLowerCase().contains(normalizedQuery));
        })
        .toList(growable: false);
  }

  void resetFormValidation() {
    _nameError = null;
    _descriptionError = null;
    _categoryError = null;
    _priceError = null;
  }

  Future<bool> saveAdditionalService({
    String? serviceId,
    required String name,
    required String description,
    required String category,
    required String priceText,
  }) async {
    final normalizedName = name.trim();
    final normalizedDescription = description.trim();
    final normalizedCategory = category.trim();
    final price = int.tryParse(priceText.trim());

    _nameError = normalizedName.isEmpty ? 'El nombre es obligatorio' : null;
    _descriptionError = normalizedDescription.isEmpty
        ? 'La descripción es obligatoria'
        : null;
    _categoryError = normalizedCategory.isEmpty
        ? 'La categoría es obligatoria'
        : null;
    _priceError = price == null || price <= 0
        ? 'Ingresa un precio mayor que cero'
        : null;

    if (_nameError != null ||
        _descriptionError != null ||
        _categoryError != null ||
        _priceError != null) {
      notifyListeners();
      return false;
    }

    if (serviceId == null) {
      final newService = AdditionalService(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        motelId: motelId,
        name: normalizedName,
        description: normalizedDescription,
        category: normalizedCategory,
        price: price!,
        active: true,
      );
      final saved = await _pushToCloud(
        (ownerId) => _cloud.create(ownerId: ownerId, service: newService),
      );
      if (!saved) return false;
      _services.add(newService);
      await _serviceRepository.insertService(newService);
    } else {
      final index = _services.indexWhere(
        (item) => item.id == serviceId && item.motelId == motelId,
      );
      if (index < 0) return false;
      final updated = _services[index].copyWith(
        name: normalizedName,
        description: normalizedDescription,
        category: normalizedCategory,
        price: price!,
      );
      final saved = await _pushToCloud((_) => _cloud.update(updated));
      if (!saved) return false;
      _services[index] = updated;
      await _serviceRepository.updateService(updated);
    }
    notifyListeners();
    return true;
  }

  Future<void> toggleAdditionalServiceActive(String serviceId) async {
    final index = _services.indexWhere(
      (item) => item.id == serviceId && item.motelId == motelId,
    );
    if (index < 0) return;
    final current = _services[index];
    final updated = current.copyWith(active: !current.active);
    final saved = await _pushToCloud((_) => _cloud.update(updated));
    if (!saved) return;
    _services[index] = updated;
    await _serviceRepository.updateService(updated);
    notifyListeners();
  }

  Future<void> deleteAdditionalService(String serviceId) async {
    final removed = _services.any(
      (item) => item.id == serviceId && item.motelId == motelId,
    );
    if (!removed) return;
    final deleted = await _pushToCloud((_) => _cloud.delete(serviceId));
    if (!deleted) return;
    _services.removeWhere(
      (item) => item.id == serviceId && item.motelId == motelId,
    );
    await _serviceRepository.deleteService(serviceId);
    notifyListeners();
  }
}
