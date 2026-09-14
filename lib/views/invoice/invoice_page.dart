import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/utils/date_formatter.dart';

class InvoicePage extends StatelessWidget {
  const InvoicePage({
    super.key,
    required this.reservation,
    this.paymentMethod,
  });

  final Reservation reservation;
  final PaymentMethodModel? paymentMethod;

  String _maskedCard(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return '**** **** **** ****';
    }

    final visible = digits.length > 4
        ? digits.substring(digits.length - 4)
        : digits;

    return '**** **** **** $visible';
  }

  String _paymentValue(String? value) {
    return value == null || value.trim().isEmpty ? '—' : value;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final amountLabel = formatCurrencyAmount(reservation.total);

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

            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.clientMotels,
              (_) => false,
            );
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                            'Factura',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Text(
                      'Reserva ${reservation.id}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: Colors.white.withValues(
                              alpha: 0.85,
                            ),
                          ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      amountLabel,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
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
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    _DetailRow(
                      label: 'Motel',
                      value: reservation.motelName,
                    ),
                    _DetailRow(
                      label: 'Habitación',
                      value:
                          '${reservation.roomName} · ${reservation.roomNumber}',
                    ),
                    _DetailRow(
                      label: 'Fechas',
                      value: formatDateRangeLabel(
                        reservation.checkIn,
                        reservation.checkOut,
                      ),
                    ),
                    _DetailRow(
                      label: 'Personas',
                      value: '${reservation.guestCount}',
                    ),
                    _DetailRow(
                      label: 'Total',
                      value: amountLabel,
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
                      'Servicios y productos',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    if (reservation.services.isEmpty &&
                        reservation.products.isEmpty)
                      Text(
                        'Sin servicios ni productos adicionales.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: colors.textSecondary,
                            ),
                      )
                    else ...[
                      for (final item in [
                        ...reservation.services,
                        ...reservation.products,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.s2,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium,
                                ),
                              ),
                              Text(
                                formatCurrencyAmount(
                                  item.subtotal,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const Divider(
                      height: AppSpacing.s5,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Subtotal habitación',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      colors.textSecondary,
                                ),
                          ),
                        ),
                        Text(
                          formatCurrencyAmount(
                            reservation.roomTotal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                          ),
                        ),
                        Text(
                          amountLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.w700,
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos de pago',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    if (paymentMethod == null) ...[
                      _DetailRow(
                        label: 'Concepto',
                        value: _paymentValue(null),
                      ),
                      _DetailRow(
                        label: 'Importe',
                        value: _paymentValue(null),
                      ),
                      _DetailRow(
                        label: 'Titular',
                        value: _paymentValue(null),
                      ),
                      _DetailRow(
                        label: 'Tarjeta',
                        value: _paymentValue(null),
                      ),
                      _DetailRow(
                        label: 'Vencimiento',
                        value: _paymentValue(null),
                      ),
                      _DetailRow(
                        label: 'Cuotas',
                        value: _paymentValue(null),
                      ),
                    ] else ...[
                      _DetailRow(
                        label: 'Concepto',
                        value: _paymentValue(
                          paymentMethod!.concept,
                        ),
                      ),
                      _DetailRow(
                        label: 'Importe',
                        value: _paymentValue(
                          formatCurrencyAmount(
                            paymentMethod!.amount,
                          ),
                        ),
                      ),
                      _DetailRow(
                        label: 'Titular',
                        value: _paymentValue(
                          paymentMethod!.cardHolder,
                        ),
                      ),
                      _DetailRow(
                        label: 'Tarjeta',
                        value: _paymentValue(
                          _maskedCard(
                            paymentMethod!.cardNumber,
                          ),
                        ),
                      ),
                      _DetailRow(
                        label: 'Vencimiento',
                        value: _paymentValue(
                          paymentMethod!.expiry,
                        ),
                      ),
                      _DetailRow(
                        label: 'Cuotas',
                        value: _paymentValue(
                          paymentMethod!.installments
                              .toString(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s5),
              AppButton(
                label: 'Descargar factura',
                icon: Icons.download_outlined,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Descarga de factura.',
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.s2,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}