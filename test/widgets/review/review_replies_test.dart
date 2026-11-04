import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/widgets/review/admin_review_card.dart';
import 'package:machuco/widgets/review/review_card.dart';

Review _review({String? ownerReply, String? adminReply}) => Review(
  id: 'review-1',
  authorId: 'user-1',
  authorName: 'Diana R.',
  title: 'Excelente atención',
  body: 'Muy amables.',
  rating: 5,
  date: DateTime(2026, 7, 10),
  motelId: '1',
  ownerReply: ownerReply,
  adminReply: adminReply,
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('ReviewCard (cliente)', () {
    testWidgets('muestra la respuesta del propietario y la del administrador', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReviewCard(
            review: _review(
              ownerReply: 'Gracias por tu visita',
              adminReply: 'Gracias por tu comentario',
            ),
          ),
        ),
      );

      expect(find.text('Respuesta del propietario'), findsOneWidget);
      expect(find.text('Gracias por tu visita'), findsOneWidget);
      expect(find.text('Respuesta del administrador'), findsOneWidget);
      expect(find.text('Gracias por tu comentario'), findsOneWidget);
    });

    testWidgets('sin respuestas no muestra ninguna nota', (tester) async {
      await tester.pumpWidget(_wrap(ReviewCard(review: _review())));

      expect(find.text('Respuesta del propietario'), findsNothing);
      expect(find.text('Respuesta del administrador'), findsNothing);
    });
  });

  testWidgets('AdminReviewCard muestra la respuesta del propietario', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AdminReviewCard(
          review: _review(ownerReply: 'Gracias por tu visita'),
          onToggleVisibility: () {},
          onDismissReport: () {},
          onReply: () {},
          onDelete: () {},
        ),
      ),
    );

    expect(find.text('Respuesta del propietario'), findsOneWidget);
    expect(find.text('Gracias por tu visita'), findsOneWidget);
  });
}
