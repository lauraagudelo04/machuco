import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/database/repository/motel/motel_repository.dart';
import 'package:machuco/models/motel/motel_model.dart';
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

const _realMotelId = '11111111-1111-4111-8111-111111111111';
const _realRoom = RoomVisualData(
  id: 'fixture-real-room',
  motelId: _realMotelId,
  name: 'Habitación real',
  description: 'Habitación de prueba',
  idType: 'fixture-real-type',
  pricePerHour: 50000,
  roomNumber: '101',
  capacity: 3,
  imageUrls: [],
  isActive: true,
  includedServices: [],
);

class _MotelLookupController extends MotelController {
  final requestedIds = <String>[];
  bool fail = false;

  @override
  Future<Motel?> getMotelById(String id) async {
    requestedIds.add(id);
    if (fail) {
      throw const MotelRepositoryException('No se pudo consultar SQL Connect');
    }
    return Motel(
      id: id,
      ownerId: 'fixture-owner',
      name: 'Motel del catálogo SQL',
      email: 'fixture@example.com',
      roomCount: 3,
      nit: 'fixture-nit',
      address: 'Dirección de prueba',
      phone: 'fixture-phone',
      paymentMethods: const ['Efectivo'],
      imageUrls: const [],
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('resolves the real motel UUID carried by the selected room', (
    tester,
  ) async {
    _useTallView(tester);
    final lookup = _MotelLookupController();
    await tester.pumpWidget(
      _wrap(CreateBookingPage(room: _realRoom, motelController: lookup)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(lookup.requestedIds, [_realMotelId]);
    expect(find.text('Motel del catálogo SQL'), findsOneWidget);
    expect(find.text('Cargando motel...'), findsNothing);
  });

  testWidgets('a failed motel lookup is visible and can be retried', (
    tester,
  ) async {
    _useTallView(tester);
    final lookup = _MotelLookupController()..fail = true;
    await tester.pumpWidget(
      _wrap(CreateBookingPage(room: _realRoom, motelController: lookup)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('No se pudo consultar SQL Connect'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Reservar'))
          .onPressed,
      isNull,
    );
    lookup.fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Motel del catálogo SQL'), findsOneWidget);
    expect(lookup.requestedIds, [_realMotelId, _realMotelId]);
  });

  testWidgets('sin fechas ni horas señala cada selector como obligatorio y '
      'mantiene deshabilitado el botón de reservar', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(
      _wrap(CreateBookingPage(room: _room, motelController: MotelController())),
    );
    await tester.pump(const Duration(seconds: 1));

    final button = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Reservar'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('el contador de personas deshabilita incrementar al llegar al '
      'máximo de la habitación', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(
      _wrap(CreateBookingPage(room: _room, motelController: MotelController())),
    );
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

  testWidgets('los avisos de campo obligatorio no aparecen al abrir y se '
      'muestran tras intentar reservar', (tester) async {
    _useTallView(tester);
    await tester.pumpWidget(
      _wrap(CreateBookingPage(room: _room, motelController: MotelController())),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Campo obligatorio'), findsNothing);

    await tester.tap(find.text('Reservar'));
    await tester.pump();

    expect(find.text('Campo obligatorio'), findsNWidgets(4));
  });
}
