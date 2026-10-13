import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/views/booking/client_view/create_booking_page.dart';
import 'package:machuco/widgets/booking/quantity_stepper.dart';

const _room = RoomVisualData(
  id: 'room-test',
  motelId: '1',
  name: 'Suite Prueba',
  description: 'Habitación de prueba',
  idType: 'type-test',
  pricePerHour: 50000,
  roomNumber: '999',
  capacity: 3,
  imageUrls: [],
  isActive: true,
  includedServices: [],
);

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('sin fechas ni horas señala cada selector como obligatorio y '
      'mantiene deshabilitado el botón de reservar', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_wrap(const CreateBookingPage(room: _room)));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Campo obligatorio'), findsNWidgets(4));

    final button = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Reservar'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('el contador de personas deshabilita incrementar al llegar al '
      'máximo de la habitación', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(_wrap(const CreateBookingPage(room: _room)));
    await tester.pump(const Duration(seconds: 1));

    final increase = find.byTooltip('Aumentar Personas');
    for (var i = 0; i < 2; i++) {
      await tester.tap(increase);
      await tester.pump();
    }

    final stepper = tester.widget<QuantityStepper>(
      find.byType(QuantityStepper),
    );
    expect(stepper.value, 3);
    expect(stepper.max, 3);

    // At the limit another tap changes nothing.
    await tester.tap(increase, warnIfMissed: false);
    await tester.pump();
    expect(
      tester.widget<QuantityStepper>(find.byType(QuantityStepper)).value,
      3,
    );
  });
}
