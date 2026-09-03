import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking_checkout_data.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/booking/booking_view_support.dart';
import 'package:machuco/widgets/booking/booking_widgets.dart';
import 'package:machuco/widgets/booking/payment_method_presentation.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

class PaymentConfirmationView extends StatelessWidget {
  const PaymentConfirmationView({
    super.key,
    required this.data,
    required this.paymentMethod,
    this.onDownloadInvoice,
  });

  final BookingCheckoutData data;
  final BookingPaymentMethod paymentMethod;
  final VoidCallback? onDownloadInvoice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmación de pago'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            maxWidth: 780,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s6),
                  decoration: BoxDecoration(
                    color: AppColors.available.withValues(alpha: .12),
                    border: Border.all(
                      color: AppColors.available.withValues(alpha: .65),
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.available,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 42,
                          color: Color(0xFF064E3B),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        '¡Reserva confirmada!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Tu pago fue registrado y enviamos el comprobante a tu correo.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s5),
                BookingSection(
                  title: 'Resumen de la transacción',
                  subtitle:
                      'La factura será gestionada por el módulo de facturación.',
                  child: Column(
                    children: [
                      PriceRow(
                        label: 'Total pagado',
                        value: formatBookingMoney(data.total),
                        emphasized: true,
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      PriceRow(
                        label: 'Método de pago',
                        value: paymentMethod.label,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s5),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final download = AppButton(
                      label: 'Descargar factura',
                      icon: Icons.download_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => _download(context),
                    );
                    final home = AppButton(
                      label: 'Volver al inicio',
                      icon: Icons.home_outlined,
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.clientHome,
                        (route) => false,
                      ),
                    );
                    if (constraints.maxWidth < 520) {
                      return Column(
                        children: [
                          download,
                          const SizedBox(height: AppSpacing.s3),
                          home,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: download),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(child: home),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _download(BuildContext context) {
    if (onDownloadInvoice != null) {
      onDownloadInvoice!();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La generación del PDF quedará conectada al servicio de facturación.',
        ),
      ),
    );
  }
}
