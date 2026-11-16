import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';

/// Línea de servicio o producto "congelada" dentro de una factura.
class InvoiceLineItem {
  const InvoiceLineItem({
    required this.id,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  factory InvoiceLineItem.fromReservationItem(ReservationLineItem item) =>
      InvoiceLineItem(
        id: item.id,
        name: item.name,
        unitPrice: item.unitPrice,
        quantity: item.quantity,
      );

  final String id;
  final String name;
  final int unitPrice;
  final int quantity;

  int get subtotal => unitPrice * quantity;
}

/// Datos del pago visibles en la factura. Nunca contiene el número completo
/// de la tarjeta, la fecha de vencimiento ni el CVV: solo los últimos 4
/// dígitos.
class InvoicePayment {
  const InvoicePayment({
    required this.concept,
    required this.amount,
    this.cardHolder,
    this.cardLast4,
    this.installments,
  });

  /// Extrae del método de pago solo lo que puede quedar en la factura.
  factory InvoicePayment.fromPaymentMethod(PaymentMethodModel paymentMethod) {
    final digits = paymentMethod.cardNumber.replaceAll(RegExp(r'\D'), '');
    final holder = paymentMethod.cardHolder.trim();
    final hasCard = digits.length >= 4;
    return InvoicePayment(
      concept: paymentMethod.concept.trim(),
      amount: paymentMethod.amount,
      cardHolder: holder.isEmpty ? null : holder,
      cardLast4: hasCard ? digits.substring(digits.length - 4) : null,
      installments: hasCard ? paymentMethod.installments : null,
    );
  }

  final String concept;
  final int amount;
  final String? cardHolder;
  final String? cardLast4;
  final int? installments;
}

/// Factura emitida y guardada en Cloud Firestore (`invoices/{reservationId}`).
///
/// Es una copia inmutable de la reserva y del pago en el momento de emitirla:
/// si la reserva o el catálogo cambian después, la factura no cambia. Hay
/// como máximo una factura por reserva, por eso [id] es el id de la reserva.
class InvoiceModel {
  const InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.reservationId,
    required this.motelId,
    required this.motelName,
    required this.roomName,
    required this.roomNumber,
    required this.checkIn,
    required this.checkOut,
    required this.guestCount,
    required this.items,
    required this.roomTotal,
    required this.total,
    required this.issuedAt,
    this.clientId,
    this.clientName,
    this.payment,
  });

  /// Construye la factura de [reservation] tal como debe quedar guardada.
  ///
  /// [issuedAt] es provisional: Firestore guarda la hora del servidor.
  factory InvoiceModel.fromReservation(
    Reservation reservation, {
    PaymentMethodModel? paymentMethod,
    DateTime? issuedAt,
  }) => InvoiceModel(
    id: reservation.id,
    invoiceNumber: numberFor(reservation.id),
    reservationId: reservation.id,
    clientId: reservation.guestId.isEmpty ? null : reservation.guestId,
    clientName: reservation.guestName.trim().isEmpty
        ? null
        : reservation.guestName.trim(),
    motelId: reservation.motelId,
    motelName: reservation.motelName,
    roomName: reservation.roomName,
    roomNumber: reservation.roomNumber,
    checkIn: reservation.checkIn,
    checkOut: reservation.checkOut,
    guestCount: reservation.guestCount,
    items: List.unmodifiable([
      for (final item in [...reservation.services, ...reservation.products])
        InvoiceLineItem.fromReservationItem(item),
    ]),
    roomTotal: reservation.roomTotal,
    total: reservation.total,
    payment: paymentMethod == null
        ? null
        : InvoicePayment.fromPaymentMethod(paymentMethod),
    issuedAt: issuedAt ?? DateTime.now(),
  );

  final String id;
  final String invoiceNumber;
  final String reservationId;
  final String? clientId;
  final String? clientName;
  final String motelId;
  final String motelName;
  final String roomName;
  final String roomNumber;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guestCount;
  final List<InvoiceLineItem> items;
  final int roomTotal;

  /// Total de la reserva (habitación + servicios + productos), copiado de la
  /// reserva guardada en Firebase al emitir la factura.
  final int total;
  final InvoicePayment? payment;
  final DateTime issuedAt;

  /// Número visible de la factura. Se deriva del id de la reserva, así que es
  /// único y estable aunque la emisión se reintente.
  static String numberFor(String reservationId) {
    final code = reservationId.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    return 'FAC-${code.length > 20 ? code.substring(code.length - 20) : code}';
  }

  @override
  String toString() =>
      'InvoiceModel(number: $invoiceNumber, reservation: $reservationId, total: $total)';
}
