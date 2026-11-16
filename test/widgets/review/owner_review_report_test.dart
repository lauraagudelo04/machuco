import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/controllers/review/owner_review_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/review/review_repository.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/views/review/owner_view/owner_review_page.dart';

class _FakeMotelController extends MotelController {
  @override
  Future<List<Motel>> getMyMotels() async => [
    Motel(
      id: '1',
      ownerId: 'owner-test',
      name: 'Sol',
      email: '1@test.com',
      roomCount: 1,
      nit: '900',
      address: 'Calle 1',
      phone: '300',
      paymentMethods: const [],
      imageUrls: const [],
    ),
  ];
}

void main() {
  testWidgets('el propietario reporta una reseña con un motivo', (
    tester,
  ) async {
    final repository = InMemoryReviewRepository();
    final controller = OwnerReviewController(
      motelController: _FakeMotelController(),
      repository: repository,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OwnerReviewPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    final reportButton = find.widgetWithText(TextButton, 'Reportar');
    await tester.ensureVisible(reportButton);
    await tester.pumpAndSettle();
    await tester.tap(reportButton);
    await tester.pumpAndSettle();
    expect(find.text('Reportar reseña'), findsOneWidget);
    expect(find.textContaining('revisará la reseña de Diana'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      '  Lenguaje ofensivo  ',
    );
    await tester.tap(find.text('Enviar reporte'));
    await tester.pumpAndSettle();

    final stored = (await repository.getAll()).firstWhere(
      (r) => r.id == 'review-owner-1',
    );
    expect(stored.status, ReviewModerationStatus.reported);
    expect(stored.reportReason, 'Lenguaje ofensivo');
    expect(find.text('Reportada al administrador'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Reportar'), findsNothing);
  });
}
