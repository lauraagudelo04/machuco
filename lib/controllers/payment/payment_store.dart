import 'package:flutter/foundation.dart';
import 'package:machuco/models/payment/payment.dart';

/// Fuente de datos compartida del mock de pagos.
///
/// Sustituirá su almacenamiento en memoria por un repositorio cuando el
/// proyecto defina el backend. La instancia [shared] permite que las vistas
/// por rol observen los mismos cambios durante la ejecución de la aplicación.
class PaymentStore extends ChangeNotifier {
  PaymentStore._();

  /// Crea una fuente aislada con datos inyectados, útil para pruebas y para
  /// sustituir gradualmente el mock sin acoplar los controladores al singleton.
  factory PaymentStore.seeded({
    List<PaymentRecord> payments = const [],
    List<FrequentClient> frequentClients = const [],
    List<MotelFinance> motelFinances = const [],
  }) {
    final store = PaymentStore._();
    store._payments
      ..clear()
      ..addAll(payments);
    store._frequentClients
      ..clear()
      ..addAll(frequentClients);
    store._motelFinances
      ..clear()
      ..addAll(motelFinances);
    return store;
  }

  static const demoClientId = 'client-maria-lopez';
  static const demoOwnerMotelId = '1';
  static final PaymentStore shared = PaymentStore._();

  final List<PaymentRecord> _payments = [
    PaymentRecord(
      id: 'pay-001',
      bookingId: 'booking-1048',
      bookingReference: 'RES-1048',
      clientId: demoClientId,
      client: 'María López',
      motelId: '1',
      motel: 'Motel Paraíso Élite',
      roomId: 'room-305',
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
      bookingId: 'booking-1061',
      bookingReference: 'RES-1061',
      clientId: demoClientId,
      client: 'María López',
      motelId: '2',
      motel: 'Hotel Mar y Sol',
      roomId: 'room-208',
      room: 'Habitación 208 · Deluxe',
      reservationDate: DateTime(2026, 9, 15, 22),
      amount: 210000,
      status: PaymentStatus.pending,
    ),
    PaymentRecord(
      id: 'pay-003',
      bookingId: 'booking-0975',
      bookingReference: 'RES-0975',
      clientId: demoClientId,
      client: 'María López',
      motelId: '4',
      motel: 'Suites Centro',
      roomId: 'room-012',
      room: 'Habitación 12 · Junior',
      reservationDate: DateTime(2026, 8, 12, 19),
      amount: 135000,
      status: PaymentStatus.refunded,
      method: PaymentMethod.online,
      paidAt: DateTime(2026, 8, 5, 9, 15),
      receiptNumber: 'CMP-2026-00732',
    ),
    PaymentRecord(
      id: 'owner-pay-001',
      bookingId: 'booking-1082',
      bookingReference: 'RES-1082',
      clientId: 'client-carlos-ruiz',
      client: 'Carlos Ruiz',
      motelId: demoOwnerMotelId,
      motel: 'Motel Paraíso Élite',
      roomId: 'room-112',
      room: 'Habitación 112 · Junior',
      reservationDate: DateTime(2026, 9, 3, 21),
      amount: 120000,
      status: PaymentStatus.pending,
    ),
    PaymentRecord(
      id: 'owner-pay-002',
      bookingId: 'booking-1087',
      bookingReference: 'RES-1087',
      clientId: 'client-ana-torres',
      client: 'Ana Torres',
      motelId: demoOwnerMotelId,
      motel: 'Motel Paraíso Élite',
      roomId: 'room-305',
      room: 'Habitación 305 · Suite',
      reservationDate: DateTime(2026, 9, 4, 20),
      amount: 180000,
      status: PaymentStatus.pending,
    ),
    PaymentRecord(
      id: 'owner-pay-003',
      bookingId: 'booking-1069',
      bookingReference: 'RES-1069',
      clientId: 'client-juan-gomez',
      client: 'Juan Gómez',
      motelId: demoOwnerMotelId,
      motel: 'Motel Paraíso Élite',
      roomId: 'room-201',
      room: 'Habitación 201 · Estándar',
      reservationDate: DateTime(2026, 9, 1, 18),
      amount: 95000,
      status: PaymentStatus.paid,
      method: PaymentMethod.online,
      paidAt: DateTime(2026, 8, 29, 11, 5),
      receiptNumber: 'CMP-2026-00822',
    ),
  ];

  final List<FrequentClient> _frequentClients = [
    FrequentClient(
      clientId: 'client-ana-torres',
      motelId: demoOwnerMotelId,
      name: 'Ana Torres',
      initials: 'AT',
      reservations: 8,
      totalPaid: 1440000,
    ),
    FrequentClient(
      clientId: demoClientId,
      motelId: demoOwnerMotelId,
      name: 'María López',
      initials: 'ML',
      reservations: 6,
      totalPaid: 1080000,
    ),
    FrequentClient(
      clientId: 'client-carlos-ruiz',
      motelId: demoOwnerMotelId,
      name: 'Carlos Ruiz',
      initials: 'CR',
      reservations: 4,
      totalPaid: 480000,
    ),
  ];

  final List<MotelFinance> _motelFinances = [
    MotelFinance(
      motelId: demoOwnerMotelId,
      name: 'Motel Paraíso Élite',
      rooms: 24,
      income: 4200000,
      paymentsReceived: 38,
      pendingAmount: 300000,
      commissions: 210000,
    ),
    MotelFinance(
      motelId: '2',
      name: 'Hotel Mar y Sol',
      rooms: 18,
      income: 3150000,
      paymentsReceived: 29,
      pendingAmount: 420000,
      commissions: 157500,
    ),
    MotelFinance(
      motelId: '3',
      name: 'Hostal El Descanso',
      rooms: 12,
      income: 2100000,
      paymentsReceived: 21,
      pendingAmount: 190000,
      commissions: 105000,
    ),
    MotelFinance(
      motelId: '4',
      name: 'Suites Centro',
      rooms: 30,
      income: 3000000,
      paymentsReceived: 27,
      pendingAmount: 250000,
      commissions: 150000,
    ),
  ];

  List<PaymentRecord> get payments => List.unmodifiable(_payments);
  List<FrequentClient> get frequentClients =>
      List.unmodifiable(_frequentClients);
  List<MotelFinance> get motelFinances => List.unmodifiable(_motelFinances);

  bool registerCashPayment(String paymentId) {
    final index = _payments.indexWhere((payment) => payment.id == paymentId);
    if (index == -1 || _payments[index].status != PaymentStatus.pending) {
      return false;
    }

    final payment = _payments[index];
    _payments[index] = payment.copyWith(
      status: PaymentStatus.paid,
      method: PaymentMethod.cash,
      paidAt: DateTime.now(),
      receiptNumber: 'CAJA-${payment.bookingReference}',
    );
    notifyListeners();
    return true;
  }
}
