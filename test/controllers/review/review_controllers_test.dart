import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/controllers/review/add_review_controller.dart';
import 'package:machuco/controllers/review/owner_review_controller.dart';
import 'package:machuco/controllers/review/review_administration_controller.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/review/review.dart';
import 'package:shared_preferences/shared_preferences.dart';

Motel _motel(String id, String name) => Motel(
  id: id,
  ownerId: 'owner-test',
  name: name,
  email: '$id@test.com',
  roomCount: 1,
  nit: '900',
  address: 'Calle 1',
  phone: '300',
  paymentMethods: const [],
  imageUrls: const [],
);

class _FakeMotelController extends MotelController {
  _FakeMotelController(this.motels);

  final List<Motel> motels;

  @override
  Future<List<Motel>> getMyMotels() async => motels;
}

Review _review({
  String id = 'review-new',
  String motelId = 'motel-eclipse',
  String? roomId,
  int rating = 4,
}) => Review(
  id: id,
  authorId: 'user-test',
  authorName: 'Prueba',
  title: 'Título',
  body: 'Cuerpo',
  rating: rating,
  date: DateTime(2026, 11, 1),
  motelId: motelId,
  roomId: roomId,
  type: roomId == null ? ReviewType.motel : ReviewType.room,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReviewsController (cliente)', () {
    test('seedReviews carga las reseñas del motel y su promedio', () {
      final controller = ReviewsController()..seedReviews();

      final reviews = controller.getReviewsByMotelId('motel-eclipse');
      expect(reviews.map((r) => r.id), [
        'review-1',
        'review-2',
        'review-client-1',
        'review-client-2',
      ]);
      expect(controller.getAverageByMotelId('motel-eclipse'), 3.5);
      expect(controller.getAverageByMotelId('motel-sin-resenas'), 0.0);
    });

    test('addReview la pone de primera y notifica', () {
      final controller = ReviewsController()..seedReviews();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.addReview(_review(roomId: 'room-1', rating: 2));

      expect(controller.getReviewsByMotelId('motel-eclipse').first.id,
          'review-new');
      expect(controller.getReviewsByRoomId('room-1').single.id, 'review-new');
      expect(controller.getAverageByRoomId('room-1'), 2.0);
      expect(notified, 1);
    });

    test('el borrador se guarda por motel y se borra al publicar', () async {
      final controller = ReviewsController();
      await controller.saveDraft('motel-eclipse', (
        type: ReviewType.room,
        roomId: 'room-1',
        rating: 4,
        title: 'Hola',
        body: 'Texto',
      ));

      final draft = await controller.loadDraft('motel-eclipse');
      expect(draft?.type, ReviewType.room);
      expect(draft?.roomId, 'room-1');
      expect(draft?.rating, 4);
      expect(draft?.title, 'Hola');
      expect(draft?.body, 'Texto');
      expect(await controller.loadDraft('otro-motel'), isNull);

      controller.addReview(_review());
      await Future<void>.delayed(Duration.zero);
      expect(await controller.loadDraft('motel-eclipse'), isNull);
    });
  });

  group('OwnerReviewController (propietario)', () {
    late OwnerReviewController controller;

    setUp(() async {
      controller = OwnerReviewController(
        motelController: _FakeMotelController([
          _motel('motel-sol', 'Sol'),
          _motel('motel-luna', 'Luna'),
        ]),
      );
      await controller.loadReviews();
    });

    test('solo muestra reseñas de los moteles del propietario', () {
      expect(controller.reviews.map((r) => r.id),
          ['review-owner-1', 'review-owner-2']);
      expect(controller.averageRating, 4.0);
      expect(controller.getMotelName('motel-luna'), 'Luna');
      expect(controller.errorMessage, isNull);
    });

    test('filtra por motel y por texto', () {
      controller.selectMotel('motel-luna');
      expect(controller.reviews.single.id, 'review-owner-2');

      controller
        ..selectMotel(null)
        ..setQuery('  DIANA ');
      expect(controller.reviews.single.id, 'review-owner-1');
    });

    test('responde con texto recortado e ignora respuestas vacías', () {
      controller.reply('review-owner-1', '  Gracias  ');
      controller.reply('review-owner-2', '   ');

      final byId = {for (final r in controller.reviews) r.id: r};
      expect(byId['review-owner-1']!.ownerReply, 'Gracias');
      expect(byId['review-owner-2']!.ownerReply, isNull);
    });
  });

  group('ReviewAdministrationController (administrador)', () {
    late ReviewAdministrationController controller;

    setUp(() async {
      controller = ReviewAdministrationController();
      await controller.loadReviews();
    });

    Review byId(String id) =>
        controller.reviews.firstWhere((r) => r.id == id);

    test('carga todas las reseñas con sus métricas', () {
      expect(controller.totalCount, 6);
      expect(controller.reportedCount, 1);
      expect(controller.averageRating, closeTo(22 / 6, 1e-9));
    });

    test('filtra por estado y por texto', () {
      controller.setFilter(ReviewFilter.reported);
      expect(controller.reviews.single.id, 'review-2');

      controller
        ..setFilter(ReviewFilter.all)
        ..setQuery('aire');
      expect(controller.reviews.single.id, 'review-owner-2');
    });

    test('oculta y vuelve a mostrar una reseña', () {
      controller.toggleVisibility('review-1');
      expect(byId('review-1').status, ReviewModerationStatus.hidden);

      controller.toggleVisibility('review-1');
      expect(byId('review-1').status, ReviewModerationStatus.visible);
    });

    test('descartar reporte la deja visible y sin motivo', () {
      controller.dismissReport('review-2');

      expect(byId('review-2').status, ReviewModerationStatus.visible);
      expect(byId('review-2').reportReason, isNull);
      expect(controller.reportedCount, 0);
    });

    test('responde y elimina', () {
      controller.reply('review-1', ' Gracias ');
      expect(byId('review-1').adminReply, 'Gracias');

      controller.delete('review-1');
      expect(controller.reviews.any((r) => r.id == 'review-1'), isFalse);
      expect(controller.totalCount, 5);
    });
  });
}
