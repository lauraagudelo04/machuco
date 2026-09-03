import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking_checkout_data.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/widgets/booking/booking_widgets.dart';
import 'package:machuco/widgets/booking/payment_method_presentation.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

class PaymentMethodView extends StatefulWidget {
  const PaymentMethodView({super.key, required this.data, this.onConfirm});

  final BookingCheckoutData data;
  final void Function(BookingCheckoutData data, BookingPaymentMethod method)?
  onConfirm;

  @override
  State<PaymentMethodView> createState() => _PaymentMethodViewState();
}

class _PaymentMethodViewState extends State<PaymentMethodView> {
  BookingPaymentMethod? _selected;
  bool _accepted = false;
  bool _attempted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Método de pago')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            child: ResponsiveSplit(
              primary: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '¿Cómo quieres pagar?',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'Selecciona una opción segura disponible en Colombia.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  for (final method in BookingPaymentMethod.values) ...[
                    _PaymentMethodCard(
                      method: method,
                      selected: _selected == method,
                      onTap: () => setState(() => _selected = method),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                  ],
                  if (_attempted && _selected == null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s1),
                      child: Text(
                        'Selecciona un método de pago.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.s4),
                  BookingSection(
                    title: 'Autorizaciones',
                    subtitle:
                        'Tu información será tratada según la normativa colombiana de protección de datos.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _accepted,
                          onChanged: (value) =>
                              setState(() => _accepted = value ?? false),
                          title: const Text(
                            'Acepto los Términos y Condiciones y autorizo el tratamiento de mis datos personales (Habeas Data).',
                          ),
                        ),
                        Wrap(
                          spacing: AppSpacing.s2,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  _showLegal('Términos y Condiciones'),
                              child: const Text('Ver términos'),
                            ),
                            TextButton(
                              onPressed: () => _showLegal(
                                'Política de tratamiento de datos',
                              ),
                              child: const Text('Ver política de datos'),
                            ),
                          ],
                        ),
                        if (_attempted && !_accepted)
                          Text(
                            'Debes aceptar las autorizaciones para continuar.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              secondary: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PriceBreakdownCard(
                    data: widget.data,
                    title: 'Total de la transacción',
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  AppButton(
                    label: 'Confirmar y pagar',
                    icon: Icons.lock_outline,
                    onPressed: _confirm,
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: context.appColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.s1),
                      Flexible(
                        child: Text(
                          'Pago protegido y cifrado',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.appColors.textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirm() {
    setState(() => _attempted = true);
    if (_selected == null || !_accepted) return;
    if (widget.onConfirm != null) {
      widget.onConfirm!(widget.data, _selected!);
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.paymentConfirmation,
      arguments: (widget.data, _selected!),
    );
  }

  Future<void> _showLegal(String title) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: const SingleChildScrollView(
        child: Text(
          'Texto demostrativo. La versión legal vigente deberá ser suministrada por el responsable del tratamiento antes de la integración productiva.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.method,
    required this.selected,
    required this.onTap,
  });
  final BookingPaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    selected: selected,
    onTap: onTap,
    semanticLabel: 'Pagar con ${method.label}',
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.appColors.elevated,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            method.icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(method.label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.s1),
              Text(
                method.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : context.appColors.textSecondary,
          semanticLabel: selected ? 'Seleccionado' : 'No seleccionado',
        ),
      ],
    ),
  );
}
