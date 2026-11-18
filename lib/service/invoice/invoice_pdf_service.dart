import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
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
/// Todo el contenido (establecimiento, cliente, habitación, conceptos,
/// totales y pago) sale de [InvoiceModel]; solo la marca "Machuco" es fija.
///
/// Usa las fuentes integradas del PDF (Helvetica y Times), que solo cubren
/// Latin-1: por eso los textos que vienen de los datos pasan por [_pdfText] y
/// las fechas se escriben por separado y no con [formatDateRangeLabel] (que
/// usa "→").
class PrintingInvoicePdfService implements InvoicePdfService {
  const PrintingInvoicePdfService();

  static const _brand = 'MACHUCO';
  static const _brandTagline = 'Reservas de Habitaciones de Moteles';

  @override
  Future<Uint8List> build(InvoiceModel invoice) async {
    final theme = pw.ThemeData(
      defaultTextStyle: pw.TextStyle(
        font: pw.Font.helvetica(),
        fontBold: pw.Font.helveticaBold(),
        fontSize: _Pdf.bodyText,
      ),
    );
    final document = pw.Document(
      title: 'Factura ${invoice.invoiceNumber}',
      author: _pdfText(invoice.motelName),
      theme: theme,
    );
    final display = pw.Font.timesBold();
    final motelName = _pdfText(invoice.motelName);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          _Pdf.pageMargin,
          AppSpacing.s8,
          _Pdf.pageMargin,
          AppSpacing.s6,
        ),
        footer: (context) => _footer(context, motelName),
        build: (_) => [
          _header(invoice, display),
          pw.SizedBox(height: AppSpacing.s6),
          _parties(invoice, display),
          pw.SizedBox(height: AppSpacing.s4),
          _sectionTitle('Detalles de la reserva'),
          _reservationDetails(invoice),
          pw.SizedBox(height: AppSpacing.s4),
          _sectionTitle('Detalle de facturación'),
          _billingTable(invoice),
          _totals(invoice, display),
          if (invoice.payment != null) ...[
            pw.SizedBox(height: AppSpacing.s4),
            // Un Container no se parte entre páginas: el bloque queda junto.
            pw.Container(
              child: pw.Column(
                children: [
                  _sectionTitle('Datos de pago'),
                  _paymentDetails(
                    invoice.payment!,
                    methodName: invoice.paymentMethodName,
                  ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: AppSpacing.s4),
          _note(invoice, motelName),
        ],
      ),
    );

    return document.save();
  }

  @override
  Future<void> save(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);

  // ---------------------------------------------------------------------------
  // Bloques
  // ---------------------------------------------------------------------------

  pw.Widget _header(InvoiceModel invoice, pw.Font display) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: AppSpacing.s4),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: _Pdf.ink, width: _Pdf.ruleHeavy),
        bottom: pw.BorderSide(color: _Pdf.ink, width: _Pdf.ruleStrong),
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: _Pdf.logoSize,
          height: _Pdf.logoSize,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _Pdf.ink, width: _Pdf.ruleStrong),
          ),
          child: pw.Text(
            _brand.substring(0, 1),
            style: pw.TextStyle(
              font: display,
              fontSize: _Pdf.logoText,
              color: _Pdf.ink,
            ),
          ),
        ),
        pw.SizedBox(width: AppSpacing.s3),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _brand,
                style: pw.TextStyle(
                  font: display,
                  fontSize: _Pdf.brandText,
                  color: _Pdf.ink,
                  letterSpacing: 1,
                ),
              ),
              pw.Text(
                _brandTagline,
                style: pw.TextStyle(
                  fontSize: _Pdf.smallText,
                  color: _Pdf.accent,
                ),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'FACTURA',
              style: pw.TextStyle(
                font: display,
                fontSize: _Pdf.brandText,
                color: _Pdf.ink,
                letterSpacing: 2,
              ),
            ),
            pw.SizedBox(height: AppSpacing.s1),
            _labeledInline('N.°:', _pdfText(invoice.invoiceNumber)),
            pw.SizedBox(height: AppSpacing.s1),
            _labeledInline('Emitida:', formatDateTimeLabel(invoice.issuedAt)),
          ],
        ),
      ],
    ),
  );

  pw.Widget _parties(InvoiceModel invoice, pw.Font display) {
    final client = _pdfText(invoice.clientName ?? '');
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _Pdf.panel,
        border: pw.Border.all(color: _Pdf.line),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _partyCell(
              label: 'Establecimiento',
              children: [
                pw.Text(
                  _pdfText(invoice.motelName),
                  style: pw.TextStyle(
                    font: display,
                    fontSize: _Pdf.titleText,
                    color: _Pdf.ink,
                  ),
                ),
                pw.SizedBox(height: AppSpacing.s1),
                pw.Text(
                  'Reserva gestionada por Machuco',
                  style: pw.TextStyle(
                    fontSize: _Pdf.smallText,
                    color: _Pdf.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(width: _Pdf.ruleThin, height: 64, color: _Pdf.line),
          pw.Expanded(
            child: _partyCell(
              label: 'Cliente',
              children: [
                pw.Text(
                  client.isEmpty ? '-' : client,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: _Pdf.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _partyCell({
    required String label,
    required List<pw.Widget> children,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(AppSpacing.s4),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _eyebrow(label),
        pw.SizedBox(height: AppSpacing.s2),
        ...children,
      ],
    ),
  );

  pw.Widget _reservationDetails(InvoiceModel invoice) {
    final room = _pdfText('${invoice.roomName} (N.° ${invoice.roomNumber})');
    return pw.Table(
      border: pw.TableBorder.all(color: _Pdf.line),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2.4),
        2: pw.FlexColumnWidth(2.4),
        3: pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _Pdf.panel),
          children: [
            for (final header in [
              'Habitación',
              'Entrada',
              'Salida',
              'Huéspedes',
            ])
              _cell(_eyebrow(header)),
          ],
        ),
        pw.TableRow(
          children: [
            _cell(
              pw.Text(
                room,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: _Pdf.textPrimary,
                ),
              ),
            ),
            _cell(_body(formatDateTimeLabel(invoice.checkIn))),
            _cell(_body(formatDateTimeLabel(invoice.checkOut))),
            _cell(_body('${invoice.guestCount}')),
          ],
        ),
      ],
    );
  }

  pw.Widget _billingTable(InvoiceModel invoice) {
    final roomDetail = _pdfText(
      '${invoice.motelName} · ${invoice.roomName} (N.° ${invoice.roomNumber})',
    );
    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _Pdf.ink),
          children: [
            _cell(_headerText('Concepto')),
            _cell(_headerText('Cant.'), align: pw.Alignment.center),
            _cell(_headerText('Valor unit.'), align: pw.Alignment.centerRight),
            _cell(_headerText('Subtotal'), align: pw.Alignment.centerRight),
          ],
        ),
        _billingRow(
          concept: 'Habitación',
          detail: roomDetail,
          quantity: 1,
          unitPrice: invoice.roomTotal,
          subtotal: invoice.roomTotal,
        ),
        for (final item in invoice.items)
          _billingRow(
            concept: _pdfText(item.name),
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            subtotal: item.subtotal,
          ),
      ],
    );
  }

  pw.TableRow _billingRow({
    required String concept,
    String? detail,
    required int quantity,
    required int unitPrice,
    required int subtotal,
  }) => pw.TableRow(
    verticalAlignment: pw.TableCellVerticalAlignment.top,
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _Pdf.line)),
    ),
    children: [
      _cell(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              concept,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: _Pdf.ink,
              ),
            ),
            if (detail != null) ...[
              pw.SizedBox(height: AppSpacing.s1),
              pw.Text(
                detail,
                style: pw.TextStyle(
                  fontSize: _Pdf.smallText,
                  color: _Pdf.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
      _cell(_body('$quantity'), align: pw.Alignment.center),
      _cell(
        _body(formatCurrencyAmount(unitPrice)),
        align: pw.Alignment.centerRight,
      ),
      _cell(
        _body(formatCurrencyAmount(subtotal)),
        align: pw.Alignment.centerRight,
      ),
    ],
  );

  pw.Widget _totals(InvoiceModel invoice, pw.Font display) {
    final subtotal = invoice.items.fold<int>(
      invoice.roomTotal,
      (sum, item) => sum + item.subtotal,
    );
    return pw.Row(
      children: [
        pw.Spacer(),
        pw.SizedBox(
          width: _Pdf.totalsWidth,
          child: pw.Column(
            children: [
              pw.SizedBox(height: AppSpacing.s2),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s2,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Subtotal',
                      style: pw.TextStyle(color: _Pdf.textSecondary),
                    ),
                    _body(formatCurrencyAmount(subtotal)),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(AppSpacing.s3),
                decoration: pw.BoxDecoration(
                  color: _Pdf.panel,
                  border: pw.Border(
                    top: pw.BorderSide(color: _Pdf.ink, width: _Pdf.ruleStrong),
                    bottom: pw.BorderSide(
                      color: _Pdf.ink,
                      width: _Pdf.ruleStrong,
                    ),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: _Pdf.ink,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.Text(
                      formatCurrencyAmount(invoice.total),
                      style: pw.TextStyle(
                        font: display,
                        fontSize: _Pdf.titleText,
                        color: _Pdf.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _paymentDetails(InvoicePayment payment, {String? methodName}) {
    final rows = <(String, String)>[
      if (methodName != null) ('Método', _pdfText(methodName)),
      ('Concepto', _pdfText(payment.concept)),
      ('Importe', formatCurrencyAmount(payment.amount)),
      if (payment.cardHolder != null)
        ('Titular', _pdfText(payment.cardHolder!)),
      if (payment.cardLast4 != null)
        ('Tarjeta', '**** **** **** ${payment.cardLast4}'),
      if (payment.installments != null) ('Cuotas', '${payment.installments}'),
    ];
    // Dos columnas para que el bloque ocupe poco alto.
    final columnWidth =
        (PdfPageFormat.a4.width -
            2 * _Pdf.pageMargin -
            2 * AppSpacing.s4 -
            AppSpacing.s4) /
        2;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(AppSpacing.s4),
      decoration: pw.BoxDecoration(
        color: _Pdf.panel,
        border: pw.Border.all(color: _Pdf.line),
      ),
      child: pw.Wrap(
        spacing: AppSpacing.s4,
        runSpacing: AppSpacing.s2,
        children: [
          for (final (label, value) in rows)
            pw.SizedBox(
              width: columnWidth,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(width: _Pdf.labelWidth, child: _eyebrow(label)),
                  pw.Expanded(child: _body(value)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _note(InvoiceModel invoice, String motelName) => pw.Container(
    padding: const pw.EdgeInsets.all(AppSpacing.s4),
    decoration: pw.BoxDecoration(
      color: _Pdf.panel,
      border: pw.Border(
        left: pw.BorderSide(color: _Pdf.accent, width: _Pdf.ruleHeavy),
      ),
    ),
    child: pw.RichText(
      text: pw.TextSpan(
        style: pw.TextStyle(
          fontSize: _Pdf.smallText,
          color: _Pdf.textSecondary,
          lineSpacing: 2,
        ),
        children: [
          _strong('Comprobante de reserva: '),
          const pw.TextSpan(
            text: 'Este documento respalda la estadía reservada en ',
          ),
          _strong(motelName),
          const pw.TextSpan(text: ' a través de '),
          _strong('Machuco'),
          pw.TextSpan(
            text: ' bajo la referencia ${_pdfText(invoice.invoiceNumber)}.',
          ),
        ],
      ),
    ),
  );

  pw.Widget _footer(pw.Context context, String motelName) => pw.Container(
    margin: const pw.EdgeInsets.only(top: AppSpacing.s4),
    padding: const pw.EdgeInsets.only(top: AppSpacing.s2),
    decoration: pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _Pdf.line)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Machuco · $motelName', style: _mutedSmall),
        pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: _mutedSmall,
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------------------
  // Piezas reutilizables
  // ---------------------------------------------------------------------------

  pw.Widget _sectionTitle(String title) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: AppSpacing.s2),
    padding: const pw.EdgeInsets.only(bottom: AppSpacing.s1),
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _Pdf.line)),
    ),
    child: pw.Text(
      title.toUpperCase(),
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: _Pdf.ink,
        letterSpacing: 1,
      ),
    ),
  );

  pw.Widget _eyebrow(String text) => pw.Text(
    text.toUpperCase(),
    style: pw.TextStyle(
      fontSize: _Pdf.smallText,
      fontWeight: pw.FontWeight.bold,
      color: _Pdf.accent,
      letterSpacing: 1,
    ),
  );

  pw.Widget _headerText(String text) => pw.Text(
    text.toUpperCase(),
    style: pw.TextStyle(
      fontSize: _Pdf.smallText,
      fontWeight: pw.FontWeight.bold,
      color: _Pdf.onInk,
      letterSpacing: 1,
    ),
  );

  pw.Widget _body(String text) =>
      pw.Text(text, style: pw.TextStyle(color: _Pdf.textPrimary));

  pw.Widget _cell(
    pw.Widget child, {
    pw.Alignment align = pw.Alignment.centerLeft,
  }) => pw.Container(
    alignment: align,
    padding: const pw.EdgeInsets.symmetric(
      horizontal: AppSpacing.s3,
      vertical: AppSpacing.s2,
    ),
    child: child,
  );

  pw.Widget _labeledInline(String label, String value) => pw.RichText(
    text: pw.TextSpan(
      style: pw.TextStyle(fontSize: _Pdf.smallText, color: _Pdf.textSecondary),
      children: [
        _strong('$label '),
        pw.TextSpan(text: value),
      ],
    ),
  );

  pw.TextSpan _strong(String text) => pw.TextSpan(
    text: text,
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _Pdf.ink),
  );

  static final _mutedSmall = pw.TextStyle(
    fontSize: _Pdf.smallText,
    color: _Pdf.textMuted,
  );

  /// Las fuentes integradas del PDF solo cubren Latin-1. Los datos vienen de
  /// Firestore y pueden traer guiones largos, comillas tipográficas o emojis:
  /// se sustituyen por equivalentes y lo demás fuera de Latin-1 se omite,
  /// para que un nombre raro nunca impida generar la factura.
  static String _pdfText(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final replacement = switch (rune) {
        0x2013 || 0x2014 => '-',
        0x2018 || 0x2019 => "'",
        0x201C || 0x201D => '"',
        0x2022 => '·',
        0x2026 => '...',
        0x2192 => '->',
        _ => null,
      };
      if (replacement != null) {
        buffer.write(replacement);
      } else if (rune <= 0xFF) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().trim();
  }
}

/// Medidas y colores del PDF. Los colores salen de los tokens del sistema de
/// diseño (tema claro: la factura se imprime sobre papel blanco).
abstract final class _Pdf {
  static final ink = _token(AppLightColors.textPrimary);
  static final accent = _token(AppColors.violet);
  static final textPrimary = ink;
  static final textSecondary = _token(AppLightColors.textSecondary);
  static final textMuted = _token(AppLightColors.textMuted);
  static final panel = _token(AppLightColors.background);
  static final line = _token(AppLightColors.mediaFallback);
  static final onInk = _token(AppLightColors.surface);

  static PdfColor _token(Color color) => PdfColor.fromInt(color.toARGB32());

  static const pageMargin = AppSpacing.s8;
  static const logoSize = AppSpacing.s8 + AppSpacing.s2;
  static const totalsWidth = 230.0;
  static const labelWidth = 70.0;

  static const ruleThin = 1.0;
  static const ruleStrong = 2.0;
  static const ruleHeavy = 3.0;

  static const smallText = 8.0;
  static const bodyText = 10.0;
  static const titleText = 16.0;
  static const logoText = 20.0;
  static const brandText = 24.0;
}
