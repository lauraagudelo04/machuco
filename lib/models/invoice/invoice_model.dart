import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';

/// Línea de servicio o producto "congelada" dentro de una factura.
class InvoiceLineItem {
  const InvoiceLineItem({
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) =>
      InvoiceLineItem(
        name: json['name'] as String,
        unitPrice: (json['unit_price'] as num).toInt(),
        quantity: (json['quantity'] as num).toInt(),
      );

  factory InvoiceLineItem.fromReservationItem(ReservationLineItem item) =>
      InvoiceLineItem(
        name: item.name,
        unitPrice: item.unitPrice,
        quantity: item.quantity,
      );

  final String name;
  final int unitPrice;
  final int quantity;

  int get subtotal => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
    'name': name,
    'unit_price': unitPrice,
    'quantity': quantity,
  };
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
      concept: paymentMethod.concept,
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

/// Factura emitida y guardada en Supabase (tabla `invoices`).
///
/// Es una copia inmutable de la reserva y del pago en el momento de emitirla:
/// si la reserva o el catálogo cambian después, la factura no cambia.
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

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final concept = json['payment_concept'] as String?;
    final amount = json['payment_amount'] as num?;
    return InvoiceModel(
      id: (json['id'] as num).toInt(),
      invoiceNumber: json['invoice_number'] as String,
      reservationId: json['reservation_id'] as String,
      clientId: json['client_id'] as String?,
      clientName: json['client_name'] as String?,
      motelId: json['motel_id'] as String,
      motelName: json['motel_name'] as String,
      roomName: json['room_name'] as String,
      roomNumber: json['room_number'] as String,
      checkIn: DateTime.parse(json['check_in'] as String).toLocal(),
      checkOut: DateTime.parse(json['check_out'] as String).toLocal(),
      guestCount: (json['guest_count'] as num).toInt(),
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => InvoiceLineItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      roomTotal: (json['room_total'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      payment: concept == null || amount == null
          ? null
          : InvoicePayment(
              concept: concept,
              amount: amount.toInt(),
              cardHolder: json['card_holder'] as String?,
              cardLast4: json['card_last4'] as String?,
              installments: (json['installments'] as num?)?.toInt(),
            ),
      issuedAt: DateTime.parse(json['issued_at'] as String).toLocal(),
    );
  }

  final int id;
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

  /// Total calculado por Supabase (habitación + servicios + productos).
  final int total;
  final InvoicePayment? payment;
  final DateTime issuedAt;

  /// Cuerpo que recibe la función `issue_invoice` de Supabase. El total no se
  /// envía: lo calcula el backend a partir de `room_total` e `items`.
  static Map<String, dynamic> issuePayload(
    Reservation reservation,
    PaymentMethodModel? paymentMethod,
  ) {
    final payment = paymentMethod == null
        ? null
        : InvoicePayment.fromPaymentMethod(paymentMethod);
    return {
      'reservation_id': reservation.id,
      'client_id': reservation.guestId.isEmpty ? null : reservation.guestId,
      'client_name': reservation.guestName.isEmpty
          ? null
          : reservation.guestName,
      'motel_id': reservation.motelId,
      'motel_name': reservation.motelName,
      'room_name': reservation.roomName,
      'room_number': reservation.roomNumber,
      'check_in': reservation.checkIn.toUtc().toIso8601String(),
      'check_out': reservation.checkOut.toUtc().toIso8601String(),
      'guest_count': reservation.guestCount,
      'items': [
        for (final item in [...reservation.services, ...reservation.products])
          InvoiceLineItem.fromReservationItem(item).toJson(),
      ],
      'room_total': reservation.roomTotal,
      'payment_concept': payment?.concept,
      'payment_amount': payment?.amount,
      'card_holder': payment?.cardHolder,
      'card_last4': payment?.cardLast4,
      'installments': payment?.installments,
    };
  }

  @override
  String toString() =>
      'InvoiceModel(number: $invoiceNumber, reservation: $reservationId, total: $total)';
}
