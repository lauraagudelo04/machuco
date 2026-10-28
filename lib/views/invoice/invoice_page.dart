import 'package:flutter/material.dart';
import 'package:machuco/controllers/invoice/invoice_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/invoice/invoice_model.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/utils/date_formatter.dart';

/// Muestra la factura de una reserva tal como está guardada en Supabase.
class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key, required this.reservation, this.paymentMethod});

  final Reservation reservation;
  final PaymentMethodModel? paymentMethod;

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final _controller = InvoiceController();
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.loadPreferences();
    _load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() => _controller.loadForReservation(
    widget.reservation,
    paymentMethod: widget.paymentMethod,
  );

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    final success = await _controller.downloadCurrent();
    if (!mounted) return;
    setState(() => _isDownloading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Factura descargada.' : 'No se pudo descargar la factura.',
        ),
      ),
    );
  }

  String _paymentValue(String? value) {
    return value == null || value.trim().isEmpty ? '—' : value;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('Factura'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return;
            }

            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.clientMotels, (_) => false);
          },
        ),
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final invoice = _controller.invoice;
    return switch (_controller.status) {
      InvoiceLoadStatus.initial || InvoiceLoadStatus.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      InvoiceLoadStatus.pending => const AppEmptyState(
        icon: Icons.hourglass_empty_rounded,
        title: 'Factura pendiente',
        message:
            'El pago en efectivo aún no se ha facturado. Vuelve a consultar más tarde.',
      ),
      InvoiceLoadStatus.notAvailable => const AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Sin factura',
        message: 'Esta reserva no tiene una factura disponible.',
      ),
      InvoiceLoadStatus.error => AppErrorState(
        message: _controller.errorMessage ?? 'No se pudo cargar la factura.',
        onRetry: _load,
      ),
      InvoiceLoadStatus.available when invoice != null => _buildInvoice(
        context,
        invoice,
      ),
      InvoiceLoadStatus.available => const SizedBox.shrink(),
    };
  }

  Widget _buildInvoice(BuildContext context, InvoiceModel invoice) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final amountLabel = formatCurrencyAmount(invoice.total);
    final payment = invoice.payment;
    final isDownloaded = _controller.isDownloaded(invoice.reservationId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.s2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.cta,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      color: Colors.white,
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: Text(
                        'Factura ${invoice.invoiceNumber}',
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  'Reserva ${invoice.reservationId} · '
                  'Emitida ${formatDateTimeLabel(invoice.issuedAt)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  amountLabel,
                  style: textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen de la reserva',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                _DetailRow(label: 'Motel', value: invoice.motelName),
                _DetailRow(
                  label: 'Habitación',
                  value: '${invoice.roomName} · ${invoice.roomNumber}',
                ),
                _DetailRow(
                  label: 'Fechas',
                  value: formatDateRangeLabel(
                    invoice.checkIn,
                    invoice.checkOut,
                  ),
                ),
                _DetailRow(label: 'Personas', value: '${invoice.guestCount}'),
                _DetailRow(label: 'Total', value: amountLabel),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Servicios y productos',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                if (invoice.items.isEmpty)
                  Text(
                    'Sin servicios ni productos adicionales.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  )
                else
                  for (final item in invoice.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.quantity > 1
                                  ? '${item.name} x${item.quantity}'
                                  : item.name,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            formatCurrencyAmount(item.subtotal),
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                const Divider(height: AppSpacing.s5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Subtotal habitación',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Text(formatCurrencyAmount(invoice.roomTotal)),
                  ],
                ),
                const SizedBox(height: AppSpacing.s2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      amountLabel,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Datos de pago',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                _DetailRow(
                  label: 'Concepto',
                  value: _paymentValue(payment?.concept),
                ),
                _DetailRow(
                  label: 'Importe',
                  value: _paymentValue(
                    payment == null
                        ? null
                        : formatCurrencyAmount(payment.amount),
                  ),
                ),
                _DetailRow(
                  label: 'Titular',
                  value: _paymentValue(payment?.cardHolder),
                ),
                _DetailRow(
                  label: 'Tarjeta',
                  value: _paymentValue(
                    payment?.cardLast4 == null
                        ? null
                        : '**** **** **** ${payment!.cardLast4}',
                  ),
                ),
                _DetailRow(
                  label: 'Cuotas',
                  value: _paymentValue(payment?.installments?.toString()),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          if (isDownloaded) ...[
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: colors.textSecondary),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    _controller.lastDownloadedAt == null
                        ? 'Ya descargaste esta factura.'
                        : 'Ya descargaste esta factura. Última descarga: '
                              '${formatDateTimeLabel(_controller.lastDownloadedAt!)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
          AppButton(
            label: isDownloaded ? 'Descargar de nuevo' : 'Descargar factura',
            icon: Icons.download_outlined,
            loading: _isDownloading,
            onPressed: _download,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
