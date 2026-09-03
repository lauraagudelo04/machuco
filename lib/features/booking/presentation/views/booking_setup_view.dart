import 'package:flutter/material.dart';
import 'package:machuco/controllers/booking/client_view/client_booking_ui_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking_checkout_data.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/booking/booking_view_support.dart';
import 'package:machuco/widgets/booking/booking_widgets.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

class CreateBookingPage extends StatefulWidget {
  const CreateBookingPage({super.key, this.initialData, this.onContinue});

  final BookingCheckoutData? initialData;
  final ValueChanged<BookingCheckoutData>? onContinue;

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  late BookingCheckoutData _data;
  BookingDurationMode _durationMode = BookingDurationMode.hours;
  int _hours = 3;
  final Set<String> _selectedExtraIds = {};

  static const _extras = ClientBookingUiController.extras;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData ?? ClientBookingUiController.initialCheckout;
    _hours = _data.billableHours.clamp(1, 12);
    _selectedExtraIds.addAll(_data.extras.map((item) => item.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configura tu reserva')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BookingStayHeader(data: _data),
                const SizedBox(height: AppSpacing.s4),
                ResponsiveSplit(
                  primary: Column(
                    children: [
                      BookingSection(
                        title: 'Fecha y duración',
                        subtitle:
                            'Selecciona cuándo llegas y cómo quieres definir la salida.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BookingDateTimeTile(
                              label: 'Llegada',
                              value: formatBookingDate(_data.arrival),
                              icon: Icons.login_outlined,
                              onTap: () => _pickDateTime(isArrival: true),
                            ),
                            const SizedBox(height: AppSpacing.s3),
                            SegmentedButton<BookingDurationMode>(
                              segments: const [
                                ButtonSegment(
                                  value: BookingDurationMode.hours,
                                  icon: Icon(Icons.timer_outlined),
                                  label: Text('Horas'),
                                ),
                                ButtonSegment(
                                  value: BookingDurationMode.exactDateTime,
                                  icon: Icon(Icons.event_outlined),
                                  label: Text('Salida exacta'),
                                ),
                              ],
                              selected: {_durationMode},
                              onSelectionChanged: (selection) => setState(
                                () => _durationMode = selection.first,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s3),
                            if (_durationMode == BookingDurationMode.hours)
                              QuantitySelector(
                                label: 'Duración',
                                value: _hours,
                                minimum: 1,
                                maximum: 12,
                                helperText: 'Número de horas de la estadía',
                                onChanged: _setHours,
                              )
                            else
                              BookingDateTimeTile(
                                label: 'Salida',
                                value: formatBookingDate(_data.departure),
                                icon: Icons.logout_outlined,
                                onTap: () => _pickDateTime(isArrival: false),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      BookingSection(
                        title: 'Huéspedes',
                        subtitle:
                            'La capacidad máxima de esta habitación es ${_data.maxCapacity}.',
                        child: QuantitySelector(
                          label: 'Número de huéspedes',
                          value: _data.guests,
                          minimum: 1,
                          maximum: _data.maxCapacity,
                          onChanged: (value) => setState(
                            () => _data = _data.copyWith(guests: value),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      BookingSection(
                        title: 'Adicionales y minibar',
                        subtitle:
                            'Personaliza tu estadía. Puedes cambiar esta selección antes de pagar.',
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < _extras.length;
                              index++
                            ) ...[
                              BookingOptionTile(
                                title: _extras[index].name,
                                subtitle: _extras[index].description,
                                icon: _extraIcon(_extras[index].id),
                                selected: _selectedExtraIds.contains(
                                  _extras[index].id,
                                ),
                                trailing: Text(
                                  formatBookingMoney(_extras[index].price),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                onChanged: (_) => _toggleExtra(_extras[index]),
                              ),
                              if (index != _extras.length - 1)
                                const SizedBox(height: AppSpacing.s2),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  secondary: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PriceBreakdownCard(data: _data),
                      const SizedBox(height: AppSpacing.s4),
                      AppButton(
                        label: 'Continuar al pago',
                        icon: Icons.arrow_forward,
                        onPressed: _continue,
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Aún no se realizará ningún cobro.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setHours(int value) {
    setState(() {
      _hours = value;
      _data = _data.copyWith(
        departure: _data.arrival.add(Duration(hours: value)),
      );
    });
  }

  void _toggleExtra(BookingExtra extra) {
    setState(() {
      if (!_selectedExtraIds.remove(extra.id)) _selectedExtraIds.add(extra.id);
      _data = _data.copyWith(
        extras: _extras
            .where((item) => _selectedExtraIds.contains(item.id))
            .toList(growable: false),
      );
    });
  }

  Future<void> _pickDateTime({required bool isArrival}) async {
    final initial = isArrival ? _data.arrival : _data.departure;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: isArrival ? DateTime.now() : _data.arrival,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isArrival ? 'FECHA DE LLEGADA' : 'FECHA DE SALIDA',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: isArrival ? 'HORA DE LLEGADA' : 'HORA DE SALIDA',
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!isArrival && !selected.isAfter(_data.arrival)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La salida debe ser posterior a la llegada.'),
        ),
      );
      return;
    }
    setState(() {
      if (isArrival) {
        final departure = _durationMode == BookingDurationMode.hours
            ? selected.add(Duration(hours: _hours))
            : (_data.departure.isAfter(selected)
                  ? _data.departure
                  : selected.add(const Duration(hours: 1)));
        _data = _data.copyWith(arrival: selected, departure: departure);
      } else {
        _data = _data.copyWith(departure: selected);
      }
    });
  }

  void _continue() {
    if (widget.onContinue != null) {
      widget.onContinue!(_data);
      return;
    }
    Navigator.pushNamed(context, AppRoutes.payment, arguments: _data);
  }

  IconData _extraIcon(String id) => switch (id) {
    'romantic' => Icons.favorite_outline,
    'birthday' => Icons.celebration_outlined,
    'sparkling' => Icons.local_bar_outlined,
    _ => Icons.shopping_bag_outlined,
  };
}
