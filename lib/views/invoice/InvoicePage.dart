import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';

class PaymentReceiptScreen extends StatelessWidget {
  // 1. Declaramos las variables que va a recibir la vista
  final String commerce;
  final String amount;
  final String transferNumber;
  final String dateTime;
  final String reservationNumber;
  final String ownerName;
  final String document;
  final String description;
  final String startDate;
  final String endDate;

  // 2. Las pedimos en el constructor de la clase
  const PaymentReceiptScreen({
    super.key,
    required this.commerce,
    required this.amount,
    required this.transferNumber,
    required this.dateTime,
    required this.reservationNumber,
    required this.ownerName,
    required this.document,
    required this.description,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppLightColors.background,


      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.s3),
              
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
              // Usamos la variable dateTime para el encabezado
              Text(
                dateTime,
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
                  border: Border.all(color: AppLightColors.border),
                ),
                child: Column( // Quitamos el 'const' de este Column porque ahora tiene variables dinámicas
                  children: [
                    // 3. Pasamos las variables a cada fila
                    _ReceiptRow(label: 'Comercio:', value: commerce),
                    _ReceiptRow(label: 'Valor:', value: amount, isHighlight: true),
                    _ReceiptRow(label: 'No. Transferencia:', value: transferNumber),
                    _ReceiptRow(label: 'Fecha y hora reserva:', value: dateTime),
                    _ReceiptRow(label: 'No. Reserva:', value: reservationNumber),
                    _ReceiptRow(label: 'Titular:', value: ownerName),
                    _ReceiptRow(label: 'Documento:', value: document),
                    _ReceiptRow(label: 'Descripción pago:', value: description),
                    _ReceiptRow(label: 'Inicio:', value: startDate),
                    _ReceiptRow(label: 'Fin:', value: endDate, showBorder: false),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s8),

              AppButton(
                label: 'Descargar',
                icon: Icons.file_download_outlined,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.large,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// El componente _ReceiptRow se mantiene exactamente igual
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      decoration: showBorder
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppLightColors.border)),
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
                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                    color: isHighlight ? AppColors.violet : AppLightColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}