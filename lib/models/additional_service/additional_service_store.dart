import 'package:machuco/models/additional_service/additional_service.dart';

class AdditionalServiceStore {
  AdditionalServiceStore({
    Iterable<AdditionalService>? initialServices,
    Iterable<String>? initialSelectedServiceIds,
  }) : services = List.of(initialServices ?? defaultServices),
       selectedServiceIds = Set.of(
         initialSelectedServiceIds ?? const {'service-cloud-backup'},
       );

  static final AdditionalServiceStore instance = AdditionalServiceStore();

  static const List<AdditionalService> defaultServices = [
    AdditionalService(
      id: 'service-screen-insurance',
      icon: AdditionalServiceIcon.shield,
      name: 'Seguro de pantalla',
      description: 'Protección para dispositivos ante daños accidentales.',
      category: 'Protección',
      price: 9900,
      active: true,
    ),
    AdditionalService(
      id: 'service-cloud-backup',
      icon: AdditionalServiceIcon.cloud,
      name: 'Respaldo en la nube',
      description: 'Almacenamiento seguro para archivos y fotografías.',
      category: 'Almacenamiento',
      price: 5900,
      active: true,
    ),
    AdditionalService(
      id: 'service-technical-support',
      icon: AdditionalServiceIcon.support,
      name: 'Asistencia técnica',
      description: 'Servicio de asistencia y soporte técnico.',
      category: 'Soporte',
      price: 12900,
      active: true,
    ),
    AdditionalService(
      id: 'service-extra-cleaning',
      icon: AdditionalServiceIcon.cleaning,
      name: 'Limpieza adicional',
      description: 'Servicio adicional de limpieza durante la estadía.',
      category: 'Servicios',
      price: 7900,
      active: false,
    ),
  ];

  final List<AdditionalService> services;
  final Set<String> selectedServiceIds;
}
