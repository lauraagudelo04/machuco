import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/controllers/invoice/InvoiceController.dart';

class InvoicePage extends StatelessWidget {
  final InvoiceController controller;

  const InvoicePage({
    super.key,
    this.controller = const InvoiceController(),
  });

  @override
  Widget build(BuildContext context) {
    final data = controller.invoiceData;

    return Scaffold(
      backgroundColor: AppLightColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.s6),

              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.available,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: AppSpacing.s4),

              Text(
                '¡TRANSFERENCIA EXITOSA!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppLightColors.textPrimary,
                    ),
              ),

              const SizedBox(height: AppSpacing.s1),

              Text(
                data.dateTime,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppLightColors.textMuted,
                    ),
              ),

              const SizedBox(height: AppSpacing.s6),

              Container(
                padding: const EdgeInsets.all(AppSpacing.s5),
                decoration: BoxDecoration(
                  color: AppLightColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppLightColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    _ReceiptRow(
                      label: 'Comercio:',
                      value: data.commerce,
                    ),
                    _ReceiptRow(
                      label: 'Valor:',
                      value: data.amount,
                      isHighlight: true,
                    ),
                    _ReceiptRow(
                      label: 'No. Transferencia:',
                      value: data.transferNumber,
                    ),
                    _ReceiptRow(
                      label: 'Fecha y hora reserva:',
                      value: data.dateTime,
                    ),
                    _ReceiptRow(
                      label: 'No. Reserva:',
                      value: data.reservationNumber,
                    ),
                    _ReceiptRow(
                      label: 'Titular:',
                      value: data.ownerName,
                    ),
                    _ReceiptRow(
                      label: 'Documento:',
                      value: data.document,
                    ),
                    _ReceiptRow(
                      label: 'Descripción pago:',
                      value: data.description,
                    ),
                    _ReceiptRow(
                      label: 'Inicio:',
                      value: data.startDate,
                    ),
                    _ReceiptRow(
                      label: 'Fin:',
                      value: data.endDate,
                      showBorder: false,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s8),

              AppButton(
                label: 'Descargar',
                icon: Icons.file_download_outlined,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.large,
                onPressed: () async {
                  final success = await controller.downloadReceipt();

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Comprobante descargado correctamente.'
                            : 'No se pudo descargar el comprobante.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.showBorder = true,
  });

  final String label;
  final String value;
  final bool isHighlight;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.s3,
      ),
      decoration: showBorder
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppLightColors.border,
                ),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: AppLightColors.textSecondary,
                  ),
            ),
          ),

          const SizedBox(width: AppSpacing.s2),

          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isHighlight
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isHighlight
                        ? AppColors.violet
                        : AppLightColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}