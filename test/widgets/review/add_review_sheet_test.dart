import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/widgets/review/add_review_sheet.dart';

const _room = RoomVisualData(
  id: 'room-1',
  motelId: 'motel-1',
  name: 'Suite 101',
  description: 'Suite',
  idType: 'type-1',
  pricePerHour: 50000,
  roomNumber: '101',
  capacity: 2,
  imageUrls: [],
  isActive: true,
  includedServices: [],
);

Future<List<ReviewDraft>> _pumpSheet(
  WidgetTester tester, {
  required List<RoomVisualData> rooms,
  String? saveError,
}) async {
  final sent = <ReviewDraft>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: AddReviewSheet(
          motelId: 'motel-1',
          motelName: 'Motel Sol',
          rooms: rooms,
          onSave: (draft) async {
            sent.add(draft);
            return saveError;
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return sent;
}

Future<void> _chooseType(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<ReviewType>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _fillAndSave(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
  await tester.enterText(find.byType(TextField).at(0), 'Título');
  await tester.enterText(find.byType(TextField).at(1), 'Texto de la reseña');
  await tester.ensureVisible(find.text('Guardar'));
  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'sin habitaciones en el motel no ofrece la categoría Habitación',
    (tester) async {
      await _pumpSheet(tester, rooms: const []);

      await tester.tap(find.byType(DropdownButtonFormField<ReviewType>));
      await tester.pumpAndSettle();

      expect(find.text('Motel'), findsWidgets);
      expect(find.text('Atención'), findsWidgets);
      expect(find.text('Habitación'), findsNothing);
    },
  );

  testWidgets('una reseña de habitación exige elegir cuál y no se envía sin '
      'ella', (tester) async {
    final sent = await _pumpSheet(tester, rooms: const [_room]);

    await _chooseType(tester, 'Habitación');
    await _fillAndSave(tester);

    expect(
      find.text('Elige la habitación que quieres reseñar'),
      findsOneWidget,
    );
    expect(sent, isEmpty);
  });

  testWidgets('con la habitación elegida envía la reseña con su roomId', (
    tester,
  ) async {
    final sent = await _pumpSheet(tester, rooms: const [_room]);

    await _chooseType(tester, 'Habitación');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suite 101').last);
    await tester.pumpAndSettle();
    await _fillAndSave(tester);

    expect(sent.single.type, ReviewType.room);
    expect(sent.single.roomId, 'room-1');
  });

  testWidgets('si no se pudo guardar muestra el motivo y sigue abierto', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      rooms: const [],
      saveError: 'No hay conexión con el servidor de reseñas',
    );

    await _fillAndSave(tester);

    expect(
      find.text('No hay conexión con el servidor de reseñas'),
      findsOneWidget,
    );
    expect(find.text('Añadir reseña'), findsOneWidget);
  });
}
