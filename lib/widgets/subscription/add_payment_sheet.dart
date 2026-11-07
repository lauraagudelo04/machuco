import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/model/suscripcion/subscription.dart';
import 'package:machuco/database/repository/suscripcion/subscription_repository.dart';

class AddPaymentSheet extends StatefulWidget {
  const AddPaymentSheet({
    super.key,
    required this.defaultAmount,
    required this.loadPaymentMethods,
    required this.onSave,
  });

  final int defaultAmount;
  final Future<List<SubscriptionPaymentMethod>> Function() loadPaymentMethods;
  final Future<void> Function({
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
  SubscriptionPaymentMethod? _selectedMethod;
  List<SubscriptionPaymentMethod> _paymentMethods = [];
  bool _isLoadingMethods = true;
  String? _methodsError;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.defaultAmount.toString(),
    );
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    setState(() {
      _isLoadingMethods = true;
      _methodsError = null;
    });
    try {
      final methods = await widget.loadPaymentMethods();
      if (!mounted) return;
      setState(() {
        _paymentMethods = methods;
        _selectedMethod = methods.isEmpty ? null : methods.first;
        if (methods.isEmpty) {
          _methodsError = 'No hay métodos de pago disponibles.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _methodsError = error is SubscriptionRepositoryException
            ? error.message
            : 'No se pudieron cargar los métodos de pago.';
      });
    } finally {
      if (mounted) setState(() => _isLoadingMethods = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSaving ||
        _isLoadingMethods ||
        _selectedMethod == null ||
        _methodsError != null)
      return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cleaned = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.parse(cleaned);
    final reference = _referenceController.text.trim();

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(
        amount: amount,
        paymentMethod: _selectedMethod!.name,
        reference: reference,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'No se pudo guardar el pago. Intenta nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_isSaving,
      child: Container(
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
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: semantic.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SubscriptionPaymentMethod>(
                      value: _selectedMethod,
                      hint: Text(
                        _isLoadingMethods
                            ? 'Cargando métodos de pago...'
                            : 'Selecciona un método de pago',
                      ),
                      isExpanded: true,
                      items: _paymentMethods
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.name, style: AppTextStyles.body),
                            ),
                          )
                          .toList(),
                      onChanged:
                          _isSaving ||
                              _isLoadingMethods ||
                              _methodsError != null
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _selectedMethod = val);
                              }
                            },
                    ),
                  ),
                ),
                if (_isLoadingMethods) const LinearProgressIndicator(),
                if (_methodsError != null) ...[
                  Text(
                    _methodsError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _loadMethods,
                    child: const Text('Reintentar'),
                  ),
                ],
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
                if (_saveError != null) ...[
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                ],
                AppButton(
                  label: 'Confirmar pago',
                  icon: Icons.check_circle_outline,
                  onPressed:
                      _isLoadingMethods ||
                          _methodsError != null ||
                          _selectedMethod == null
                      ? null
                      : _handleSubmit,
                  loading: _isSaving,
                ),
                const SizedBox(height: AppSpacing.s2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
