import 'package:flutter/material.dart';
import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/controllers/payment_method/payment_method_checkout_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/repositories/payment/payment_repository.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/views/payment_method/payment_method_page.dart';

Future<bool> _confirmWithClientController(String reservationId) async {
  final controller = ClientBookingController();
  try {
    return await controller.confirmPayment(reservationId);
  } finally {
    controller.dispose();
  }
}

class PaymentMethodSelectionPage extends StatefulWidget {
  const PaymentMethodSelectionPage({
    super.key,
    this.reservation,
    this.amount = 120000,
    this.concept = 'Reserva Suite Deluxe - Motel Fantasía',
    this.onContinue,
    this.checkoutController,
    this.confirmReservationPayment,
  });

  final Reservation? reservation;
  final int amount;
  final String concept;
  final ValueChanged<PaymentMethodModel>? onContinue;
  final PaymentCheckoutController? checkoutController;

  /// Confirms the payment of a reservation and reports success. Defaults to
  /// the client booking flow; injectable so the view builds no controller.
  final Future<bool> Function(String reservationId)? confirmReservationPayment;

  @override
  State<PaymentMethodSelectionPage> createState() =>
      _PaymentMethodSelectionPageState();
}

class _PaymentMethodSelectionPageState
    extends State<PaymentMethodSelectionPage> {
  bool _isCashSelected = false;
  bool _isRegistering = false;

  /// Set once the reservation was confirmed, so retrying a failed payment
  /// registration does not confirm it again (it is no longer pending).
  bool _reservationConfirmed = false;

  // Perezoso: crear el controlador toca Firebase y SQLite, que no deben
  // inicializarse mientras el usuario solo está eligiendo.
  late final PaymentCheckoutController _checkout =
      widget.checkoutController ?? PaymentCheckoutController();

  Reservation? get _reservation => widget.reservation;

  int get _effectiveAmount => _reservation?.total ?? widget.amount;

  String get _effectiveConcept => _reservation != null
      ? 'Reserva ${_reservation!.roomName} - ${_reservation!.motelName}'
      : widget.concept;

  String get _formattedAmount =>
      '${formatCurrencyAmount(_effectiveAmount)} COP';

  void _selectCash() {
    setState(() => _isCashSelected = true);
  }

  void _goToInvoice([PaymentMethodModel? paymentMethod]) {
    final reservation = _reservation;
    if (reservation == null) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.clientMotels, (_) => false);
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.invoice,
      (_) => false,
      arguments: {
        'reservation': reservation,
        'paymentMethod':
            paymentMethod ??
            PaymentMethodModel(
              amount: _effectiveAmount,
              concept: _effectiveConcept,
            ),
      },
    );
  }

  void _openCardPayment() {
    setState(() => _isCashSelected = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentMethodPage(
          amount: _effectiveAmount,
          concept: _effectiveConcept,
          reservation: _reservation,
          onContinue: _continueAfterCard,
        ),
      ),
    );
  }

  Future<void> _continueAfterCard(PaymentMethodModel model) async {
    final reservation = _reservation;
    if (reservation != null) {
      // The real checkout rejects the sandbox before Booking can mark a
      // reservation paid. Tests may inject an actual payment implementation.
      final registered = await _registerPayment(
        () => _checkout.registerCardPayment(reservation, kind: model.cardKind),
      );
      if (!registered) return;
      if (!_reservationConfirmed) {
        if (!await _confirmReservation(reservation)) return;
        _reservationConfirmed = true;
      }
    }
    if (!mounted) return;
    (widget.onContinue ?? _goToInvoice)(model);
  }

  /// Card payment succeeded: confirms the reservation (pending -> upcoming or
  /// active) before registering the payment. If the reservation can no longer
  /// be paid (for example, its 15 minutes expired) the user is told and leaves.
  Future<bool> _confirmReservation(Reservation reservation) async {
    final confirmed =
        await (widget.confirmReservationPayment ??
            _confirmWithClientController)(reservation.id);
    if (!mounted) return false;
    if (!confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos confirmar el pago: la reserva ya no está pendiente '
            'de pago.',
          ),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    return confirmed;
  }

  Future<void> _finishCashPayment() async {
    final reservation = _reservation;
    if (reservation != null) {
      final registered = await _registerPayment(
        () => _checkout.registerPendingLocalPayment(reservation),
      );
      if (!registered) return;
    }
    if (!mounted) return;
    // Choosing where to pay is not a receipt or an invoice for money received.
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.clientReservations, (_) => false);
  }

  Future<bool> _registerPayment(
    Future<PaymentCheckoutResult> Function() register,
  ) async {
    if (_isRegistering) return false;
    setState(() => _isRegistering = true);
    String? notice;
    var registered = false;
    try {
      notice = (await register()).syncWarning;
      registered = true;
    } on PaymentRepositoryException catch (error) {
      notice = error.message;
    } catch (_) {
      notice = 'No se pudo registrar el pago. Inténtalo nuevamente.';
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
    if (notice != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(notice)));
    }
    return registered;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Método de pago'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total de la reserva',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      _formattedAmount,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      _effectiveConcept,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              Text(
                '¿Cómo deseas pagar?',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                'Selecciona el método de pago para tu reserva.',
                style: TextStyle(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s4),
              _PaymentOptionCard(
                icon: Icons.payments_outlined,
                title: 'En el Local',
                description: 'Paga el valor total en la recepción.',
                selected: _isCashSelected,
                onTap: _selectCash,
              ),
              const SizedBox(height: AppSpacing.s3),
              _PaymentOptionCard(
                icon: Icons.credit_card_outlined,
                title: 'Tarjeta',
                description: 'Simulación; no realiza cobros bancarios.',
                selected: false,
                onTap: _openCardPayment,
              ),
              if (_isCashSelected) ...[
                const SizedBox(height: AppSpacing.s5),
                _CashPaymentNotice(formattedAmount: _formattedAmount),
                const SizedBox(height: AppSpacing.s5),
                AppButton(
                  label: 'Finalizar',
                  loading: _isRegistering,
                  onPressed: _isRegistering ? null : _finishCashPayment,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CashPaymentNotice extends StatelessWidget {
  const _CashPaymentNotice({required this.formattedAmount});

  final String formattedAmount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.violet,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pago en recepción',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'Paga cuando llegues al establecimiento.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.elevated,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL A PAGAR EN RECEPCIÓN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  formattedAmount,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Divider(height: 1, color: colors.borderStrong),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Muchas gracias por usar nuestros servicios. Estaremos listos '
            'para recibirte.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  const _PaymentOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      onTap: onTap,
      selected: selected,
      semanticLabel: '$title. $description',
      child: Row(
        children: [
          Icon(icon, color: AppColors.violet, size: 28),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Icon(
            selected ? Icons.check_circle : Icons.chevron_right,
            color: selected ? AppColors.violet : colors.textSecondary,
          ),
        ],
      ),
    );
  }
}
