import '../../models/motel/motel_model.dart';

class MotelController {
  // Base de datos simulada unificada
  final List<Motel> _mockDatabase = [
    Motel(
      id: '1',
      ownerId: 'owner-1020304050',
      name: 'Motel Paraíso Élite',
      email: 'admin@paraisoelite.com',
      roomCount: 15,
      nit: '900123456-1',
      address: 'Calle 123 # 45-67, Rionegro',
      phone: '3001234567',
      description:
          'Un espacio discreto y elegante con acabados de lujo, ideal para salir de la rutina y disfrutar en pareja.',
      generalLocation: 'Rionegro - Zona Rosa',
      paymentMethods: ['Efectivo', 'Nequi', 'Tarjeta'],
      imageUrls: ['url_imagen_1.jpg'],
      basePrice: 80000,
      isAvailable: true,
    ),
    Motel(
      id: '2',
      ownerId: 'owner-1020304050',
      name: 'Motel El Edén',
      email: 'reservas@eleden.com',
      roomCount: 20,
      nit: '900987654-2',
      address: 'Avenida Llanogrande # 12-34',
      phone: '3109876543',
      description:
          'Cabañas exclusivas rodeadas de naturaleza con la mayor privacidad y servicios de primera clase.',
      generalLocation: 'Llanogrande',
      paymentMethods: ['Efectivo', 'Transferencia'],
      imageUrls: ['url_imagen_2.jpg'],
      basePrice: 95000,
      isAvailable: true,
    ),
    Motel(
      id: '3',
      ownerId: 'owner-900123456',
      name: 'Motel Eclipse',
      email: 'contacto@moteleclipse.com',
      roomCount: 30,
      nit: '900123456-3',
      address: 'Carrera 7 # 89-01, Rionegro',
      phone: '3119876543',
      description:
          'Económico y acogedor. El mejor servicio al mejor precio del sector.',
      generalLocation: 'Rionegro - Centro',
      paymentMethods: ['Efectivo'],
      imageUrls: [],
      basePrice: 35000,
      isAvailable: true,
    ),
  ];

  // ==========================================
  // MÉTODOS PARA EL PROPIETARIO (OWNER)
  // ==========================================

  /// Obtiene los moteles pertenecientes al propietario con sesión activa.
  Future<List<Motel>> getMyMotels() async {
    await Future.delayed(const Duration(seconds: 1));

    const currentLoggedInUserId = 'owner-1020304050';

    return _mockDatabase
        .where((motel) => motel.ownerId == currentLoggedInUserId)
        .toList();
  }

  /// Obtiene los moteles filtrados por un ownerId específico.
  Future<List<Motel>> getMotelsByOwnerId(String ownerId) async {
    await Future.delayed(const Duration(milliseconds: 800));

    return _mockDatabase
        .where((motel) => motel.ownerId == ownerId)
        .toList();
  }

  // ==========================================
  // MÉTODOS PARA EL CLIENTE (CLIENT)
  // ==========================================

  /// Obtiene la lista de moteles recomendados / disponibles para la vista de clientes.
  Future<List<Motel>> getRecommendedMotels() async {
    await Future.delayed(const Duration(seconds: 1));

    // Filtra únicamente los moteles habilitados/disponibles para clientes
    return _mockDatabase.where((motel) => motel.isAvailable).toList();
  }

  /// Obtiene el catálogo completo de moteles.
  Future<List<Motel>> getAllMotels() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _mockDatabase;
  }

  /// Obtiene un motel específico por su ID.
  Future<Motel?> getMotelById(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _mockDatabase.cast<Motel?>().firstWhere(
          (motel) => motel?.id == id,
          orElse: () => null,
        );
  }
}