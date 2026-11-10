import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:machuco/models/invoice/invoice_model.dart';

/// Representación en Firestore de una [InvoiceModel] (`invoices/{reservationId}`).
///
/// [ownerId] es el propietario del motel de la reserva. Es un campo de
/// autorización (las reglas de seguridad dejan que ese propietario lea la
/// factura) y no forma parte del modelo que usa la pantalla.
class InvoiceFirestoreDocument {
  const InvoiceFirestoreDocument({
    required this.ownerId,
    required this.invoice,
  });

  final String ownerId;
  final InvoiceModel invoice;

  factory InvoiceFirestoreDocument.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final reservationId = _requiredString(data, 'reservationId');
    if (reservationId != documentId) {
      throw const FormatException('Factura remota con reserva inválida.');
    }
    final guestCount = _requiredInt(data, 'guestCount');
    final roomTotal = _requiredInt(data, 'roomTotal');
    final total = _requiredInt(data, 'total');
    if (guestCount <= 0 || roomTotal < 0 || total < 0) {
      throw const FormatException('Valores de factura remota inválidos.');
    }

    return InvoiceFirestoreDocument(
      ownerId: _requiredString(data, 'ownerId'),
      invoice: InvoiceModel(
        id: documentId,
        invoiceNumber: _requiredString(data, 'invoiceNumber'),
        reservationId: reservationId,
        clientId: _optionalString(data, 'clientId'),
        clientName: _optionalString(data, 'clientName'),
        motelId: _requiredString(data, 'motelId'),
        motelName: _requiredString(data, 'motelName'),
        roomName: _requiredString(data, 'roomName'),
        roomNumber: _requiredString(data, 'roomNumber'),
        checkIn: _requiredDate(data, 'checkIn'),
        checkOut: _requiredDate(data, 'checkOut'),
        guestCount: guestCount,
        items: _items(data),
        roomTotal: roomTotal,
        total: total,
        payment: _payment(data),
        issuedAt: _requiredDate(data, 'issuedAt'),
      ),
    );
  }

  /// Documento a crear. `issuedAt` lo pone el servidor de Firestore.
  Map<String, dynamic> toFirestore() {
    final payment = invoice.payment;
    return <String, dynamic>{
      'ownerId': ownerId,
      'reservationId': invoice.reservationId,
      'invoiceNumber': invoice.invoiceNumber,
      if (invoice.clientId != null) 'clientId': invoice.clientId,
      if (invoice.clientName != null) 'clientName': invoice.clientName,
      'motelId': invoice.motelId,
      'motelName': invoice.motelName,
      'roomName': invoice.roomName,
      'roomNumber': invoice.roomNumber,
      'checkIn': _timestamp(invoice.checkIn),
      'checkOut': _timestamp(invoice.checkOut),
      'guestCount': invoice.guestCount,
      'items': [
        for (final item in invoice.items)
          {
            'id': item.id,
            'name': item.name,
            'unitPrice': item.unitPrice,
            'quantity': item.quantity,
          },
      ],
      'roomTotal': invoice.roomTotal,
      'total': invoice.total,
      if (payment != null) ...{
        'paymentConcept': payment.concept,
        'paymentAmount': payment.amount,
        if (payment.cardHolder != null) 'cardHolder': payment.cardHolder,
        if (payment.cardLast4 != null) 'cardLast4': payment.cardLast4,
        if (payment.installments != null) 'installments': payment.installments,
      },
      'issuedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Misma precisión (milisegundos) que la reserva en Firestore, para que las
  /// reglas puedan comparar las fechas de la factura con las de la reserva.
  static Timestamp _timestamp(DateTime value) =>
      Timestamp.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch);

  static List<InvoiceLineItem> _items(Map<String, dynamic> data) {
    final value = data['items'];
    if (value is! List) {
      throw const FormatException('Campo remoto inválido: items.');
    }
    return List.unmodifiable(
      value.map((raw) {
        if (raw is! Map) {
          throw const FormatException('Campo remoto inválido: items.');
        }
        final item = Map<String, dynamic>.from(raw);
        final unitPrice = _requiredInt(item, 'unitPrice');
        final quantity = _requiredInt(item, 'quantity');
        if (unitPrice < 0 || quantity <= 0) {
          throw const FormatException('Campo remoto inválido: items.');
        }
        return InvoiceLineItem(
          id: _requiredString(item, 'id'),
          name: _requiredString(item, 'name'),
          unitPrice: unitPrice,
          quantity: quantity,
        );
      }),
    );
  }

  static InvoicePayment? _payment(Map<String, dynamic> data) {
    final concept = _optionalString(data, 'paymentConcept');
    final amount = _optionalInt(data, 'paymentAmount');
    if (concept == null || amount == null) return null;
    final cardLast4 = _optionalString(data, 'cardLast4');
    if (cardLast4 != null && !RegExp(r'^\d{4}$').hasMatch(cardLast4)) {
      throw const FormatException('Campo remoto inválido: cardLast4.');
    }
    return InvoicePayment(
      concept: concept,
      amount: amount,
      cardHolder: _optionalString(data, 'cardHolder'),
      cardLast4: cardLast4,
      installments: _optionalInt(data, 'installments'),
    );
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = _optionalString(data, key);
    if (value == null) throw FormatException('Campo remoto inválido: $key.');
    return value;
  }

  static String? _optionalString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Campo remoto inválido: $key.');
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> data, String key) {
    final value = _optionalInt(data, key);
    if (value == null) throw FormatException('Campo remoto inválido: $key.');
    return value;
  }

  static int? _optionalInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! int) throw FormatException('Campo remoto inválido: $key.');
    return value;
  }

  static DateTime _requiredDate(Map<String, dynamic> data, String key) =>
      switch (data[key]) {
        Timestamp value => value.toDate(),
        DateTime value => value,
        _ => throw FormatException('Campo remoto inválido: $key.'),
      };
}
