import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/invoice/invoice_model.dart';
import 'package:machuco/service/invoice/invoice_pdf_service.dart';

InvoiceModel _invoice({
  String motelName = 'Motel Luna',
  List<InvoiceLineItem> items = const [],
  InvoicePayment? payment,
  String? clientName = 'cliente@correo.com',
}) {
  final roomTotal = 680000;
  final total = items.fold<int>(roomTotal, (sum, item) => sum + item.subtotal);
  return InvoiceModel(
    id: 'res-1',
    invoiceNumber: 'FAC-RES1',
    reservationId: 'res-1',
    clientName: clientName,
    motelId: 'motel-1',
    motelName: motelName,
    roomName: 'Suite deluxe',
    roomNumber: '101',
    checkIn: DateTime(2026, 11, 29, 20),
    checkOut: DateTime(2026, 11, 30, 16),
    guestCount: 2,
    items: items,
    roomTotal: roomTotal,
    total: total,
    payment: payment,
    issuedAt: DateTime(2026, 11, 17, 17, 8),
  );
}

void main() {
  const service = PrintingInvoicePdfService();

  bool isPdf(List<int> bytes) => String.fromCharCodes(bytes.take(5)) == '%PDF-';

  test('genera el PDF de una factura sin servicios ni pago', () async {
    expect(isPdf(await service.build(_invoice())), isTrue);
  });

  test('genera el PDF con conceptos, pago y textos fuera de Latin-1', () async {
    final bytes = await service.build(
      _invoice(
        motelName: 'Motel Sol — Luna “VIP” 🌙 → Centro',
        clientName: null,
        items: const [
          InvoiceLineItem(
            id: 's1',
            name: 'Decoración romántica',
            unitPrice: 45000,
            quantity: 1,
          ),
          InvoiceLineItem(
            id: 'p1',
            name: 'Botella de vino…',
            unitPrice: 80000,
            quantity: 2,
          ),
        ],
        payment: const InvoicePayment(
          concept: 'Reserva Suite deluxe - Motel Sol',
          amount: 885000,
          cardHolder: 'Ana Pérez',
          cardLast4: '4242',
          installments: 3,
        ),
      ),
    );
    expect(isPdf(bytes), isTrue);
  });

  test('genera varias páginas cuando hay muchos conceptos', () async {
    final bytes = await service.build(
      _invoice(
        items: [
          for (var i = 1; i <= 40; i++)
            InvoiceLineItem(
              id: 'i$i',
              name: 'Producto $i',
              unitPrice: 1000 * i,
              quantity: 1,
            ),
        ],
      ),
    );
    expect(isPdf(bytes), isTrue);
  });
}
