import '../../../models/motel/motel_model.dart';

class OwnerMotelController {
  // Simulamos una petición asíncrona a la base de datos
  Future<List<Motel>> getMyMotels() async {
    await Future.delayed(const Duration(seconds: 1)); // Retraso simulado
    
    return [
      Motel(
        id: '1',
        name: 'Motel Paraíso 1',
        email: 'admin@paraiso1.com',
        roomCount: 15,
        nit: '900123456-1',
        address: 'Calle 123 # 45-67',
        phone: '3001234567',
        paymentMethods: ['Efectivo', 'Tarjeta'],
        imageUrls: [],
        basePrice: 45000,
        isAvailable: true, // Activo
      ),
      Motel(
        id: '2',
        name: 'Motel Paraíso 2',
        email: 'admin@paraiso2.com',
        roomCount: 20,
        nit: '900123456-2',
        address: 'Avenida 45 # 12-34',
        phone: '3007654321',
        paymentMethods: ['Efectivo', 'Nequi'],
        imageUrls: [],
        basePrice: 55000,
        isAvailable: true, // Activo
      ),
      Motel(
        id: '3',
        name: 'Motel Paraíso 3',
        email: 'admin@paraiso3.com',
        roomCount: 30,
        nit: '900123456-3',
        address: 'Carrera 7 # 89-01',
        phone: '3119876543',
        paymentMethods: ['Efectivo'],
        imageUrls: [],
        basePrice: 35000,
        isAvailable: false, // Inhabilitado
      ),
    ];
  }
}