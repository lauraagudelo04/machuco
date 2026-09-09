import 'dart:async';

import 'package:flutter/material.dart';

import 'package:machuco/controllers/additional_service/client_view/additional_service_client_controller.dart';
import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/controllers/product/product_controller.dart';
import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_feedback.dart';
import 'package:machuco/core/design_system/components/app_icon_button.dart';
import 'package:machuco/core/design_system/components/app_skeleton.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/product/product.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/room/room_view_models.dart';
import 'package:machuco/widgets/booking/availability_calendar.dart';
import 'package:machuco/widgets/booking/priced_checkbox_tile.dart';
import 'package:machuco/widgets/booking/quantity_stepper.dart';

/// Formulario de reserva. Una sola pantalla con scroll (sin stepper),
/// alcanzable desde el detalle de habitación pulsando "Reservar".
class CreateBookingPage extends StatefulWidget {
  const CreateBookingPage({super.key, required this.room});

  final RoomVisualData room;

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  late final ClientBookingController _bookingController;
  late final AdditionalServiceClientController _servicesController;
  late final ProductController _productsController;
  late final String _requestId;
  late final List<BlockedRange> _externalBlocked;

  StayMode _stayMode = StayMode.dateWithHourBlock;
  DateTime? _selectedDay;
  TimeOfDay? _checkInTime;
  TimeOfDay? _checkOutTime;
  int _hourBlock = 2;
  int _guestCount = 1;
  final Set<String> _selectedServiceIds = {};
  final Set<String> _selectedProductIds = {};
  bool _isSubmitting = false;
  bool _simulateNetworkFailureNextAttempt = false;
  bool _simulateConflictNextAttempt = false;

  @override
  void initState() {
    super.initState();
    _bookingController = ClientBookingController();
    _servicesController = AdditionalServiceClientController();
    _productsController = ProductController();
    _requestId = 'booking-request-${DateTime.now().microsecondsSinceEpoch}';
    _externalBlocked = widget.room.reservations
        .map((r) => BlockedRange(r.startDateTime, r.endDateTime))
        .toList();
    _servicesController.addListener(_refresh);
    unawaited(_servicesController.loadServicesByUserId());
  }

  @override
  void dispose() {
    _servicesController.removeListener(_refresh);
    _servicesController.dispose();
    _productsController.dispose();
    _bookingController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  DateTime? get _checkIn {
    if (_selectedDay == null || _checkInTime == null) return null;
    return DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
      _checkInTime!.hour,
      _checkInTime!.minute,
    );
  }

  DateTime? get _checkOut {
    final checkIn = _checkIn;
    if (checkIn == null) return null;
    if (_stayMode == StayMode.dateWithHourBlock) {
      return checkIn.add(Duration(hours: _hourBlock));
    }
    if (_checkOutTime == null) return null;
    var checkOut = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
      _checkOutTime!.hour,
      _checkOutTime!.minute,
    );
    if (!checkOut.isAfter(checkIn)) {
      // La salida es antes que la hora de entrada: se asume que corresponde
      // al día siguiente (estancia nocturna).
      checkOut = checkOut.add(const Duration(days: 1));
    }
    return checkOut;
  }

  String? get _rangeError {
    final checkIn = _checkIn;
    final checkOut = _checkOut;
    if (checkIn == null || checkOut == null) return null;
    if (checkIn.isBefore(DateTime.now())) {
      return 'La hora de entrada debe ser posterior al momento actual.';
    }
    if (_stayMode == StayMode.dateTimeRange &&
        checkOut.difference(checkIn) > const Duration(hours: 24)) {
      return 'La estancia no puede superar 24 horas continuas.';
    }
    if (!_bookingController.isSlotAvailable(
      widget.room.id,
      checkIn,
      checkOut,
      externalBlocked: _externalBlocked,
    )) {
      return _bookingController.explainBlockedSlot(
        widget.room.id,
        checkIn,
        checkOut,
        externalBlocked: _externalBlocked,
      );
    }
    return null;
  }

  bool get _hasCompleteSchedule {
    if (_selectedDay == null || _checkInTime == null) return false;
    if (_stayMode == StayMode.dateTimeRange && _checkOutTime == null) {
      return false;
    }
    return true;
  }

  bool get _isGuestCountValid =>
      _guestCount >= 1 && _guestCount <= widget.room.capacity;

  bool get _isFormValid =>
      _hasCompleteSchedule && _rangeError == null && _isGuestCountValid;

  List<AdditionalService> get _availableServices => _servicesController
      .activeServices
      .where((service) => service.motelId == widget.room.motelId)
      .toList();

  List<Product> get _availableProducts => _productsController
      .getProductsByMotel(widget.room.motelId)
      .where((product) => product.isActive)
      .toList();

  int get _hoursForTotal {
    final checkIn = _checkIn;
    final checkOut = _checkOut;
    if (checkIn == null || checkOut == null) return 0;
    final minutes = checkOut.difference(checkIn).inMinutes;
    return (minutes / 60).ceil();
  }

  int get _roomTotal => widget.room.pricePerHour * _hoursForTotal;

  List<ReservationLineItem> get _selectedServiceItems => _availableServices
      .where((service) => _selectedServiceIds.contains(service.id))
      .map(
        (service) => ReservationLineItem(
          id: service.id,
          name: service.name,
          unitPrice: service.price,
        ),
      )
      .toList();

  List<ReservationLineItem> get _selectedProductItems => _availableProducts
      .where((product) => _selectedProductIds.contains(product.id))
      .map(
        (product) => ReservationLineItem(
          id: product.id,
          name: product.name,
          unitPrice: product.price.round(),
        ),
      )
      .toList();

  int get _servicesTotal =>
      _selectedServiceItems.fold(0, (sum, item) => sum + item.subtotal);

  int get _productsTotal =>
      _selectedProductItems.fold(0, (sum, item) => sum + item.subtotal);

  int get _grandTotal => _roomTotal + _servicesTotal + _productsTotal;

  Future<void> _pickCheckInTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkInTime ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (picked != null) setState(() => _checkInTime = picked);
  }

  Future<void> _pickCheckOutTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkOutTime ?? const TimeOfDay(hour: 23, minute: 0),
    );
    if (picked != null) setState(() => _checkOutTime = picked);
  }

  Future<void> _submit() async {
    if (!_isFormValid || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    final checkIn = _checkIn!;
    final checkOut = _checkOut!;

    final result = await _bookingController.createReservation(
      requestId: _requestId,
      motelId: widget.room.motelId,
      motelName: widget.room.motelName,
      roomId: widget.room.id,
      roomName: widget.room.name,
      roomNumber: widget.room.roomNumber,
      checkIn: checkIn,
      checkOut: checkOut,
      stayMode: _stayMode,
      guestCount: _guestCount,
      services: _selectedServiceItems,
      products: _selectedProductItems,
      roomTotal: _roomTotal,
      externalBlocked: _externalBlocked,
      simulateNetworkFailure: _simulateNetworkFailureNextAttempt,
      simulateConcurrentConflict: _simulateConflictNextAttempt,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    switch (result.outcome) {
      case CreateReservationOutcome.success:
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.clientBookingCheckout,
          arguments: result.reservation!.id,
        );
      case CreateReservationOutcome.conflict:
        _showRecoverableError(
          result.message!,
          actionLabel: 'Actualizar calendario',
          onAction: () => setState(() {}),
        );
      case CreateReservationOutcome.networkError:
        _showRecoverableError(
          result.message!,
          actionLabel: 'Reintentar',
          onAction: _submit,
        );
    }
  }

  void _showRecoverableError(
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: actionLabel, onPressed: onAction),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s3),
          child: AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: const Text('Nueva reserva'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            _HeaderCard(room: widget.room),
            const SizedBox(height: AppSpacing.s4),
            _ScheduleCard(
              room: widget.room,
              bookingController: _bookingController,
              externalBlocked: _externalBlocked,
              stayMode: _stayMode,
              onStayModeChanged: (mode) => setState(() => _stayMode = mode),
              selectedDay: _selectedDay,
              onDaySelected: (day) => setState(() => _selectedDay = day),
              checkInTime: _checkInTime,
              checkOutTime: _checkOutTime,
              hourBlock: _hourBlock,
              onHourBlockChanged: (hours) => setState(() => _hourBlock = hours),
              onPickCheckInTime: _pickCheckInTime,
              onPickCheckOutTime: _pickCheckOutTime,
              rangeError: _rangeError,
            ),
            const SizedBox(height: AppSpacing.s4),
            AppCard(
              child: QuantityStepper(
                label: 'Personas',
                subtitle: 'Máximo ${widget.room.capacity} por habitación',
                value: _guestCount,
                min: 1,
                max: widget.room.capacity,
                onChanged: (value) => setState(() => _guestCount = value),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            _ServicesCard(
              controller: _servicesController,
              services: _availableServices,
              selectedIds: _selectedServiceIds,
              onToggle: (service) => setState(() {
                if (!_selectedServiceIds.remove(service.id)) {
                  _selectedServiceIds.add(service.id);
                }
              }),
            ),
            const SizedBox(height: AppSpacing.s4),
            _ProductsCard(
              products: _availableProducts,
              selectedIds: _selectedProductIds,
              onToggle: (product) => setState(() {
                if (!_selectedProductIds.remove(product.id)) {
                  _selectedProductIds.add(product.id);
                }
              }),
            ),
            const SizedBox(height: AppSpacing.s4),
            _DebugToolsCard(
              simulateNetworkFailure: _simulateNetworkFailureNextAttempt,
              simulateConflict: _simulateConflictNextAttempt,
              onNetworkFailureChanged: (value) =>
                  setState(() => _simulateNetworkFailureNextAttempt = value),
              onConflictChanged: (value) =>
                  setState(() => _simulateConflictNextAttempt = value),
            ),
            const SizedBox(height: AppSpacing.s4),
            _SummaryCard(
              room: widget.room,
              hours: _hoursForTotal,
              roomTotal: _roomTotal,
              services: _selectedServiceItems,
              products: _selectedProductItems,
              total: _grandTotal,
              isFormValid: _isFormValid,
              isSubmitting: _isSubmitting,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.room});

  final RoomVisualData room;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            room.motelName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(room.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.s2),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              _Pill(
                icon: Icons.door_sliding_outlined,
                label: 'Habitación ${room.roomNumber}',
              ),
              _Pill(
                icon: Icons.people_alt_outlined,
                label: 'Máx. ${room.capacity} personas',
              ),
              _Pill(
                icon: Icons.payments_outlined,
                label: formatPricePerHour(room.pricePerHour),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: context.appColors.textSecondary),
            const SizedBox(width: AppSpacing.s2),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.room,
    required this.bookingController,
    required this.externalBlocked,
    required this.stayMode,
    required this.onStayModeChanged,
    required this.selectedDay,
    required this.onDaySelected,
    required this.checkInTime,
    required this.checkOutTime,
    required this.hourBlock,
    required this.onHourBlockChanged,
    required this.onPickCheckInTime,
    required this.onPickCheckOutTime,
    required this.rangeError,
  });

  final RoomVisualData room;
  final ClientBookingController bookingController;
  final List<BlockedRange> externalBlocked;
  final StayMode stayMode;
  final ValueChanged<StayMode> onStayModeChanged;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final TimeOfDay? checkInTime;
  final TimeOfDay? checkOutTime;
  final int hourBlock;
  final ValueChanged<int> onHourBlockChanged;
  final VoidCallback onPickCheckInTime;
  final VoidCallback onPickCheckOutTime;
  final String? rangeError;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fechas y horario',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.s3),
          SegmentedButton<StayMode>(
            segments: const [
              ButtonSegment(
                value: StayMode.dateWithHourBlock,
                label: Text('Bloque de horas'),
                icon: Icon(Icons.hourglass_bottom_outlined),
              ),
              ButtonSegment(
                value: StayMode.dateTimeRange,
                label: Text('Entrada y salida'),
                icon: Icon(Icons.schedule_outlined),
              ),
            ],
            selected: {stayMode},
            onSelectionChanged: (selection) =>
                onStayModeChanged(selection.first),
          ),
          const SizedBox(height: AppSpacing.s4),
          AvailabilityCalendar(
            selectedDay: selectedDay,
            onDaySelected: onDaySelected,
            isDayAvailable: (day) => bookingController.isDayAvailable(
              room.id,
              day,
              externalBlocked: externalBlocked,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          _TimeField(
            label: 'Hora de entrada',
            value: checkInTime,
            onTap: onPickCheckInTime,
          ),
          if (stayMode == StayMode.dateTimeRange) ...[
            const SizedBox(height: AppSpacing.s3),
            _TimeField(
              label: 'Hora de salida',
              value: checkOutTime,
              onTap: onPickCheckOutTime,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.s3),
            Text(
              'Duración (máx. $maxStayHourBlock horas)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s2,
              children: [
                for (var hours = 1; hours <= maxStayHourBlock; hours++)
                  ChoiceChip(
                    label: Text('$hours h'),
                    selected: hourBlock == hours,
                    onSelected: (_) => onHourBlockChanged(hours),
                  ),
              ],
            ),
          ],
          if (rangeError != null) ...[
            const SizedBox(height: AppSpacing.s3),
            _InlineNotice(message: rangeError!),
          ],
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: value == null
          ? '$label, sin definir'
          : '$label, ${value!.format(context)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s2,
            ),
            decoration: BoxDecoration(
              color: context.appColors.elevated,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_outlined,
                  color: context.appColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Text(
                  value == null ? 'Elegir hora' : value!.format(context),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({
    required this.controller,
    required this.services,
    required this.selectedIds,
    required this.onToggle,
  });

  final AdditionalServiceClientController controller;
  final List<AdditionalService> services;
  final Set<String> selectedIds;
  final ValueChanged<AdditionalService> onToggle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Servicios adicionales (opcional)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.s2),
          if (controller.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s2),
              child: AppSkeleton(height: 48),
            )
          else if (controller.errorMessage != null)
            AppErrorState(
              message: controller.errorMessage!,
              onRetry: controller.loadServicesByUserId,
            )
          else if (services.isEmpty)
            Text(
              'Este motel no tiene servicios adicionales disponibles.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            )
          else
            for (final service in services)
              PricedCheckboxTile(
                title: service.name,
                subtitle: service.description,
                priceLabel: formatCurrencyAmount(service.price),
                value: selectedIds.contains(service.id),
                onChanged: (_) => onToggle(service),
              ),
        ],
      ),
    );
  }
}

class _ProductsCard extends StatelessWidget {
  const _ProductsCard({
    required this.products,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<Product> products;
  final Set<String> selectedIds;
  final ValueChanged<Product> onToggle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Productos de la habitación (opcional)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.s2),
          if (products.isEmpty)
            Text(
              'Este motel no tiene productos disponibles.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            )
          else
            for (final product in products)
              PricedCheckboxTile(
                title: product.name,
                subtitle: product.description,
                priceLabel: formatCurrencyAmount(product.price.round()),
                value: selectedIds.contains(product.id),
                onChanged: (_) => onToggle(product),
              ),
        ],
      ),
    );
  }
}

/// Sección de pruebas mock, transparente para el usuario, que permite
/// demostrar de forma determinista los escenarios de interrupción de red
/// (reintento sin duplicar la reserva) y de concurrencia (el horario se
/// ocupa justo antes de confirmar). No representa ninguna feature real de
/// red ni de backend.
class _DebugToolsCard extends StatelessWidget {
  const _DebugToolsCard({
    required this.simulateNetworkFailure,
    required this.simulateConflict,
    required this.onNetworkFailureChanged,
    required this.onConflictChanged,
  });

  final bool simulateNetworkFailure;
  final bool simulateConflict;
  final ValueChanged<bool> onNetworkFailureChanged;
  final ValueChanged<bool> onConflictChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Herramientas de prueba (mock)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'Solo para verificar los escenarios de red y concurrencia sin backend real.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Simular error de red al reservar'),
            value: simulateNetworkFailure,
            onChanged: onNetworkFailureChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Simular que el horario se ocupó justo antes'),
            value: simulateConflict,
            onChanged: onConflictChanged,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.room,
    required this.hours,
    required this.roomTotal,
    required this.services,
    required this.products,
    required this.total,
    required this.isFormValid,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final RoomVisualData room;
  final int hours;
  final int roomTotal;
  final List<ReservationLineItem> services;
  final List<ReservationLineItem> products;
  final int total;
  final bool isFormValid;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s3),
          _SummaryRow(
            label: hours > 0 ? 'Habitación · $hours h' : 'Habitación',
            value: formatCurrencyAmount(roomTotal),
          ),
          for (final service in services)
            _SummaryRow(
              label: service.name,
              value: formatCurrencyAmount(service.subtotal),
            ),
          for (final product in products)
            _SummaryRow(
              label: product.name,
              value: formatCurrencyAmount(product.subtotal),
            ),
          const Divider(height: AppSpacing.s5),
          _SummaryRow(
            label: 'Total',
            value: formatCurrencyAmount(total),
            emphasize: true,
          ),
          const SizedBox(height: AppSpacing.s4),
          AppButton(
            label: 'Reservar',
            icon: Icons.event_available_outlined,
            loading: isSubmitting,
            onPressed: isFormValid && !isSubmitting ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasize
                  ? style
                  : style?.copyWith(color: context.appColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: emphasize
                ? style?.copyWith(color: Theme.of(context).colorScheme.primary)
                : style,
          ),
        ],
      ),
    );
  }
}
