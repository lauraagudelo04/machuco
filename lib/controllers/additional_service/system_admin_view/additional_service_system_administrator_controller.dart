import 'package:flutter/foundation.dart';
import 'package:machuco/models/additional_service/additional_service.dart';

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
  AdditionalServiceSystemAdministratorController({required this.motelId});

  final String motelId;

  // Datos temporales en memoria, compartidos al volver a abrir una vista.
  static const List<AdditionalService> _motel1Services = [
    AdditionalService(
      id: '1',
      motelId: '1',
      name: 'Decoración romántica',
      description: 'Pétalos, globos y velas para la habitación.',
      category: 'Experiencias',
      price: 45000,
      active: true,
    ),
    AdditionalService(
      id: '2',
      motelId: '1',
      name: 'Desayuno para dos',
      description: 'Desayuno completo entregado en la habitación.',
      category: 'Alimentación',
      price: 28000,
      active: true,
    ),
    AdditionalService(
      id: '3',
      motelId: '1',
      name: 'Salida extendida',
      description: 'Dos horas adicionales de estadía.',
      category: 'Estadía',
      price: 30000,
      active: false,
    ),
  ];

  static const List<AdditionalService> _motel2Services = [
    AdditionalService(
      id: '4',
      motelId: '2',
      name: 'Limpieza adicional',
      description: 'Limpieza de la habitación durante la estadía.',
      category: 'Servicios',
      price: 12000,
      active: true,
    ),
    AdditionalService(
      id: '5',
      motelId: '2',
      name: 'Cena para dos',
      description: 'Cena especial con bebida para dos personas.',
      category: 'Alimentación',
      price: 65000,
      active: true,
    ),
    AdditionalService(
      id: '6',
      motelId: '2',
      name: 'Masaje relajante',
      description: 'Sesión de masaje de treinta minutos.',
      category: 'Bienestar',
      price: 55000,
      active: false,
    ),
  ];

  static const List<AdditionalService> _motel3Services = [
    AdditionalService(
      id: '7',
      motelId: '3',
      name: 'Acceso al jacuzzi',
      description: 'Una hora de uso privado del jacuzzi.',
      category: 'Bienestar',
      price: 40000,
      active: true,
    ),
    AdditionalService(
      id: '8',
      motelId: '3',
      name: 'Tabla de pasabocas',
      description: 'Selección de pasabocas para compartir.',
      category: 'Alimentación',
      price: 25000,
      active: true,
    ),
    AdditionalService(
      id: '9',
      motelId: '3',
      name: 'Decoración de cumpleaños',
      description: 'Globos y decoración para una celebración.',
      category: 'Celebraciones',
      price: 35000,
      active: false,
    ),
  ];

  static final List<AdditionalService> _services = [
    ..._motel1Services,
    ..._motel2Services,
    ..._motel3Services,
  ];
  static int _nextServiceSequence = 10;

  String? _nameError;
  String? _descriptionError;
  String? _categoryError;
  String? _priceError;

  List<AdditionalServiceData> get services =>
      getAdditionalServicesByMotelId(motelId);

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

  bool saveAdditionalService({
    String? serviceId,
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

    if (serviceId == null) {
      _services.add(
        AdditionalService(
          id: (_nextServiceSequence++).toString(),
          motelId: motelId,
          name: normalizedName,
          description: normalizedDescription,
          category: normalizedCategory,
          price: price!,
          active: true,
        ),
      );
    } else {
      final index = _services.indexWhere(
        (item) => item.id == serviceId && item.motelId == motelId,
      );
      if (index < 0) return false;
      _services[index] = _services[index].copyWith(
        name: normalizedName,
        description: normalizedDescription,
        category: normalizedCategory,
        price: price!,
      );
    }
    notifyListeners();
    return true;
  }

  void toggleAdditionalServiceActive(String serviceId) {
    final index = _services.indexWhere(
      (item) => item.id == serviceId && item.motelId == motelId,
    );
    if (index < 0) return;
    final current = _services[index];
    _services[index] = current.copyWith(active: !current.active);
    notifyListeners();
  }

  void deleteAdditionalService(String serviceId) {
    _services.removeWhere(
      (item) => item.id == serviceId && item.motelId == motelId,
    );
    notifyListeners();
  }
}
