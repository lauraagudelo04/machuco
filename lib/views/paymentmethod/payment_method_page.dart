import 'package:flutter/material.dart';
import 'package:machuco/controllers/paymentmethod/payment_method_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/paymentmethod/payment_method_model.dart';

class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({
    super.key,
    this.amount = 120000,
    this.concept = 'Reserva Suite Deluxe - Motel Fantasía',
  });

  final int amount;
  final String concept;

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  late final PaymentMethodController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaymentMethodController(
      amount: widget.amount,
      concept: widget.concept,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final colors = context.appColors;
      return Scaffold(
        appBar: AppBar(title: const Text('Método de pago'), centerTitle: true),
        body: SafeArea(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(overscroll: false),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total a pagar',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                            const Chip(
                              avatar: Icon(Icons.shield_outlined, size: 15),
                              label: Text('Pago en línea'),
                            ),
                          ],
                        ),
                        Text(
                          _controller.formattedAmount,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _controller.concept,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  _CardPreview(controller: _controller),
                  const SizedBox(height: AppSpacing.s6),
                  Text(
                    'Detalles de la tarjeta',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  AppTextField(
                    label: 'Nombre del titular',
                    errorText: _controller.cardHolderError,
                    errorMaxLines: 2,
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(Icons.person_outline),
                    onChanged: _controller.updateCardHolder,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  AppTextField(
                    label: 'Número de tarjeta',
                    errorText: _controller.cardNumberError,
                    errorMaxLines: 2,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(Icons.credit_card_outlined),
                    onChanged: _controller.updateCardNumber,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Vencimiento',
                          hint: 'MM/YY',
                          errorText: _controller.expiryError,
                          errorMaxLines: 3,
                          keyboardType: TextInputType.datetime,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [_controller.expiryDateFormatter],
                          onChanged: _controller.updateExpiry,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: AppTextField(
                          label: 'CVV',
                          errorText: _controller.cvvError,
                          errorMaxLines: 3,
                          obscureText: _controller.isCvvHidden,
                          keyboardType: TextInputType.number,
                          onChanged: _controller.updateCvv,
                          suffixIcon: IconButton(
                            tooltip: _controller.isCvvHidden
                                ? 'Mostrar CVV'
                                : 'Ocultar CVV',
                            icon: Icon(
                              _controller.isCvvHidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: _controller.toggleCvvVisibility,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  DropdownButtonFormField<int>(
                    initialValue: _controller.installments,
                    decoration: const InputDecoration(labelText: 'Cuotas'),
                    items: List.generate(12, (index) => index + 1)
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value == 1 ? '1 cuota' : '$value cuotas',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _controller.changeInstallments,
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, color: AppColors.violet),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(
                          child: Text(
                            'Tus datos de pago están protegidos durante la transacción.',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_controller.message case final message?) ...[
                    const SizedBox(height: AppSpacing.s4),
                    _PaymentResult(
                      message: message,
                      approved:
                          _controller.status == PaymentProcessStatus.approved,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s5),
                  AppButton(
                    label: _controller.isApproved
                        ? 'Pago aprobado'
                        : 'Pagar ${_controller.formattedAmount}',
                    loading: _controller.isProcessing,
                    onPressed:
                        _controller.isProcessing || _controller.isApproved
                        ? null
                        : _controller.processPayment,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CardPreview extends StatelessWidget {
  const _CardPreview({required this.controller});

  final PaymentMethodController controller;

  @override
  Widget build(BuildContext context) => Container(
    height: 190,
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.s5),
    decoration: BoxDecoration(
      gradient: AppGradients.primary,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      boxShadow: AppShadows.cta,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.nfc, color: Colors.white, size: 32),
            Text(
              'TARJETA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Text(
          controller.cardPreviewNumber,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                controller.cardPreviewHolder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Text(
              controller.cardPreviewExpiry,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PaymentResult extends StatelessWidget {
  const _PaymentResult({required this.message, required this.approved});

  final String message;
  final bool approved;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        Icon(
          approved ? Icons.check_circle_outline : Icons.error_outline,
          color: approved ? AppColors.available : AppColors.rose,
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
