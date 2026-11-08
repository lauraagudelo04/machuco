import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:machuco/models/booking/booking.dart';

/// Firestore representation of a [Reservation] (`reservations/{id}`).
///
/// [ownerId] is the owner of the reservation's motel. It is an authorization
/// field (security rules let that owner read the document) and is not part
/// of the local SQLite schema.
class ReservationFirestoreDocument {
  const ReservationFirestoreDocument({
    required this.ownerId,
    required this.reservation,
  });

  final String ownerId;
  final Reservation reservation;

  factory ReservationFirestoreDocument.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final guestCount = _requiredInt(data, 'guestCount');
    final roomTotal = _requiredInt(data, 'roomTotal');
    final total = _requiredInt(data, 'total');
    if (guestCount <= 0 || roomTotal < 0 || total < 0) {
      throw const FormatException('Valores de reserva remota inválidos.');
    }

    return ReservationFirestoreDocument(
      ownerId: _requiredString(data, 'ownerId'),
      reservation: Reservation(
        id: documentId,
        requestId: _requiredString(data, 'requestId'),
        motelId: _requiredString(data, 'motelId'),
        motelName: _requiredString(data, 'motelName'),
        roomId: _requiredString(data, 'roomId'),
        roomName: _requiredString(data, 'roomName'),
        roomNumber: _requiredString(data, 'roomNumber'),
        checkIn: _requiredDate(data, 'checkIn'),
        checkOut: _requiredDate(data, 'checkOut'),
        stayMode: _enum(StayMode.values, data, 'stayMode'),
        guestCount: guestCount,
        services: _lineItems(data, 'services'),
        products: _lineItems(data, 'products'),
        roomTotal: roomTotal,
        total: total,
        status: _enum(ReservationStatus.values, data, 'status'),
        createdAt: _requiredDate(data, 'createdAt'),
        guestId: _requiredString(data, 'guestId'),
        guestName: _plainString(data, 'guestName'),
        categoryId: _optionalInt(data, 'categoryId'),
        cancellationReason: _optionalString(data, 'cancellationReason'),
        invoiceAccessStatus: _enum(
          InvoiceAccessStatus.values,
          data,
          'invoiceAccessStatus',
        ),
        paymentMethod: _optionalString(data, 'paymentMethod'),
      ),
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'ownerId': ownerId,
    'guestId': reservation.guestId,
    'guestName': reservation.guestName,
    'requestId': reservation.requestId,
    'motelId': reservation.motelId,
    'motelName': reservation.motelName,
    'roomId': reservation.roomId,
    'roomName': reservation.roomName,
    'roomNumber': reservation.roomNumber,
    'checkIn': _timestamp(reservation.checkIn),
    'checkOut': _timestamp(reservation.checkOut),
    'stayMode': reservation.stayMode.name,
    'guestCount': reservation.guestCount,
    'services': [for (final item in reservation.services) _lineItem(item)],
    'products': [for (final item in reservation.products) _lineItem(item)],
    'roomTotal': reservation.roomTotal,
    'total': reservation.total,
    'status': reservation.status.name,
    'createdAt': _timestamp(reservation.createdAt),
    if (reservation.categoryId != null) 'categoryId': reservation.categoryId,
    if (reservation.cancellationReason != null)
      'cancellationReason': reservation.cancellationReason,
    'invoiceAccessStatus': reservation.invoiceAccessStatus.name,
    if (reservation.paymentMethod != null)
      'paymentMethod': reservation.paymentMethod,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Millisecond precision, like the SQLite cache: re-pushing a cached
  /// reservation must not look like a change to these immutable fields.
  static Timestamp _timestamp(DateTime value) =>
      Timestamp.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch);

  static Map<String, dynamic> _lineItem(ReservationLineItem item) => {
    'id': item.id,
    'name': item.name,
    'unitPrice': item.unitPrice,
    'quantity': item.quantity,
  };

  static List<ReservationLineItem> _lineItems(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key];
    if (value is! List) throw FormatException('Campo remoto inválido: $key.');
    return List.unmodifiable(
      value.map((raw) {
        if (raw is! Map) throw FormatException('Campo remoto inválido: $key.');
        final item = Map<String, dynamic>.from(raw);
        final unitPrice = _requiredInt(item, 'unitPrice');
        final quantity = _requiredInt(item, 'quantity');
        if (unitPrice < 0 || quantity <= 0) {
          throw FormatException('Campo remoto inválido: $key.');
        }
        return ReservationLineItem(
          id: _requiredString(item, 'id'),
          name: _requiredString(item, 'name'),
          unitPrice: unitPrice,
          quantity: quantity,
        );
      }),
    );
  }

  static T _enum<T extends Enum>(
    List<T> values,
    Map<String, dynamic> data,
    String key,
  ) {
    final name = _requiredString(data, key);
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Campo remoto inválido: $key.');
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty || value != value.trim()) {
      throw FormatException('Campo remoto inválido: $key.');
    }
    return value;
  }

  /// A string that may be empty (for example a guest without a name).
  static String _plainString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String) throw FormatException('Campo remoto inválido: $key.');
    return value;
  }

  static String? _optionalString(Map<String, dynamic> data, String key) {
    if (data[key] == null) return null;
    return _requiredString(data, key);
  }

  static int _requiredInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! int) throw FormatException('Campo remoto inválido: $key.');
    return value;
  }

  static int? _optionalInt(Map<String, dynamic> data, String key) {
    if (data[key] == null) return null;
    return _requiredInt(data, key);
  }

  static DateTime _requiredDate(Map<String, dynamic> data, String key) {
    return switch (data[key]) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      _ => throw FormatException('Campo remoto inválido: $key.'),
    };
  }
}
