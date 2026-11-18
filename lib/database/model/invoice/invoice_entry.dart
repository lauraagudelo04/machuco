import 'dart:convert';

import 'package:floor/floor.dart';
import 'package:machuco/models/invoice/invoice_model.dart';

/// Copia local (SQLite) de una factura emitida en Firestore
/// (`invoices/{reservationId}`).
///
/// Firestore es la fuente de verdad: esta tabla solo se escribe con lo que
/// devuelve Firebase y se lee cuando no hay conexión. Nunca se crea una
/// factura solo aquí. Igual que en Firestore, no guarda el número completo de
/// la tarjeta, la fecha de vencimiento ni el CVV.
@Entity(
  tableName: 'invoices',
  indices: [
    Index(value: ['clientId']),
    Index(value: ['ownerId']),
  ],
)
class InvoiceEntry {
  const InvoiceEntry({
    required this.id,
    required this.ownerId,
    required this.invoiceNumber,
    required this.motelId,
    required this.motelName,
    required this.roomName,
    required this.roomNumber,
    required this.checkIn,
    required this.checkOut,
    required this.guestCount,
    required this.itemsJson,
    required this.roomTotal,
    required this.total,
    required this.issuedAt,
    this.clientId,
    this.clientName,
    this.paymentConcept,
    this.paymentAmount,
    this.cardHolder,
    this.cardLast4,
    this.installments,
    this.paymentMethodName,
  });

  factory InvoiceEntry.fromModel(
    InvoiceModel invoice, {
    required String ownerId,
  }) {
    final payment = invoice.payment;
    return InvoiceEntry(
      id: invoice.reservationId,
      ownerId: ownerId,
      invoiceNumber: invoice.invoiceNumber,
      clientId: invoice.clientId,
      clientName: invoice.clientName,
      motelId: invoice.motelId,
      motelName: invoice.motelName,
      roomName: invoice.roomName,
      roomNumber: invoice.roomNumber,
      checkIn: invoice.checkIn.millisecondsSinceEpoch,
      checkOut: invoice.checkOut.millisecondsSinceEpoch,
      guestCount: invoice.guestCount,
      itemsJson: jsonEncode([
        for (final item in invoice.items)
          {
            'id': item.id,
            'name': item.name,
            'unitPrice': item.unitPrice,
            'quantity': item.quantity,
          },
      ]),
      roomTotal: invoice.roomTotal,
      total: invoice.total,
      paymentConcept: payment?.concept,
      paymentAmount: payment?.amount,
      cardHolder: payment?.cardHolder,
      cardLast4: payment?.cardLast4,
      installments: payment?.installments,
      paymentMethodName: invoice.paymentMethodName,
      issuedAt: invoice.issuedAt.millisecondsSinceEpoch,
    );
  }

  /// Id de la reserva (una factura por reserva, igual que en Firestore).
  @primaryKey
  final String id;

  /// Propietario del motel; permite listar sus facturas sin conexión.
  final String ownerId;
  final String invoiceNumber;
  final String? clientId;
  final String? clientName;
  final String motelId;
  final String motelName;
  final String roomName;
  final String roomNumber;

  /// Milisegundos desde epoch.
  final int checkIn;
  final int checkOut;
  final int guestCount;

  /// Servicios y productos congelados en la factura, como JSON.
  final String itemsJson;
  final int roomTotal;
  final int total;
  final String? paymentConcept;
  final int? paymentAmount;
  final String? cardHolder;
  final String? cardLast4;
  final int? installments;
  final String? paymentMethodName;

  /// Milisegundos desde epoch (hora del servidor de Firestore).
  final int issuedAt;

  InvoiceModel toModel() {
    final concept = paymentConcept;
    final amount = paymentAmount;
    return InvoiceModel(
      id: id,
      invoiceNumber: invoiceNumber,
      reservationId: id,
      clientId: clientId,
      clientName: clientName,
      motelId: motelId,
      motelName: motelName,
      roomName: roomName,
      roomNumber: roomNumber,
      checkIn: DateTime.fromMillisecondsSinceEpoch(checkIn),
      checkOut: DateTime.fromMillisecondsSinceEpoch(checkOut),
      guestCount: guestCount,
      items: List.unmodifiable([
        for (final raw in jsonDecode(itemsJson) as List)
          InvoiceLineItem(
            id: (raw as Map)['id'] as String,
            name: raw['name'] as String,
            unitPrice: raw['unitPrice'] as int,
            quantity: raw['quantity'] as int,
          ),
      ]),
      roomTotal: roomTotal,
      total: total,
      payment: concept == null || amount == null
          ? null
          : InvoicePayment(
              concept: concept,
              amount: amount,
              cardHolder: cardHolder,
              cardLast4: cardLast4,
              installments: installments,
            ),
      paymentMethodName: paymentMethodName,
      issuedAt: DateTime.fromMillisecondsSinceEpoch(issuedAt),
    );
  }
}
