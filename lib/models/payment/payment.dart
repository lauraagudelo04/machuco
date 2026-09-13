enum PaymentStatus { pending, paid, refunded, cancelled }

enum PaymentMethod { online, cash }

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.bookingId,
    required this.bookingReference,
    required this.clientId,
    required this.client,
    required this.motelId,
    required this.motel,
    required this.roomId,
    required this.room,
    required this.reservationDate,
    required this.amount,
    required this.status,
    this.method,
    this.paidAt,
    this.receiptNumber,
  });

  final String id;
  final String bookingId;
  final String bookingReference;
  final String clientId;
  final String client;
  final String motelId;
  final String motel;
  final String roomId;
  final String room;
  final DateTime reservationDate;
  final int amount;
  final PaymentStatus status;
  final PaymentMethod? method;
  final DateTime? paidAt;
  final String? receiptNumber;

  PaymentRecord copyWith({
    PaymentStatus? status,
    PaymentMethod? method,
    DateTime? paidAt,
    String? receiptNumber,
  }) => PaymentRecord(
    id: id,
    bookingId: bookingId,
    bookingReference: bookingReference,
    clientId: clientId,
    client: client,
    motelId: motelId,
    motel: motel,
    roomId: roomId,
    room: room,
    reservationDate: reservationDate,
    amount: amount,
    status: status ?? this.status,
    method: method ?? this.method,
    paidAt: paidAt ?? this.paidAt,
    receiptNumber: receiptNumber ?? this.receiptNumber,
  );
}

class FrequentClient {
  const FrequentClient({
    required this.clientId,
    required this.motelId,
    required this.name,
    required this.initials,
    required this.reservations,
    required this.totalPaid,
  });

  final String clientId;
  final String motelId;
  final String name;
  final String initials;
  final int reservations;
  final int totalPaid;
}

class MotelFinance {
  const MotelFinance({
    required this.motelId,
    required this.name,
    required this.rooms,
    required this.income,
    required this.paymentsReceived,
    required this.pendingAmount,
    required this.commissions,
  });

  final String motelId;
  final String name;
  final int rooms;
  final int income;
  final int paymentsReceived;
  final int pendingAmount;
  final int commissions;
}
