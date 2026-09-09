import './../../../models/motel/motel_model.dart';

class ClientMotelController {
  final List<Motel> _mockDatabase = [
    Motel(
      id: '1',
      ownerId: 'owner-900123456',
      name: 'Motel Paraíso Élite',
      email: 'contacto@paraisoelite.com',
      roomCount: 15,
      nit: '900123456-1',
      address: 'Rionegro, Antioquia - A 5 min del centro',
      phone: '3001234567',
      description: 'Un espacio discreto y elegante con acabados de lujo, ideal para salir de la rutina y disfrutar en pareja.',
      generalLocation: 'Rionegro',
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
      roomCount: 10,
      nit: '900987654-2',
      address: 'Llanogrande, Antioquia',
      phone: '3109876543',
      description: 'Cabañas exclusivas rodeadas de naturaleza con la mayor privacidad y servicios de primera clase.',
      generalLocation: 'Llanogrande',
      paymentMethods: ['Efectivo', 'Transferencia'],
      imageUrls: ['url_imagen_2.jpg'],
      basePrice: 95000,
      isAvailable: false,
    ),
  ];

  Future<List<Motel>> getRecommendedMotels() async {
    await Future.delayed(const Duration(seconds: 1));
    return _mockDatabase;
  }
}