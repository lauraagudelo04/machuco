import './../../../models/motel/motel_model.dart';

class ClientMotelController {
  // Simula una consulta a la base de datos
  Future<List<Motel>> getRecommendedMotels() async {
    // Simulamos el tiempo de espera (latencia) de la red
    await Future.delayed(const Duration(seconds: 1));

    // Retornamos la lista de objetos modelo
    return [
      Motel(
        id: '1',
        name: 'Motel Paraíso Élite',
        email: 'contacto@paraisoelite.com',
        roomCount: 15,
        nit: '900123456-1',
        address: 'Rionegro, Antioquia - A 5 min del centro',
        phone: '3001234567',
        paymentMethods: ['Efectivo', 'Nequi', 'Tarjeta'],
        imageUrls: ['url_imagen_1.jpg'],
        basePrice: 80000,
        isAvailable: true,
      ),
      Motel(
        id: '2',
        name: 'Motel El Edén',
        email: 'reservas@eleden.com',
        roomCount: 10,
        nit: '900987654-2',
        address: 'Llanogrande, Antioquia',
        phone: '3109876543',
        paymentMethods: ['Efectivo', 'Transferencia'],
        imageUrls: ['url_imagen_2.jpg'],
        basePrice: 95000,
        isAvailable: false,
      ),
    ];
  }
}