enum PaymentStatus { pending, paid, cancelled, completed, confirmed }

class PaymentReservation {
  const PaymentReservation({
    required this.id,
    required this.motel,
    required this.room,
    required this.date,
    required this.amount,
    required this.status,
  });

  final String id;
  final String motel;
  final String room;
  final String date;
  final String amount;
  final PaymentStatus status;

  PaymentReservation copyWith({PaymentStatus? status}) => PaymentReservation(
    id: id,
    motel: motel,
    room: room,
    date: date,
    amount: amount,
    status: status ?? this.status,
  );
}

class PendingPayment {
  const PendingPayment({
    required this.client,
    required this.room,
    required this.amount,
  });

  final String client;
  final String room;
  final String amount;
}

class RecentPaymentClient {
  const RecentPaymentClient({
    required this.name,
    required this.initials,
    required this.reservations,
  });

  final String name;
  final String initials;
  final String reservations;
}

class MotelFinance {
  const MotelFinance({
    required this.name,
    required this.rooms,
    required this.monthlyIncome,
  });

  final String name;
  final int rooms;
  final String monthlyIncome;
}
