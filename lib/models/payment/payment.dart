enum PaymentStatus { pending, paid, refunded, cancelled }

enum PaymentMethod { online, cash }

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.bookingReference,
    required this.client,
    required this.motel,
    required this.room,
    required this.reservationDate,
    required this.amount,
    required this.status,
    this.method,
    this.paidAt,
    this.receiptNumber,
  });

  final String id;
  final String bookingReference;
  final String client;
  final String motel;
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
    bookingReference: bookingReference,
    client: client,
    motel: motel,
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
    required this.name,
    required this.initials,
    required this.reservations,
    required this.totalPaid,
  });

  final String name;
  final String initials;
  final int reservations;
  final int totalPaid;
}

class MotelFinance {
  const MotelFinance({
    required this.name,
    required this.rooms,
    required this.income,
    required this.paymentsReceived,
    required this.pendingAmount,
    required this.commissions,
  });

  final String name;
  final int rooms;
  final int income;
  final int paymentsReceived;
  final int pendingAmount;
  final int commissions;
}
