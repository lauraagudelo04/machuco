import 'package:flutter/foundation.dart';
import 'package:machuco/models/additional_service/additional_service.dart';

class AdditionalServiceController extends ChangeNotifier {
  AdditionalServiceController({
    Iterable<AdditionalService>? initialServices,
    Iterable<String>? initialSelectedServiceIds,
  }) : _services = List.of(initialServices ?? _defaultServices),
       _selectedServiceIds = Set.of(
         initialSelectedServiceIds ?? const {'service-cloud-backup'},
       ) {
    final activeIds = _services
        .where((service) => service.active)
        .map((service) => service.id)
        .toSet();
    _selectedServiceIds.retainAll(activeIds);
  }

  static final AdditionalServiceController instance =
      AdditionalServiceController();

  static const List<AdditionalService> _defaultServices = [
    const AdditionalService(
      id: 'service-screen-insurance',
      icon: AdditionalServiceIcon.shield,
      name: 'Seguro de pantalla',
      description: 'Protección para dispositivos ante daños accidentales.',
      category: 'Protección',
      price: 9900,
      active: true,
    ),
    const AdditionalService(
      id: 'service-cloud-backup',
      icon: AdditionalServiceIcon.cloud,
      name: 'Respaldo en la nube',
      description: 'Almacenamiento seguro para archivos y fotografías.',
      category: 'Almacenamiento',
      price: 5900,
      active: true,
    ),
    const AdditionalService(
      id: 'service-technical-support',
      icon: AdditionalServiceIcon.support,
      name: 'Asistencia técnica',
      description: 'Servicio de asistencia y soporte técnico.',
      category: 'Soporte',
      price: 12900,
      active: true,
    ),
    const AdditionalService(
      id: 'service-extra-cleaning',
      icon: AdditionalServiceIcon.cleaning,
      name: 'Limpieza adicional',
      description: 'Servicio adicional de limpieza durante la estadía.',
      category: 'Servicios',
      price: 7900,
      active: false,
    ),
  ];

  final List<AdditionalService> _services;
  final Set<String> _selectedServiceIds;
  final Set<String> _draftSelectedServiceIds = {};

  String? _nameError;
  String? _descriptionError;
  String? _categoryError;
  String? _priceError;

  List<AdditionalService> get services => List.unmodifiable(_services);
  List<AdditionalService> get activeServices =>
      _services.where((service) => service.active).toList(growable: false);
  List<AdditionalService> get selectedServices => _services
      .where(
        (service) => service.active && _selectedServiceIds.contains(service.id),
      )
      .toList(growable: false);
  Set<String> get selectedServiceIds => Set.unmodifiable(_selectedServiceIds);
  Set<String> get draftSelectedServiceIds =>
      Set.unmodifiable(_draftSelectedServiceIds);
  String? get nameError => _nameError;
  String? get descriptionError => _descriptionError;
  String? get categoryError => _categoryError;
  String? get priceError => _priceError;
  int get activeCount => _services.where((service) => service.active).length;
  int get inactiveCount => _services.length - activeCount;
  int get selectedCount => _selectedServiceIds.length;
  int get selectedTotal => _services
      .where((service) => _selectedServiceIds.contains(service.id))
      .fold(0, (total, service) => total + service.price);
  int get draftSelectedCount => _draftSelectedServiceIds.length;
  int get draftSelectedTotal => activeServices
      .where((service) => _draftSelectedServiceIds.contains(service.id))
      .fold(0, (total, service) => total + service.price);

  List<String> get categories => [
    'Todos',
    ...{...activeServices.map((service) => service.category)},
  ];

  List<AdditionalService> searchAdmin(String query) =>
      _filter(_services, query: query);

  List<AdditionalService> searchClient(String query, String category) =>
      _filter(activeServices, query: query, category: category);

  List<AdditionalService> searchSelected(String query) =>
      _filter(selectedServices, query: query);

  bool isSelected(AdditionalService service) =>
      _selectedServiceIds.contains(service.id);

  bool isDraftSelected(AdditionalService service) =>
      _draftSelectedServiceIds.contains(service.id);

  void beginSelection() {
    _draftSelectedServiceIds
      ..clear()
      ..addAll(_selectedServiceIds);
  }

  void toggleDraftSelected(AdditionalService service) {
    if (!service.active) return;
    if (!_draftSelectedServiceIds.add(service.id)) {
      _draftSelectedServiceIds.remove(service.id);
    }
    notifyListeners();
  }

  void confirmSelection() {
    replaceSelected(_draftSelectedServiceIds);
  }

  void resetFormValidation() {
    _nameError = null;
    _descriptionError = null;
    _categoryError = null;
    _priceError = null;
  }

  void toggleSelected(AdditionalService service) {
    if (!service.active) return;
    if (!_selectedServiceIds.add(service.id)) {
      _selectedServiceIds.remove(service.id);
    }
    notifyListeners();
  }

  void replaceSelected(Iterable<String> serviceIds) {
    final activeIds = activeServices.map((service) => service.id).toSet();
    _selectedServiceIds
      ..clear()
      ..addAll(serviceIds.where(activeIds.contains));
    notifyListeners();
  }

  void removeSelected(AdditionalService service) {
    if (_selectedServiceIds.remove(service.id)) notifyListeners();
  }

  void _create({
    required String name,
    required String description,
    required String category,
    required int price,
  }) {
    _services.add(
      AdditionalService(
        id: 'service-${DateTime.now().microsecondsSinceEpoch}',
        icon: AdditionalServiceIcon.miscellaneous,
        name: name,
        description: description,
        category: category,
        price: price,
        active: true,
      ),
    );
    notifyListeners();
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
      _create(
        name: normalizedName,
        description: normalizedDescription,
        category: normalizedCategory,
        price: price!,
      );
    } else {
      _update(
        service,
        name: normalizedName,
        description: normalizedDescription,
        category: normalizedCategory,
        price: price!,
      );
    }
    return true;
  }

  void _update(
    AdditionalService service, {
    required String name,
    required String description,
    required String category,
    required int price,
  }) {
    final index = _services.indexWhere((item) => item.id == service.id);
    if (index < 0) return;
    _services[index] = service.copyWith(
      name: name,
      description: description,
      category: category,
      price: price,
    );
    notifyListeners();
  }

  void toggleActive(AdditionalService service) {
    final index = _services.indexWhere((item) => item.id == service.id);
    if (index < 0) return;
    _services[index] = service.copyWith(active: !service.active);
    if (service.active) {
      _selectedServiceIds.remove(service.id);
      _draftSelectedServiceIds.remove(service.id);
    }
    notifyListeners();
  }

  void delete(AdditionalService service) {
    _services.removeWhere((item) => item.id == service.id);
    _selectedServiceIds.remove(service.id);
    _draftSelectedServiceIds.remove(service.id);
    notifyListeners();
  }

  List<AdditionalService> _filter(
    Iterable<AdditionalService> source, {
    required String query,
    String category = 'Todos',
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return source
        .where((service) {
          final matchesCategory =
              category == 'Todos' || service.category == category;
          final matchesQuery =
              normalizedQuery.isEmpty ||
              service.name.toLowerCase().contains(normalizedQuery) ||
              service.description.toLowerCase().contains(normalizedQuery) ||
              service.category.toLowerCase().contains(normalizedQuery);
          return matchesCategory && matchesQuery;
        })
        .toList(growable: false);
  }
}
