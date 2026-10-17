import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_catalog_entry.dart';
import 'package:machuco/repositories/payment/payment_repository.dart';
import 'package:machuco/views/payment/payment_view_support.dart';

class RegisterLocalPaymentSheet extends StatefulWidget {
  const RegisterLocalPaymentSheet({
    super.key,
    required this.payment,
    required this.loadPaymentMethods,
    required this.onSave,
  });

  final PaymentRecord payment;
  final Future<List<PaymentCatalogEntry>> Function() loadPaymentMethods;
  final Future<PaymentRecord> Function(int methodId) onSave;

  @override
  State<RegisterLocalPaymentSheet> createState() =>
      _RegisterLocalPaymentSheetState();
}

class _RegisterLocalPaymentSheetState extends State<RegisterLocalPaymentSheet> {
  List<PaymentCatalogEntry> _methods = [];
  int? _selectedMethodId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _methodsError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    setState(() {
      _isLoading = true;
      _methodsError = null;
    });
    try {
      final methods = await widget.loadPaymentMethods();
      if (!mounted) return;
      setState(() {
        _methods = methods;
        if (methods.isEmpty) {
          _methodsError = 'No hay métodos de pago disponibles.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _methodsError = error is PaymentRepositoryException
            ? error.message
            : 'No se pudieron cargar los métodos de pago. Inténtalo nuevamente.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    final methodId = _selectedMethodId;
    if (_isSaving || _isLoading || _methodsError != null || methodId == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final saved = await widget.onSave(methodId);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = error is PaymentRepositoryException
            ? error.message
            : 'No se pudo guardar el pago. Inténtalo nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    return PopScope(
      canPop: !_isSaving,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s5,
            AppSpacing.s5,
            AppSpacing.s5,
            AppSpacing.s5 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Registrar pago',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close),
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.client,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text('${payment.bookingReference} · ${payment.room}'),
                    const SizedBox(height: AppSpacing.s3),
                    Text(
                      formatPaymentMoney(payment.amount),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              const Text(
                'Confirma el pago solo después de haber recibido el dinero en el local.',
              ),
              const SizedBox(height: AppSpacing.s4),
              if (_isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: AppSpacing.s2),
                const Text('Cargando métodos de pago...'),
              ] else if (_methodsError case final error?)
                AppErrorState(message: error, onRetry: _loadMethods)
              else
                DropdownButtonFormField<int>(
                  initialValue: _selectedMethodId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago recibido',
                    hintText: 'Selecciona un método',
                  ),
                  items: _methods
                      .map(
                        (method) => DropdownMenuItem(
                          value: method.id,
                          child: Text(method.name),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() => _selectedMethodId = value);
                        },
                ),
              if (_saveError case final error?) ...[
                const SizedBox(height: AppSpacing.s3),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Se guardará un comprobante local. Esta acción no realiza un cobro bancario.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s5),
              // La altura puede crecer con la fuente accesible; AppButton
              // tiene altura fija y su etiqueta larga desborda al 200 %.
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.s12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s5,
                    vertical: AppSpacing.s3,
                  ),
                ),
                onPressed:
                    _isLoading ||
                        _methodsError != null ||
                        _selectedMethodId == null ||
                        _isSaving
                    ? null
                    : _submit,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSaving)
                      const SizedBox(
                        width: AppSpacing.s5,
                        height: AppSpacing.s5,
                        child: CircularProgressIndicator(),
                      )
                    else
                      const Icon(Icons.payments_outlined),
                    const SizedBox(width: AppSpacing.s2),
                    const Flexible(
                      child: Text(
                        'Confirmar pago',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.secondary,
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
