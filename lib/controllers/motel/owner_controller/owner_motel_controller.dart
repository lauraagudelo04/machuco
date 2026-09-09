import '../../../models/motel/motel_model.dart';

class OwnerMotelController {
  final List<Motel> _mockDatabase = [
    Motel(
      id: '1',
      ownerId: 'owner-1020304050',
      name: 'Motel Paraíso 1',
      email: 'admin@paraiso1.com',
      roomCount: 15,
      nit: '900123456-1',
      address: 'Calle 123 # 45-67',
      phone: '3001234567',
      description: 'Un lugar exclusivo y discreto para tus mejores momentos. Habitaciones temáticas y servicio 24/7.',
      generalLocation: 'Centro - Zona Rosa',
      paymentMethods: ['Efectivo', 'Tarjeta'],
      imageUrls: [],
      basePrice: 45000,
      isAvailable: true, 
    ),
    Motel(
      id: '2',
      ownerId: 'owner-1020304050',
      name: 'Motel Paraíso 2',
      email: 'admin@paraiso2.com',
      roomCount: 20,
      nit: '900123456-2',
      address: 'Avenida 45 # 12-34',
      phone: '3007654321',
      description: 'Confort y lujo a las afueras de la ciudad. Perfecto para escapar de la rutina con total privacidad.',
      generalLocation: 'Norte - Vía Principal',
      paymentMethods: ['Efectivo', 'Nequi'],
      imageUrls: [],
      basePrice: 55000,
      isAvailable: true, 
    ),
    Motel(
      id: '3',
      ownerId: 'owner-900123456',
      name: 'Motel Paraíso 3',
      email: 'admin@paraiso3.com',
      roomCount: 30,
      nit: '900123456-3',
      address: 'Carrera 7 # 89-01',
      phone: '3119876543',
      description: 'Económico y acogedor. El mejor servicio al mejor precio del sector.',
      generalLocation: 'Sur - Cerca al Parque',
      paymentMethods: ['Efectivo'],
      imageUrls: [],
      basePrice: 35000,
      isAvailable: false, 
    ),
  ];

  Future<List<Motel>> getMyMotels() async {
    await Future.delayed(const Duration(seconds: 1));
    
    const currentLoggedInUserId = 'owner-1020304050'; 

    return _mockDatabase
        .where((motel) => motel.ownerId == currentLoggedInUserId)
        .toList();
  }

  Future<List<Motel>> getMotelsByOwnerId(String ownerId) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Retraso simulado
    
    return _mockDatabase
        .where((motel) => motel.ownerId == ownerId)
        .toList();
  }
}