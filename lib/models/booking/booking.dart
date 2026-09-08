/// Modelos de dominio para la reserva de habitaciones del cliente.
///
/// Todo el flujo de "Reserva de habitación" y "Gestión de mis reservas" gira
/// en torno a [Reservation]. No existe backend real: estos modelos son la
/// forma que usa `ClientBookingController` para representar reservas
/// mantenidas en memoria.
library;

/// Estado de una reserva. Nunca se debe representar el estado con cadenas
/// mágicas: todo el dominio de reservas gira en torno a este enum estricto.
enum ReservationStatus { pending, active, upcoming, completed, cancelled }

extension ReservationStatusLabel on ReservationStatus {
  String get label => switch (this) {
    ReservationStatus.pending => 'Pendiente de pago',
    ReservationStatus.active => 'Activa',
    ReservationStatus.upcoming => 'Próxima',
    ReservationStatus.completed => 'Completada',
    ReservationStatus.cancelled => 'Cancelada',
  };
}

/// Las dos modalidades permitidas para definir la estancia de una reserva.
enum StayMode { dateTimeRange, dateWithHourBlock }

extension StayModeLabel on StayMode {
  String get label => switch (this) {
    StayMode.dateTimeRange => 'Fecha y hora de entrada y salida',
    StayMode.dateWithHourBlock => 'Fecha de entrada + bloque de horas',
  };
}

/// Máximo de horas permitido cuando la estancia se define como bloque.
const int maxStayHourBlock = 8;

/// Un servicio adicional o producto agregado a una reserva, ya "congelado"
/// (nombre y precio en el momento de reservar) para que el historial no
/// cambie si el catálogo del motel cambia después.
class ReservationLineItem {
  const ReservationLineItem({
    required this.id,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
  });

  final String id;
  final String name;
  final int unitPrice;
  final int quantity;

  int get subtotal => unitPrice * quantity;
}

/// Reserva de una habitación de motel hecha por un cliente.
class Reservation {
  const Reservation({
    required this.id,
    required this.requestId,
    required this.motelId,
    required this.motelName,
    required this.roomId,
    required this.roomName,
    required this.roomNumber,
    required this.checkIn,
    required this.checkOut,
    required this.stayMode,
    required this.guestCount,
    required this.services,
    required this.products,
    required this.roomTotal,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  final String id;

  /// Identificador generado por el cliente para la solicitud de creación de
  /// esta reserva. Permite lograr idempotencia: si una misma solicitud se
  /// reintenta tras un error de red, no se crea una reserva duplicada.
  final String requestId;

  final String motelId;
  final String motelName;
  final String roomId;
  final String roomName;
  final String roomNumber;
  final DateTime checkIn;
  final DateTime checkOut;
  final StayMode stayMode;
  final int guestCount;
  final List<ReservationLineItem> services;
  final List<ReservationLineItem> products;

  /// Subtotal correspondiente únicamente al costo de la habitación.
  final int roomTotal;

  /// Costo total de la reserva (habitación + servicios + productos).
  final int total;

  final ReservationStatus status;
  final DateTime createdAt;

  Duration get stayDuration => checkOut.difference(checkIn);

  int get servicesTotal => services.fold(0, (sum, item) => sum + item.subtotal);

  int get productsTotal => products.fold(0, (sum, item) => sum + item.subtotal);

  Reservation copyWith({ReservationStatus? status}) {
    return Reservation(
      id: id,
      requestId: requestId,
      motelId: motelId,
      motelName: motelName,
      roomId: roomId,
      roomName: roomName,
      roomNumber: roomNumber,
      checkIn: checkIn,
      checkOut: checkOut,
      stayMode: stayMode,
      guestCount: guestCount,
      services: services,
      products: products,
      roomTotal: roomTotal,
      total: total,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
