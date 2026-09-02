import 'package:machuco/models/payment/payment.dart';

/// Datos y operaciones de apoyo para las vistas de pagos.
abstract final class PaymentController {
  static const List<PaymentReservation> reservations = [
    PaymentReservation(
      id: '1',
      motel: 'Motel Paraíso',
      room: 'Habitación 305 · Suite',
      date: '22 jul 2026',
      amount: '\$ 180.000',
      status: PaymentStatus.pending,
    ),
    PaymentReservation(
      id: '2',
      motel: 'Motel Paraíso',
      room: 'Habitación 112 · Junior',
      date: '25 jul 2026',
      amount: '\$ 120.000',
      status: PaymentStatus.pending,
    ),
    PaymentReservation(
      id: '3',
      motel: 'Hotel Mar y Sol',
      room: 'Habitación 208 · Deluxe',
      date: '28 jul 2026',
      amount: '\$ 210.000',
      status: PaymentStatus.pending,
    ),
  ];

  static const List<PendingPayment> pendingPayments = [
    PendingPayment(
      client: 'María López',
      room: 'Habitación 305 · Suite',
      amount: '\$ 180.000',
    ),
    PendingPayment(
      client: 'Carlos Ruiz',
      room: 'Habitación 112 · Junior',
      amount: '\$ 120.000',
    ),
    PendingPayment(
      client: 'Ana Torres',
      room: 'Habitación 208 · Deluxe',
      amount: '\$ 210.000',
    ),
  ];

  static const List<RecentPaymentClient> recentClients = [
    RecentPaymentClient(
      name: 'María López',
      initials: 'ML',
      reservations: '3 reservas',
    ),
    RecentPaymentClient(
      name: 'Carlos Ruiz',
      initials: 'CR',
      reservations: '2 reservas',
    ),
    RecentPaymentClient(
      name: 'Ana Torres',
      initials: 'AT',
      reservations: '5 reservas',
    ),
    RecentPaymentClient(
      name: 'Juan Gómez',
      initials: 'JG',
      reservations: '1 reserva',
    ),
  ];

  static const List<MotelFinance> motelFinances = [
    MotelFinance(
      name: 'Motel Paraíso',
      rooms: 24,
      monthlyIncome: '\$ 4.200.000',
    ),
    MotelFinance(
      name: 'Hotel Mar y Sol',
      rooms: 18,
      monthlyIncome: '\$ 3.150.000',
    ),
    MotelFinance(
      name: 'Hostal El Descanso',
      rooms: 12,
      monthlyIncome: '\$ 2.100.000',
    ),
    MotelFinance(
      name: 'Suites Centro',
      rooms: 30,
      monthlyIncome: '\$ 3.000.000',
    ),
  ];

  static PaymentReservation markAsPaid(PaymentReservation reservation) =>
      reservation.copyWith(status: PaymentStatus.paid);
}
