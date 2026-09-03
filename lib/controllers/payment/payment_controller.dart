import 'package:machuco/models/payment/payment.dart';

/// Datos demostrativos y transformaciones de presentación del módulo de pagos.
/// La fuente debe sustituirse por un repositorio cuando se defina el backend.
abstract final class PaymentController {
  static const ownerMotelName = 'Motel Paraíso';

  static final List<PaymentRecord> clientPayments = [
    PaymentRecord(
      id: 'pay-001',
      bookingReference: 'RES-1048',
      client: 'María López',
      motel: 'Motel Paraíso',
      room: 'Habitación 305 · Suite',
      reservationDate: DateTime(2026, 9, 8, 20),
      amount: 180000,
      status: PaymentStatus.paid,
      method: PaymentMethod.online,
      paidAt: DateTime(2026, 9, 1, 14, 32),
      receiptNumber: 'CMP-2026-00841',
    ),
    PaymentRecord(
      id: 'pay-002',
      bookingReference: 'RES-1061',
      client: 'María López',
      motel: 'Hotel Mar y Sol',
      room: 'Habitación 208 · Deluxe',
      reservationDate: DateTime(2026, 9, 15, 22),
      amount: 210000,
      status: PaymentStatus.pending,
    ),
    PaymentRecord(
      id: 'pay-003',
      bookingReference: 'RES-0975',
      client: 'María López',
      motel: 'Suites Centro',
      room: 'Habitación 12 · Junior',
      reservationDate: DateTime(2026, 8, 12, 19),
      amount: 135000,
      status: PaymentStatus.refunded,
      method: PaymentMethod.online,
      paidAt: DateTime(2026, 8, 5, 9, 15),
      receiptNumber: 'CMP-2026-00732',
    ),
  ];

  static final List<PaymentRecord> ownerPayments = [
    PaymentRecord(
      id: 'owner-pay-001',
      bookingReference: 'RES-1082',
      client: 'Carlos Ruiz',
      motel: ownerMotelName,
      room: 'Habitación 112 · Junior',
      reservationDate: DateTime(2026, 9, 3, 21),
      amount: 120000,
      status: PaymentStatus.pending,
    ),
    PaymentRecord(
      id: 'owner-pay-002',
      bookingReference: 'RES-1087',
      client: 'Ana Torres',
      motel: ownerMotelName,
      room: 'Habitación 305 · Suite',
      reservationDate: DateTime(2026, 9, 4, 20),
      amount: 180000,
      status: PaymentStatus.pending,
    ),
    PaymentRecord(
      id: 'owner-pay-003',
      bookingReference: 'RES-1069',
      client: 'Juan Gómez',
      motel: ownerMotelName,
      room: 'Habitación 201 · Estándar',
      reservationDate: DateTime(2026, 9, 1, 18),
      amount: 95000,
      status: PaymentStatus.paid,
      method: PaymentMethod.online,
      paidAt: DateTime(2026, 8, 29, 11, 5),
      receiptNumber: 'CMP-2026-00822',
    ),
  ];

  static const List<FrequentClient> frequentClients = [
    FrequentClient(
      name: 'Ana Torres',
      initials: 'AT',
      reservations: 8,
      totalPaid: 1440000,
    ),
    FrequentClient(
      name: 'María López',
      initials: 'ML',
      reservations: 6,
      totalPaid: 1080000,
    ),
    FrequentClient(
      name: 'Carlos Ruiz',
      initials: 'CR',
      reservations: 4,
      totalPaid: 480000,
    ),
  ];

  static const List<MotelFinance> motelFinances = [
    MotelFinance(
      name: ownerMotelName,
      rooms: 24,
      income: 4200000,
      paymentsReceived: 38,
      pendingAmount: 300000,
      commissions: 210000,
    ),
    MotelFinance(
      name: 'Hotel Mar y Sol',
      rooms: 18,
      income: 3150000,
      paymentsReceived: 29,
      pendingAmount: 420000,
      commissions: 157500,
    ),
    MotelFinance(
      name: 'Hostal El Descanso',
      rooms: 12,
      income: 2100000,
      paymentsReceived: 21,
      pendingAmount: 190000,
      commissions: 105000,
    ),
    MotelFinance(
      name: 'Suites Centro',
      rooms: 30,
      income: 3000000,
      paymentsReceived: 27,
      pendingAmount: 250000,
      commissions: 150000,
    ),
  ];

  static MotelFinance get ownerFinance => motelFinances.first;

  static PaymentRecord registerCashPayment(PaymentRecord payment) =>
      payment.copyWith(
        status: PaymentStatus.paid,
        method: PaymentMethod.cash,
        paidAt: DateTime.now(),
        receiptNumber: 'CAJA-${payment.bookingReference}',
      );
}
