import '../../models/motel/motel_model.dart';

class MotelController {
  // ¡EL CAMBIO CLAVE!: Agregamos 'static' para que esta lista sea compartida 
  // en toda la memoria de la aplicación, sin importar cuántas veces llames al controlador.
  static final List<Motel> _mockDatabase = [
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
      isAvailable: true,
    ),
  ];

  // ==========================================
  // MÉTODOS DE CONSULTA (GET) - Ya los tenías
  // ==========================================
  
  Future<List<Motel>> getMyMotels() async {
    await Future.delayed(const Duration(seconds: 1));
    const currentLoggedInUserId = 'owner-1020304050';
    return _mockDatabase
        .where((motel) => motel.ownerId == currentLoggedInUserId)
        .toList();
  }

  Future<List<Motel>> getMotelsByOwnerId(String ownerId) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _mockDatabase.where((motel) => motel.ownerId == ownerId).toList();
  }

  Future<List<Motel>> getRecommendedMotels() async {
    await Future.delayed(const Duration(seconds: 1));
    return _mockDatabase.where((motel) => motel.isAvailable).toList();
  }

  Future<List<Motel>> getAllMotels() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _mockDatabase;
  }

  Future<Motel?> getMotelById(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _mockDatabase.cast<Motel?>().firstWhere(
          (motel) => motel?.id == id,
          orElse: () => null,
        );
  }

  // ==========================================
  // NUEVOS MÉTODOS DE MUTACIÓN (POST/PUT/PATCH simulados)
  // ==========================================

  /// Agrega un nuevo motel a la base de datos simulada
  Future<void> addMotel(Motel newMotel) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _mockDatabase.add(newMotel);
  }

  /// Actualiza la información de un motel existente
  Future<void> updateMotel(Motel updatedMotel) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = _mockDatabase.indexWhere((m) => m.id == updatedMotel.id);
    if (index != -1) {
      _mockDatabase[index] = updatedMotel;
    }
  }

  /// Cambia el estado (isAvailable) de un motel específico
  Future<void> toggleMotelStatus(String motelId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockDatabase.indexWhere((m) => m.id == motelId);
    if (index != -1) {
      final current = _mockDatabase[index];
      // Reemplazamos el motel con una copia invirtiendo el estado isAvailable
      _mockDatabase[index] = Motel(
        id: current.id,
        ownerId: current.ownerId,
        name: current.name,
        email: current.email,
        roomCount: current.roomCount,
        nit: current.nit,
        address: current.address,
        phone: current.phone,
        description: current.description,
        generalLocation: current.generalLocation,
        paymentMethods: current.paymentMethods,
        imageUrls: current.imageUrls,
        isAvailable: !current.isAvailable, 
      );
    }
  }
}