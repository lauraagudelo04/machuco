import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/controllers/review/add_review_controller.dart';
import 'package:machuco/controllers/review/owner_review_controller.dart';
import 'package:machuco/controllers/review/review_administration_controller.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/repositories/review/review_repository.dart';
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
  late InMemoryReviewRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = InMemoryReviewRepository();
  });

  group('ReviewsController (cliente)', () {
    test('loadReviews carga las reseñas del motel y su promedio', () async {
      final controller = ReviewsController(repository: repository);
      await controller.loadReviews();

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

    test('addReview la pone de primera y notifica', () async {
      final controller = ReviewsController(repository: repository);
      await controller.loadReviews();
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.addReview(_review(roomId: 'room-1', rating: 2));

      expect(controller.getReviewsByMotelId('motel-eclipse').first.id,
          'review-new');
      expect(controller.getReviewsByRoomId('room-1').single.id, 'review-new');
      expect(controller.getAverageByRoomId('room-1'), 2.0);
      expect(notified, 1);
    });

    test('el borrador se guarda por motel y se borra al publicar', () async {
      final controller = ReviewsController(repository: repository);
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

      await controller.addReview(_review());
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
        repository: repository,
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

    test('responde con texto recortado e ignora respuestas vacías', () async {
      await controller.reply('review-owner-1', '  Gracias  ');
      await controller.reply('review-owner-2', '   ');

      final byId = {for (final r in controller.reviews) r.id: r};
      expect(byId['review-owner-1']!.ownerReply, 'Gracias');
      expect(byId['review-owner-2']!.ownerReply, isNull);
    });
  });

  group('ReviewAdministrationController (administrador)', () {
    late ReviewAdministrationController controller;

    setUp(() async {
      controller = ReviewAdministrationController(repository: repository);
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

    test('oculta y vuelve a mostrar una reseña', () async {
      await controller.toggleVisibility('review-1');
      expect(byId('review-1').status, ReviewModerationStatus.hidden);

      await controller.toggleVisibility('review-1');
      expect(byId('review-1').status, ReviewModerationStatus.visible);
    });

    test('descartar reporte la deja visible y sin motivo', () async {
      await controller.dismissReport('review-2');

      expect(byId('review-2').status, ReviewModerationStatus.visible);
      expect(byId('review-2').reportReason, isNull);
      expect(controller.reportedCount, 0);
    });

    test('responde y elimina', () async {
      await controller.reply('review-1', ' Gracias ');
      expect(byId('review-1').adminReply, 'Gracias');

      await controller.delete('review-1');
      expect(controller.reviews.any((r) => r.id == 'review-1'), isFalse);
      expect(controller.totalCount, 5);
    });
  });

  group('Repositorio compartido entre roles', () {
    test('lo que hace un rol lo ven los demás', () async {
      final client = ReviewsController(repository: repository);
      final owner = OwnerReviewController(
        motelController: _FakeMotelController([_motel('motel-sol', 'Sol')]),
        repository: repository,
      );
      final admin = ReviewAdministrationController(repository: repository);

      await client.addReview(_review(id: 'review-nueva', motelId: 'motel-sol'));
      await owner.loadReviews();
      await owner.reply('review-nueva', 'Gracias por venir');
      await admin.loadReviews();

      final seenByAdmin =
          admin.reviews.firstWhere((r) => r.id == 'review-nueva');
      expect(seenByAdmin.ownerReply, 'Gracias por venir');
      expect(admin.totalCount, 7);
    });
  });

  group('Entradas inválidas no rompen la app', () {
    test('ids desconocidos no cambian nada ni notifican', () async {
      final admin = ReviewAdministrationController(repository: repository);
      await admin.loadReviews();
      var notified = 0;
      admin.addListener(() => notified++);

      await admin.toggleVisibility('no-existe');
      await admin.dismissReport('no-existe');
      await admin.reply('no-existe', 'Hola');

      expect(notified, 0);
      expect(admin.totalCount, 6);
      expect(await repository.getAll(), hasLength(6));
    });

    test('propietario sin moteles no tiene reseñas y no falla', () async {
      final owner = OwnerReviewController(
        motelController: _FakeMotelController(const []),
        repository: repository,
      );
      await owner.loadReviews();

      expect(owner.reviews, isEmpty);
      expect(owner.averageRating, 0);
      expect(owner.getMotelName('motel-sol'), 'motel-sol');
      await owner.reply('review-owner-1', 'Hola');
      expect(owner.errorMessage, isNull);
    });
  });

  group('Reglas de dominio', () {
    test('averageRatingOf promedia y devuelve 0 sin reseñas', () {
      expect(averageRatingOf([_review(rating: 5), _review(rating: 2)]), 3.5);
      expect(averageRatingOf(const []), 0);
    });

    test('ReviewRules valida calificación y textos', () {
      expect(ReviewRules.isValidRating(0), isFalse);
      expect(ReviewRules.isValidRating(1), isTrue);
      expect(ReviewRules.isValidRating(5), isTrue);
      expect(ReviewRules.isValidRating(6), isFalse);
      expect(ReviewRules.isValidText('   '), isFalse);
      expect(ReviewRules.isValidText(' a '), isTrue);
    });
  });

  group('ReviewsController.submitReview', () {
    test('crea la reseña con autor, fecha e id y la guarda', () async {
      final controller = ReviewsController(
        repository: repository,
        authorId: 'user-7',
        authorName: 'Ana',
      );
      final before = DateTime.now();

      final saved = await controller.submitReview('motel-sol', (
        type: ReviewType.room,
        roomId: 'room-3',
        rating: 4,
        title: '  Bien  ',
        body: ' Limpio ',
      ));

      expect(saved, isTrue);
      final review = (await repository.getAll()).first;
      expect(review.id, startsWith('review-client-'));
      expect(review.authorId, 'user-7');
      expect(review.authorName, 'Ana');
      expect(review.motelId, 'motel-sol');
      expect(review.roomId, 'room-3');
      expect(review.type, ReviewType.room);
      expect(review.rating, 4);
      expect(review.title, 'Bien');
      expect(review.body, 'Limpio');
      expect(review.status, ReviewModerationStatus.visible);
      expect(review.date.isBefore(before), isFalse);
      expect(controller.getReviewsByMotelId('motel-sol').first.id, review.id);
    });

    for (final (label, rating, title, body) in [
      ('calificación 0', 0, 'T', 'B'),
      ('calificación 6', 6, 'T', 'B'),
      ('título vacío', 3, '  ', 'B'),
      ('texto vacío', 3, 'T', ''),
    ]) {
      test('rechaza $label sin guardar ni notificar', () async {
        final controller = ReviewsController(repository: repository);
        var notified = 0;
        controller.addListener(() => notified++);

        final saved = await controller.submitReview('motel-sol', (
          type: ReviewType.motel,
          roomId: null,
          rating: rating,
          title: title,
          body: body,
        ));

        expect(saved, isFalse);
        expect(notified, 0);
        expect(await repository.getAll(), hasLength(6));
      });
    }
  });
}
