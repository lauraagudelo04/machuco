import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:machuco/models/payment/payment.dart';

/// Firestore representation of a local [PaymentRecord].
///
/// The authenticated owner is stored separately because it is an authorization
/// field and does not belong to the shared SQLite payment schema.
class PaymentFirestoreDocument {
  const PaymentFirestoreDocument({
    required this.ownerId,
    required this.payment,
    this.paymentMethodName,
  });

  final String ownerId;
  final PaymentRecord payment;
  final String? paymentMethodName;

  factory PaymentFirestoreDocument.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final statusName = _requiredString(data, 'status');
    final status = PaymentStatus.values.where(
      (candidate) => candidate.name == statusName,
    );
    if (status.isEmpty) {
      throw const FormatException('Estado de pago remoto inválido.');
    }

    final methodName = _optionalString(data, 'method');
    PaymentMethod? method;
    if (methodName != null) {
      for (final candidate in PaymentMethod.values) {
        if (candidate.name == methodName) method = candidate;
      }
    }
    if (methodName != null && method == null) {
      throw const FormatException('Método de pago remoto inválido.');
    }

    final amount = _requiredInt(data, 'amount');
    final paymentMethodId = _optionalInt(data, 'paymentMethodId');
    if (amount <= 0 || (paymentMethodId != null && paymentMethodId <= 0)) {
      throw const FormatException('Valores de pago remoto inválidos.');
    }

    return PaymentFirestoreDocument(
      ownerId: _requiredString(data, 'ownerId'),
      paymentMethodName: _optionalString(data, 'paymentMethodName'),
      payment: PaymentRecord(
        id: documentId,
        bookingId: _requiredString(data, 'bookingId'),
        bookingReference: _requiredString(data, 'bookingReference'),
        clientId: _requiredString(data, 'clientId'),
        client: _requiredString(data, 'client'),
        motelId: _requiredString(data, 'motelId'),
        motel: _requiredString(data, 'motel'),
        roomId: _requiredString(data, 'roomId'),
        room: _requiredString(data, 'room'),
        reservationDate: _requiredDate(data, 'reservationDate'),
        amount: amount,
        status: status.single,
        method: method,
        paymentMethodId: paymentMethodId,
        paidAt: _optionalDate(data, 'paidAt'),
        receiptNumber: _optionalString(data, 'receiptNumber'),
      ),
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'ownerId': ownerId,
    'bookingId': payment.bookingId,
    'bookingReference': payment.bookingReference,
    'clientId': payment.clientId,
    'client': payment.client,
    'motelId': payment.motelId,
    'motel': payment.motel,
    'roomId': payment.roomId,
    'room': payment.room,
    'reservationDate': Timestamp.fromDate(payment.reservationDate.toUtc()),
    'amount': payment.amount,
    'status': payment.status.name,
    if (payment.method != null) 'method': payment.method!.name,
    if (payment.paymentMethodId != null)
      'paymentMethodId': payment.paymentMethodId,
    if (paymentMethodName != null) 'paymentMethodName': paymentMethodName,
    if (payment.paidAt != null)
      'paidAt': Timestamp.fromDate(payment.paidAt!.toUtc()),
    if (payment.receiptNumber != null) 'receiptNumber': payment.receiptNumber,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty || value != value.trim()) {
      throw FormatException('Campo remoto inválido: $key.');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty || value != value.trim()) {
      throw FormatException('Campo remoto inválido: $key.');
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! int) throw FormatException('Campo remoto inválido: $key.');
    return value;
  }

  static int? _optionalInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! int) throw FormatException('Campo remoto inválido: $key.');
    return value;
  }

  static DateTime _requiredDate(Map<String, dynamic> data, String key) {
    final value = _optionalDate(data, key);
    if (value == null) throw FormatException('Campo remoto inválido: $key.');
    return value;
  }

  static DateTime? _optionalDate(Map<String, dynamic> data, String key) {
    return switch (data[key]) {
      null => null,
      Timestamp value => value.toDate(),
      DateTime value => value,
      _ => throw FormatException('Campo remoto inválido: $key.'),
    };
  }
}
