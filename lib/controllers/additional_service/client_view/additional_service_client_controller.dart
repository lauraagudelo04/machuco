import 'package:flutter/foundation.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/models/additional_service/additional_service_store.dart';

class AdditionalServiceClientController extends ChangeNotifier {
  AdditionalServiceClientController({AdditionalServiceStore? store})
    : _store = store ?? AdditionalServiceStore.instance {
    final activeIds = activeServices.map((service) => service.id).toSet();
    _store.selectedServiceIds.retainAll(activeIds);
  }

  static final AdditionalServiceClientController instance =
      AdditionalServiceClientController();

  final AdditionalServiceStore _store;
  final Set<String> _draftSelectedServiceIds = {};

  List<AdditionalService> get activeServices => _store.services
      .where((service) => service.active)
      .toList(growable: false);
  List<AdditionalService> get selectedServices => activeServices
      .where((service) => _store.selectedServiceIds.contains(service.id))
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
      _store.selectedServiceIds.contains(service.id);

  bool isDraftSelected(AdditionalService service) =>
      _draftSelectedServiceIds.contains(service.id);

  void beginSelection() {
    _draftSelectedServiceIds
      ..clear()
      ..addAll(_store.selectedServiceIds);
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
    _store.selectedServiceIds
      ..clear()
      ..addAll(_draftSelectedServiceIds.where(activeIds.contains));
    notifyListeners();
  }

  void removeSelected(AdditionalService service) {
    if (_store.selectedServiceIds.remove(service.id)) notifyListeners();
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
