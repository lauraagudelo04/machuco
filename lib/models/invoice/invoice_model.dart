import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';

/// Modelo simple para representar una factura generada a partir de una
/// reserva y (opcionalmente) los datos del método de pago usados.
class InvoiceModel {
  InvoiceModel({
    required this.id,
    required this.reservation,
    this.paymentMethod,
    DateTime? issuedAt,
  }) : issuedAt = issuedAt ?? DateTime.now();

  final String id;
  final Reservation reservation;
  final PaymentMethodModel? paymentMethod;
  final DateTime issuedAt;

  /// Total calculado a partir de la reserva. Se mantiene separado por claridad
  /// aunque por ahora es simplemente reservation.total.
  int get total => reservation.total;

  Map<String, dynamic> toJson() => {
        'id': id,
        'issuedAt': issuedAt.toIso8601String(),
        'reservationId': reservation.id,
        'motelName': reservation.motelName,
        'roomName': reservation.roomName,
        'roomNumber': reservation.roomNumber,
        'total': total,
        if (paymentMethod != null) 'payment': {
          'concept': paymentMethod!.concept,
          'amount': paymentMethod!.amount,
          'cardHolder': paymentMethod!.cardHolder,
          'cardNumber': paymentMethod!.cardNumber,
          'expiry': paymentMethod!.expiry,
          'installments': paymentMethod!.installments,
        }
      };

  @override
  String toString() => 'InvoiceModel(id: $id, reservation: ${reservation.id}, total: $total)';
}