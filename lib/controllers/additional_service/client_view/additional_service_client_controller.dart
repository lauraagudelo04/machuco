import 'package:flutter/foundation.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/models/additional_service/additional_service_store.dart';

class AdditionalServiceClientController extends ChangeNotifier {
  AdditionalServiceClientController({
    this.userId = demoUserId,
    AdditionalServiceStore? store,
  }) : _store = store ?? AdditionalServiceStore.instance;

  static const String demoUserId = 'user-demo-001';

  static final AdditionalServiceClientController instance =
      AdditionalServiceClientController();

  final AdditionalServiceStore _store;
  final String userId;
  final Set<String> _draftSelectedServiceIds = {};
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Set<String> get _selectedServiceIds => _store.selectedServiceIdsFor(userId);

  List<AdditionalService> get activeServices => _store.services
      .where((service) => service.active)
      .toList(growable: false);
  List<AdditionalService> get selectedServices => activeServices
      .where((service) => _selectedServiceIds.contains(service.id))
      .toList(growable: false);
  int get selectedCount => selectedServices.length;
  int get selectedTotal =>
      selectedServices.fold(0, (total, service) => total + service.price);
  int get draftSelectedCount => _draftSelectedServiceIds.length;
  int get draftSelectedTotal => activeServices
      .where((service) => _draftSelectedServiceIds.contains(service.id))
      .fold(0, (total, service) => total + service.price);
  List<String> get categories => [
    'Todos',
    ...{...activeServices.map((service) => service.category)},
  ];

  List<AdditionalService> searchAvailable(String query, String category) =>
      _filter(activeServices, query: query, category: category);

  List<AdditionalService> searchSelected(String query) =>
      _filter(selectedServices, query: query);

  bool isSelected(AdditionalService service) =>
      _selectedServiceIds.contains(service.id);

  bool isDraftSelected(AdditionalService service) =>
      _draftSelectedServiceIds.contains(service.id);

  Future<void> loadServicesByUserId() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final activeIds = activeServices.map((service) => service.id).toSet();
      _selectedServiceIds.retainAll(activeIds);
    } catch (_) {
      _errorMessage = 'No fue posible cargar tus servicios adicionales.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
    final activeIds = activeServices.map((service) => service.id).toSet();
    _selectedServiceIds
      ..clear()
      ..addAll(_draftSelectedServiceIds.where(activeIds.contains));
    notifyListeners();
  }

  void removeSelected(AdditionalService service) {
    if (_selectedServiceIds.remove(service.id)) notifyListeners();
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
