import 'package:flutter/foundation.dart';
import 'package:machuco/models/additional_service/additional_service.dart';

class AdditionalServiceController extends ChangeNotifier {
  AdditionalServiceController._();

  static final AdditionalServiceController instance =
      AdditionalServiceController._();

  final List<AdditionalService> _services = [
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

  final Set<String> _selectedServiceIds = {'service-cloud-backup'};

  List<AdditionalService> get services => List.unmodifiable(_services);
  List<AdditionalService> get activeServices =>
      _services.where((service) => service.active).toList(growable: false);
  List<AdditionalService> get selectedServices => _services
      .where(
        (service) => service.active && _selectedServiceIds.contains(service.id),
      )
      .toList(growable: false);
  Set<String> get selectedServiceIds => Set.unmodifiable(_selectedServiceIds);
  int get activeCount => _services.where((service) => service.active).length;
  int get inactiveCount => _services.length - activeCount;
  int get selectedCount => _selectedServiceIds.length;
  int get selectedTotal => _services
      .where((service) => _selectedServiceIds.contains(service.id))
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

  void create({
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

  void update(
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
    if (service.active) _selectedServiceIds.remove(service.id);
    notifyListeners();
  }

  void delete(AdditionalService service) {
    _services.removeWhere((item) => item.id == service.id);
    _selectedServiceIds.remove(service.id);
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
