// Floor 1.5 marca TypeConverter como experimental; la base común ya lo utiliza.
// ignore_for_file: experimental_member_use

import 'package:floor/floor.dart';
import 'package:machuco/models/payment/payment_catalog_entry.dart';

enum PaymentStatus { pending, paid, refunded, cancelled }

/// Compatibilidad con los datos de demostración anteriores al maestro.
/// Los nuevos pagos en el local utilizan [PaymentRecord.paymentMethodId].
enum PaymentMethod { online, cash }

@Entity(
  tableName: 'payments',
  foreignKeys: [
    ForeignKey(
      childColumns: ['paymentMethodId'],
      parentColumns: ['id'],
      entity: PaymentCatalogEntry,
    ),
  ],
  indices: [
    Index(value: ['clientId']),
    Index(value: ['motelId']),
    Index(value: ['paymentMethodId']),
  ],
)
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
    this.paymentMethodId,
    this.paidAt,
    this.receiptNumber,
  });

  @primaryKey
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
  final int? paymentMethodId;
  final DateTime? paidAt;
  final String? receiptNumber;

  PaymentRecord copyWith({
    PaymentStatus? status,
    PaymentMethod? method,
    int? paymentMethodId,
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
    paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    paidAt: paidAt ?? this.paidAt,
    receiptNumber: receiptNumber ?? this.receiptNumber,
  );
}

class PaymentStatusConverter extends TypeConverter<PaymentStatus, String> {
  @override
  PaymentStatus decode(String value) => PaymentStatus.values.byName(value);

  @override
  String encode(PaymentStatus value) => value.name;
}

class PaymentMethodConverter extends TypeConverter<PaymentMethod?, String?> {
  @override
  PaymentMethod? decode(String? value) =>
      value == null ? null : PaymentMethod.values.byName(value);

  @override
  String? encode(PaymentMethod? value) => value?.name;
}

class PaymentOptionalDateConverter extends TypeConverter<DateTime?, int?> {
  @override
  DateTime? decode(int? value) =>
      value == null ? null : DateTime.fromMicrosecondsSinceEpoch(value);

  @override
  int? encode(DateTime? value) => value?.microsecondsSinceEpoch;
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
