import 'package:flutter/foundation.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/models/additional_service/additional_service_store.dart';

class AdditionalServiceSystemAdministratorController extends ChangeNotifier {
  AdditionalServiceSystemAdministratorController({
    this.motelId = demoMotelId,
    AdditionalServiceStore? store,
  }) : _store = store ?? AdditionalServiceStore.instance;

  static const String demoMotelId = 'motel-demo-001';

  static final AdditionalServiceSystemAdministratorController instance =
      AdditionalServiceSystemAdministratorController();

  final AdditionalServiceStore _store;
  final String motelId;
  bool _isLoading = false;
  String? _errorMessage;
  String? _nameError;
  String? _descriptionError;
  String? _categoryError;
  String? _priceError;

  List<AdditionalService> get services => List.unmodifiable(
    _store.services.where((service) => service.motelId == motelId),
  );
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get activeCount => services.where((service) => service.active).length;
  int get inactiveCount => services.length - activeCount;
  String? get nameError => _nameError;
  String? get descriptionError => _descriptionError;
  String? get categoryError => _categoryError;
  String? get priceError => _priceError;

  List<AdditionalService> search(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    return services
        .where((service) {
          return normalizedQuery.isEmpty ||
              service.name.toLowerCase().contains(normalizedQuery) ||
              service.description.toLowerCase().contains(normalizedQuery) ||
              service.category.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  Future<void> loadServicesByMotelId() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } catch (_) {
      _errorMessage = 'No fue posible cargar los servicios del motel.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetFormValidation() {
    _nameError = null;
    _descriptionError = null;
    _categoryError = null;
    _priceError = null;
  }

  bool save({
    AdditionalService? service,
    required String name,
    required String description,
    required String category,
    required String priceText,
  }) {
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

    if (service == null) {
      _store.services.add(
        AdditionalService(
          id: 'service-${DateTime.now().microsecondsSinceEpoch}',
          motelId: motelId,
          icon: AdditionalServiceIcon.miscellaneous,
          name: normalizedName,
          description: normalizedDescription,
          category: normalizedCategory,
          price: price!,
          active: true,
        ),
      );
    } else {
      final index = _store.services.indexWhere((item) => item.id == service.id);
      if (index < 0) return false;
      _store.services[index] = service.copyWith(
        name: normalizedName,
        description: normalizedDescription,
        category: normalizedCategory,
        price: price!,
      );
    }
    notifyListeners();
    return true;
  }

  void toggleActive(AdditionalService service) {
    final index = _store.services.indexWhere((item) => item.id == service.id);
    if (index < 0) return;
    _store.services[index] = service.copyWith(active: !service.active);
    if (service.active) {
      for (final selectedIds in _store.selectedServiceIdsByUser.values) {
        selectedIds.remove(service.id);
      }
    }
    notifyListeners();
  }

  void delete(AdditionalService service) {
    _store.services.removeWhere((item) => item.id == service.id);
    for (final selectedIds in _store.selectedServiceIdsByUser.values) {
      selectedIds.remove(service.id);
    }
    notifyListeners();
  }
}
