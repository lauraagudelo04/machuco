import 'dart:typed_data';

import 'package:machuco/models/invoice/invoice_model.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/utils/date_formatter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Genera el PDF de una factura y lo entrega al dispositivo.
abstract class InvoicePdfService {
  /// Construye el PDF de [invoice] y devuelve sus bytes.
  Future<Uint8List> build(InvoiceModel invoice);

  /// Entrega [bytes] al usuario: en móvil abre el diálogo nativo para
  /// guardar/compartir, en web lo descarga.
  Future<void> save(Uint8List bytes, String fileName);
}

/// Implementación con `package:pdf` (generación) y `package:printing`
/// (guardar/compartir).
///
/// Usa la fuente Helvetica integrada en el PDF, que solo cubre Latin-1: por
/// eso las fechas se escriben por separado y no con [formatDateRangeLabel]
/// (que usa "→").
class PrintingInvoicePdfService implements InvoicePdfService {
  const PrintingInvoicePdfService();

  @override
  Future<Uint8List> build(InvoiceModel invoice) async {
    final document = pw.Document(
      title: 'Factura ${invoice.invoiceNumber}',
      author: invoice.motelName,
    );
    final payment = invoice.payment;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Text(
            invoice.motelName,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Factura ${invoice.invoiceNumber}'),
          pw.Text('Emitida ${formatDateTimeLabel(invoice.issuedAt)}'),
          pw.SizedBox(height: 16),
          _section('Reserva', [
            if (invoice.clientName != null) ('Cliente', invoice.clientName!),
            ('Habitación', '${invoice.roomName} (N.° ${invoice.roomNumber})'),
            ('Entrada', formatDateTimeLabel(invoice.checkIn)),
            ('Salida', formatDateTimeLabel(invoice.checkOut)),
            ('Huéspedes', '${invoice.guestCount}'),
          ]),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Concepto', 'Cant.', 'Valor unit.', 'Subtotal'],
            data: [
              ['Habitación', '1', '', formatCurrencyAmount(invoice.roomTotal)],
              for (final item in invoice.items)
                [
                  item.name,
                  '${item.quantity}',
                  formatCurrencyAmount(item.unitPrice),
                  formatCurrencyAmount(item.subtotal),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignments: const {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total: ${formatCurrencyAmount(invoice.total)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (payment != null) ...[
            pw.SizedBox(height: 16),
            _section('Pago', [
              ('Concepto', payment.concept),
              ('Monto', formatCurrencyAmount(payment.amount)),
              if (payment.cardHolder != null) ('Titular', payment.cardHolder!),
              if (payment.cardLast4 != null)
                ('Tarjeta', '**** ${payment.cardLast4}'),
              if (payment.installments != null)
                ('Cuotas', '${payment.installments}'),
            ]),
          ],
        ],
      ),
    );

    return document.save();
  }

  @override
  Future<void> save(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);

  pw.Widget _section(String title, List<(String, String)> rows) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      for (final (label, value) in rows)
        pw.Row(
          children: [
            pw.SizedBox(width: 90, child: pw.Text(label)),
            pw.Expanded(child: pw.Text(value)),
          ],
        ),
    ],
  );
}
