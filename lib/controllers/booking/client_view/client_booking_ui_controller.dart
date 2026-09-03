import 'package:machuco/models/booking/booking_checkout_data.dart';

/// Temporary in-memory data source for the client booking UI.
///
/// It will be replaced by repositories/state management when integration starts.
abstract final class ClientBookingUiController {
  static BookingCheckoutData get initialCheckout {
    final futureDate = DateTime.now().add(const Duration(days: 7));
    final arrival = DateTime(
      futureDate.year,
      futureDate.month,
      futureDate.day,
      20,
    );
    return BookingCheckoutData(
      motelName: 'Motel Eclipse',
      motelAddress: 'El Poblado, Medellín · Parqueadero privado',
      roomName: 'Suite Aurora',
      roomNumber: '101',
      maxCapacity: 4,
      hourlyRate: 68000,
      arrival: arrival,
      departure: arrival.add(const Duration(hours: 3)),
      guests: 2,
    );
  }

  static const extras = [
    BookingExtra(
      id: 'romantic',
      name: 'Decoración romántica',
      description: 'Pétalos, luces cálidas y detalle de bienvenida',
      price: 45000,
    ),
    BookingExtra(
      id: 'birthday',
      name: 'Montaje de cumpleaños',
      description: 'Globos, letrero y mesa decorativa',
      price: 55000,
    ),
    BookingExtra(
      id: 'sparkling',
      name: 'Bebida espumosa',
      description: 'Botella fría sin alcohol, 750 ml',
      price: 32000,
    ),
    BookingExtra(
      id: 'snacks',
      name: 'Combo minibar',
      description: 'Dos bebidas, chocolates y snacks',
      price: 28000,
    ),
  ];

  static const motels = [
    ClientMotelPreview(
      id: 'eclipse',
      name: 'Motel Eclipse',
      location: 'El Poblado, Medellín',
      startingPrice: 68000,
      rateLabel: 'hora',
      isAvailable: true,
    ),
    ClientMotelPreview(
      id: 'luna-roja',
      name: 'Luna Roja',
      location: 'Laureles, Medellín',
      startingPrice: 55000,
      rateLabel: 'hora',
      isAvailable: true,
    ),
    ClientMotelPreview(
      id: 'paraiso-elite',
      name: 'Paraíso Elite',
      location: 'Rionegro, Antioquia',
      startingPrice: 80000,
      rateLabel: '4 horas',
      isAvailable: true,
    ),
  ];
}
