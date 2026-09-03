import 'package:machuco/models/additional_service/additional_service.dart';

class AdditionalServiceStore {
  AdditionalServiceStore({
    Iterable<AdditionalService>? initialServices,
    Map<String, Set<String>>? initialSelectedServiceIdsByUser,
  }) : services = List.of(initialServices ?? defaultServices),
       selectedServiceIdsByUser =
           initialSelectedServiceIdsByUser ??
           {
             'user-demo-001': {
               'service-romantic-decoration',
               'service-breakfast',
             },
             'user-demo-002': {'service-extra-cleaning'},
           };

  static final AdditionalServiceStore instance = AdditionalServiceStore();

  static const List<AdditionalService> defaultServices = [
    AdditionalService(
      id: 'service-romantic-decoration',
      motelId: 'motel-demo-001',
      icon: AdditionalServiceIcon.miscellaneous,
      name: 'Decoración romántica',
      description: 'Decoración especial con pétalos, globos y velas.',
      category: 'Experiencias',
      price: 45000,
      active: true,
    ),
    AdditionalService(
      id: 'service-breakfast',
      motelId: 'motel-demo-001',
      icon: AdditionalServiceIcon.miscellaneous,
      name: 'Desayuno para dos',
      description: 'Desayuno completo entregado en la habitación.',
      category: 'Alimentación',
      price: 28000,
      active: true,
    ),
    AdditionalService(
      id: 'service-late-checkout',
      motelId: 'motel-demo-001',
      icon: AdditionalServiceIcon.support,
      name: 'Salida extendida',
      description: 'Extiende la estadía dos horas adicionales.',
      category: 'Estadía',
      price: 30000,
      active: true,
    ),
    AdditionalService(
      id: 'service-extra-cleaning',
      motelId: 'motel-demo-002',
      icon: AdditionalServiceIcon.cleaning,
      name: 'Limpieza adicional',
      description: 'Servicio adicional de limpieza durante la estadía.',
      category: 'Servicios',
      price: 7900,
      active: true,
    ),
  ];

  final List<AdditionalService> services;
  final Map<String, Set<String>> selectedServiceIdsByUser;

  Set<String> selectedServiceIdsFor(String userId) =>
      selectedServiceIdsByUser.putIfAbsent(userId, () => <String>{});
}
