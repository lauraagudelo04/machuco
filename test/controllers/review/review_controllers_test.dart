import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/controllers/review/add_review_controller.dart';
import 'package:machuco/controllers/review/owner_review_controller.dart';
import 'package:machuco/controllers/review/review_administration_controller.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/database/repository/review/review_repository.dart';
import 'package:machuco/service/review/review_author_provider.dart';
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

class _FakeAuthorProvider implements ReviewAuthorProvider {
  _FakeAuthorProvider(this.author);

  final ReviewAuthor? author;

  @override
  Future<ReviewAuthor?> currentAuthor() async => author;
}

class _FakeMotelController extends MotelController {
  _FakeMotelController(this.motels);

  final List<Motel> motels;

  @override
  Future<List<Motel>> getMyMotels() async => motels;
}

Review _review({
  String id = 'review-new',
  String motelId = '3',
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

      final reviews = controller.getReviewsByMotelId('3');
      expect(reviews.map((r) => r.id), [
        'review-1',
        'review-2',
        'review-client-1',
        'review-client-2',
      ]);
      expect(controller.getAverageByMotelId('3'), 3.5);
      expect(controller.getAverageByMotelId('motel-sin-resenas'), 0.0);
    });

    test('addReview la pone de primera y notifica', () async {
      final controller = ReviewsController(repository: repository);
      await controller.loadReviews();
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.addReview(_review(roomId: 'room-1', rating: 2));

      expect(controller.getReviewsByMotelId('3').first.id, 'review-new');
      expect(controller.getReviewsByRoomId('room-1').single.id, 'review-new');
      expect(controller.getAverageByRoomId('room-1'), 2.0);
      expect(notified, 1);
    });

    test('el borrador se guarda por motel y se borra al publicar', () async {
      final controller = ReviewsController(repository: repository);
      await controller.saveDraft('3', (
        type: ReviewType.room,
        roomId: 'room-1',
        rating: 4,
        title: 'Hola',
        body: 'Texto',
      ));

      final draft = await controller.loadDraft('3');
      expect(draft?.type, ReviewType.room);
      expect(draft?.roomId, 'room-1');
      expect(draft?.rating, 4);
      expect(draft?.title, 'Hola');
      expect(draft?.body, 'Texto');
      expect(await controller.loadDraft('otro-motel'), isNull);

      await controller.addReview(_review());
      expect(await controller.loadDraft('3'), isNull);
    });
  });

  group('OwnerReviewController (propietario)', () {
    late OwnerReviewController controller;

    setUp(() async {
      controller = OwnerReviewController(
        motelController: _FakeMotelController([
          _motel('1', 'Sol'),
          _motel('2', 'Luna'),
        ]),
        repository: repository,
      );
      await controller.loadReviews();
    });

    test('solo muestra reseñas de los moteles del propietario', () {
      expect(controller.reviews.map((r) => r.id), [
        'review-owner-1',
        'review-owner-2',
      ]);
      expect(controller.averageRating, 4.0);
      expect(controller.getMotelName('2'), 'Luna');
      expect(controller.errorMessage, isNull);
    });

    test('filtra por motel y por texto', () {
      controller.selectMotel('2');
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

    test('reporta con el motivo recortado e ignora motivos vacíos', () async {
      expect(await controller.report('review-owner-1', '  Spam  '), isNull);
      expect(await controller.report('review-owner-2', '   '), isNull);

      final stored = {for (final r in await repository.getAll()) r.id: r};
      expect(stored['review-owner-1']!.status, ReviewModerationStatus.reported);
      expect(stored['review-owner-1']!.reportReason, 'Spam');
      expect(stored['review-owner-2']!.status, ReviewModerationStatus.visible);
      final shown = {for (final r in controller.reviews) r.id: r};
      expect(shown['review-owner-1']!.status, ReviewModerationStatus.reported);
      expect(shown['review-owner-1']!.reportReason, 'Spam');
    });

    test('si el servidor rechaza el reporte, devuelve el motivo y no cambia '
        'la reseña', () async {
      final rejecting = OwnerReviewController(
        motelController: _FakeMotelController([_motel('1', 'Sol')]),
        repository: _RejectingRepository(repository),
      );
      await rejecting.loadReviews();

      expect(
        await rejecting.report('review-owner-1', 'Spam'),
        'No puedes reportar esta reseña',
      );
      final shown = rejecting.reviews.firstWhere(
        (r) => r.id == 'review-owner-1',
      );
      expect(shown.status, ReviewModerationStatus.visible);
      expect(shown.reportReason, isNull);
    });

    test('reply devuelve null cuando se guarda', () async {
      expect(await controller.reply('review-owner-1', 'Gracias'), isNull);
    });

    test('si el servidor rechaza la respuesta, devuelve el motivo y no la '
        'muestra como guardada', () async {
      final rejecting = OwnerReviewController(
        motelController: _FakeMotelController([_motel('1', 'Sol')]),
        repository: _RejectingRepository(repository),
      );
      await rejecting.loadReviews();

      final error = await rejecting.reply('review-owner-1', 'Gracias');

      expect(error, 'Solo puedes responder reseñas de tus moteles');
      expect(
        rejecting.reviews
            .firstWhere((r) => r.id == 'review-owner-1')
            .ownerReply,
        isNull,
      );
    });
  });

  group('ReviewAdministrationController (administrador)', () {
    late ReviewAdministrationController controller;

    setUp(() async {
      controller = ReviewAdministrationController(repository: repository);
      await controller.loadReviews();
    });

    Review byId(String id) => controller.reviews.firstWhere((r) => r.id == id);

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

    test(
      'las acciones del administrador quedan guardadas en el repositorio',
      () async {
        await controller.toggleVisibility('review-1');
        await controller.dismissReport('review-2');
        await controller.reply('review-owner-1', 'Revisado');
        await controller.delete('review-owner-2');

        final stored = {for (final r in await repository.getAll()) r.id: r};
        expect(stored['review-1']!.status, ReviewModerationStatus.hidden);
        expect(stored['review-2']!.status, ReviewModerationStatus.visible);
        expect(stored['review-2']!.reportReason, isNull);
        expect(stored['review-owner-1']!.adminReply, 'Revisado');
        expect(stored.containsKey('review-owner-2'), isFalse);
      },
    );

    test('si el servidor rechaza una acción, devuelve el motivo y no cambia '
        'la reseña en pantalla', () async {
      final rejecting = ReviewAdministrationController(
        repository: _RejectingRepository(repository),
      );
      await rejecting.loadReviews();
      Review find(String id) => rejecting.reviews.firstWhere((r) => r.id == id);
      const reason = 'Solo un administrador puede moderar reseñas';

      expect(await rejecting.toggleVisibility('review-1'), reason);
      expect(await rejecting.dismissReport('review-2'), reason);
      expect(await rejecting.reply('review-1', 'Hola'), reason);
      expect(await rejecting.delete('review-1'), reason);

      expect(find('review-1').status, ReviewModerationStatus.visible);
      expect(find('review-1').adminReply, isNull);
      expect(find('review-2').status, ReviewModerationStatus.reported);
      expect(rejecting.totalCount, 6);
    });

    test('las acciones exitosas devuelven null', () async {
      expect(await controller.toggleVisibility('review-1'), isNull);
      expect(await controller.dismissReport('review-2'), isNull);
      expect(await controller.reply('review-1', 'Hola'), isNull);
      expect(await controller.delete('review-1'), isNull);
    });
  });

  group('Repositorio compartido entre roles', () {
    test('lo que hace un rol lo ven los demás', () async {
      final client = ReviewsController(repository: repository);
      final owner = OwnerReviewController(
        motelController: _FakeMotelController([_motel('1', 'Sol')]),
        repository: repository,
      );
      final admin = ReviewAdministrationController(repository: repository);

      await client.addReview(_review(id: 'review-nueva', motelId: '1'));
      await owner.loadReviews();
      await owner.reply('review-nueva', 'Gracias por venir');
      await admin.loadReviews();

      final seenByAdmin = admin.reviews.firstWhere(
        (r) => r.id == 'review-nueva',
      );
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
      expect(owner.getMotelName('1'), '1');
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
        authorProvider: _FakeAuthorProvider((id: 'user-7', name: 'Ana')),
      );
      final before = DateTime.now();

      final saved = await controller.submitReview('1', (
        type: ReviewType.room,
        roomId: 'room-3',
        rating: 4,
        title: '  Bien  ',
        body: ' Limpio ',
      ));

      expect(saved, isNull);
      final review = (await repository.getAll()).first;
      expect(review.id, startsWith('review-client-'));
      expect(review.authorId, 'user-7');
      expect(review.authorName, 'Ana');
      expect(review.motelId, '1');
      expect(review.roomId, 'room-3');
      expect(review.type, ReviewType.room);
      expect(review.rating, 4);
      expect(review.title, 'Bien');
      expect(review.body, 'Limpio');
      expect(review.status, ReviewModerationStatus.visible);
      expect(review.date.isBefore(before), isFalse);
      expect(controller.getReviewsByMotelId('1').first.id, review.id);
    });

    test('sin sesión no guarda ni notifica', () async {
      final controller = ReviewsController(
        repository: repository,
        authorProvider: _FakeAuthorProvider(null),
      );
      var notified = 0;
      controller.addListener(() => notified++);

      final saved = await controller.submitReview('1', (
        type: ReviewType.motel,
        roomId: null,
        rating: 5,
        title: 'Bien',
        body: 'Limpio',
      ));

      expect(saved, 'Debes iniciar sesión para publicar una reseña');
      expect(notified, 0);
      expect(await repository.getAll(), hasLength(6));
    });

    test('una reseña de habitación sin habitación no se guarda', () async {
      final controller = ReviewsController(
        repository: repository,
        authorProvider: _FakeAuthorProvider((id: 'user-7', name: 'Ana')),
      );

      final saved = await controller.submitReview('1', (
        type: ReviewType.room,
        roomId: null,
        rating: 4,
        title: 'Bien',
        body: 'Limpio',
      ));

      expect(saved, 'Elige la habitación que quieres reseñar');
      expect(await repository.getAll(), hasLength(6));
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

        final saved = await controller.submitReview('1', (
          type: ReviewType.motel,
          roomId: null,
          rating: rating,
          title: title,
          body: body,
        ));

        expect(saved, 'Revisa la calificación, el título y la reseña');
        expect(notified, 0);
        expect(await repository.getAll(), hasLength(6));
      });
    }
  });

  test('el cliente no ve reseñas ocultas ni cuentan en el promedio', () async {
    final admin = ReviewAdministrationController(repository: repository);
    await admin.loadReviews();
    await admin.toggleVisibility('review-1');

    final client = ReviewsController(repository: repository);
    await client.loadReviews();

    expect(client.getReviewsByMotelId('3').map((r) => r.id), [
      'review-2',
      'review-client-1',
      'review-client-2',
    ]);
    expect(client.getAverageByMotelId('3'), 3.0);
  });

  test(
    'si la lista se recarga mientras se guarda, el cambio igual se ve',
    () async {
      final repository = _SlowReplyRepository();
      final controller = OwnerReviewController(
        motelController: _FakeMotelController([_motel('1', 'Sol')]),
        repository: repository,
      );
      await controller.loadReviews();

      final saving = controller.reply('review-owner-1', 'Gracias');
      await controller.loadReviews();
      repository.finishSave();
      await saving;

      expect(
        controller.reviews
            .firstWhere((r) => r.id == 'review-owner-1')
            .ownerReply,
        'Gracias',
      );
    },
  );

  group('carga con error del repositorio', () {
    const reason = 'No hay conexión con el servidor de reseñas';

    test('el propietario ve el motivo del repositorio', () async {
      final controller = OwnerReviewController(
        motelController: _FakeMotelController([_motel('1', 'Sol')]),
        repository: _FailingLoadRepository(reason),
      );

      await controller.loadReviews();

      expect(controller.errorMessage, reason);
    });

    test('el administrador ve el motivo del repositorio', () async {
      final controller = ReviewAdministrationController(
        repository: _FailingLoadRepository(reason),
      );

      await controller.loadReviews();

      expect(controller.errorMessage, reason);
    });

    test('un error inesperado mantiene el mensaje genérico', () async {
      final controller = ReviewAdministrationController(
        repository: _FailingLoadRepository(null),
      );

      await controller.loadReviews();

      expect(controller.errorMessage, 'No fue posible cargar las reseñas.');
    });
  });
}

/// Repositorio que lee de [_inner] pero rechaza las respuestas y la
/// moderación, como hace SQL Connect cuando el usuario no tiene permiso.
class _RejectingRepository implements ReviewRepository {
  _RejectingRepository(this._inner);

  final ReviewRepository _inner;

  @override
  Future<List<Review>> getAll() => _inner.getAll();

  @override
  Future<void> add(Review review) => _inner.add(review);

  @override
  Future<void> update(Review review) => _inner.update(review);

  @override
  Future<void> delete(String id) async =>
      throw const ReviewRepositoryException(_adminReason);

  @override
  Future<void> replyAsOwner(String reviewId, String reply) async =>
      throw const ReviewRepositoryException(
        'Solo puedes responder reseñas de tus moteles',
      );

  @override
  Future<void> reportAsOwner(String reviewId, String reason) async =>
      throw const ReviewRepositoryException('No puedes reportar esta reseña');

  @override
  Future<void> setHiddenAsAdmin(
    String reviewId, {
    required bool hidden,
  }) async => throw const ReviewRepositoryException(_adminReason);

  @override
  Future<void> dismissReportAsAdmin(String reviewId) async =>
      throw const ReviewRepositoryException(_adminReason);

  @override
  Future<void> replyAsAdmin(String reviewId, String reply) async =>
      throw const ReviewRepositoryException(_adminReason);

  static const _adminReason = 'Solo un administrador puede moderar reseñas';
}

/// Repositorio cuya carga falla: con [reason] lanza
/// [ReviewRepositoryException]; con `null`, un error inesperado.
class _FailingLoadRepository extends InMemoryReviewRepository {
  _FailingLoadRepository(this.reason);

  final String? reason;

  @override
  Future<List<Review>> getAll() async {
    if (reason case final message?) throw ReviewRepositoryException(message);
    throw StateError('falla');
  }
}

/// Repositorio cuya respuesta del propietario queda pendiente hasta
/// [finishSave], para simular una recarga de la lista durante el guardado.
class _SlowReplyRepository extends InMemoryReviewRepository {
  final _gate = Completer<void>();

  void finishSave() => _gate.complete();

  /// Como SQL Connect, cada carga crea objetos nuevos.
  @override
  Future<List<Review>> getAll() async => [
    for (final review in await super.getAll()) review.copyWith(),
  ];

  @override
  Future<void> replyAsOwner(String reviewId, String reply) async {
    await _gate.future;
    await super.replyAsOwner(reviewId, reply);
  }
}
