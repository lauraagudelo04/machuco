import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

class AddPaymentSheet extends StatefulWidget {
  const AddPaymentSheet({
    super.key,
    required this.defaultAmount,
    required this.onSave,
  });

  final int defaultAmount;
  final void Function({
    required int amount,
    required String paymentMethod,
    required String reference,
  })
  onSave;

  @override
  State<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _referenceController = TextEditingController();
  String _selectedMethod = 'Transferencia Bancaria';

  static const List<String> _paymentMethods = [
    'Transferencia Bancaria',
    'Tarjeta de Crédito',
    'PSE / Nequi / Daviplata',
    'Efectivo / Corresponsal',
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.defaultAmount.toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cleaned = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.parse(cleaned);
    final reference = _referenceController.text.trim();

    widget.onSave(
      amount: amount,
      paymentMethod: _selectedMethod,
      reference: reference,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.s5,
        right: AppSpacing.s5,
        top: AppSpacing.s5,
        bottom: AppSpacing.s5 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Registrar Pago', style: AppTextStyles.h2),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),

              // Amount field
              AppTextField(
                label: 'Monto a pagar',
                controller: _amountController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.attach_money_rounded),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un monto';
                  }
                  final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
                  final parsed = int.tryParse(cleaned);
                  if (parsed == null || parsed <= 0) {
                    return 'Ingresa un monto válido mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.s3),

              // Payment method selector
              Text(
                'Método de pago',
                style: AppTextStyles.caption.copyWith(
                  color: semantic.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: semantic.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMethod,
                    isExpanded: true,
                    items: _paymentMethods
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(m, style: AppTextStyles.body),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedMethod = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s3),

              // Reference field
              AppTextField(
                label: 'Número de comprobante / Referencia',
                controller: _referenceController,
                hint: 'Ej: TRANS-123456',
                prefixIcon: const Icon(Icons.receipt_long_outlined),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa el número de referencia';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.s5),

              // Submit Button
              AppButton(
                label: 'Confirmar pago',
                icon: Icons.check_circle_outline,
                onPressed: _handleSubmit,
              ),
              const SizedBox(height: AppSpacing.s2),
            ],
          ),
        ),
      ),
    );
  }
}
