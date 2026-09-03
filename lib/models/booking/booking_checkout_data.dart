class BookingExtra {
  const BookingExtra({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
  });

  final String id;
  final String name;
  final String description;
  final int price;
}

class BookingCheckoutData {
  const BookingCheckoutData({
    required this.motelName,
    required this.motelAddress,
    required this.roomName,
    required this.roomNumber,
    required this.maxCapacity,
    required this.hourlyRate,
    required this.arrival,
    required this.departure,
    required this.guests,
    this.extras = const [],
  });

  final String motelName;
  final String motelAddress;
  final String roomName;
  final String roomNumber;
  final int maxCapacity;
  final int hourlyRate;
  final DateTime arrival;
  final DateTime departure;
  final int guests;
  final List<BookingExtra> extras;

  int get billableHours {
    final minutes = departure.difference(arrival).inMinutes;
    return ((minutes <= 0 ? 60 : minutes) / 60).ceil();
  }

  int get roomSubtotal => hourlyRate * billableHours;
  int get extrasSubtotal =>
      extras.fold(0, (total, extra) => total + extra.price);
  int get subtotal => roomSubtotal + extrasSubtotal;
  int get iva => (subtotal * .19).round();
  int get total => subtotal + iva;

  BookingCheckoutData copyWith({
    DateTime? arrival,
    DateTime? departure,
    int? guests,
    List<BookingExtra>? extras,
  }) {
    return BookingCheckoutData(
      motelName: motelName,
      motelAddress: motelAddress,
      roomName: roomName,
      roomNumber: roomNumber,
      maxCapacity: maxCapacity,
      hourlyRate: hourlyRate,
      arrival: arrival ?? this.arrival,
      departure: departure ?? this.departure,
      guests: guests ?? this.guests,
      extras: extras ?? this.extras,
    );
  }
}

enum BookingDurationMode { hours, exactDateTime }

enum BookingPaymentMethod { pse, card, nequi, daviplata, cash }

class ClientMotelPreview {
  const ClientMotelPreview({
    required this.id,
    required this.name,
    required this.location,
    required this.startingPrice,
    required this.rateLabel,
    required this.isAvailable,
  });

  final String id;
  final String name;
  final String location;
  final int startingPrice;
  final String rateLabel;
  final bool isAvailable;
}
