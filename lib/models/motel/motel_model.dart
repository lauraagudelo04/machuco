class Motel {
  final String id;
  final String name;       // nombre
  final String email;      // correo
  final int roomCount;     // # habitaciones
  final String nit;        // nit
  final String address;    // dirección
  final String phone;      // telefono
  final List<String> paymentMethods; // métodos de pago
  final List<String> imageUrls;      // imágenes
  
  // Datos adicionales útiles para la vista del cliente
  final double basePrice;
  final bool isAvailable;

  Motel({
    required this.id,
    required this.name,
    required this.email,
    required this.roomCount,
    required this.nit,
    required this.address,
    required this.phone,
    required this.paymentMethods,
    required this.imageUrls,
    required this.basePrice,
    required this.isAvailable,
  });
}