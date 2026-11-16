import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/review/add_review_controller.dart';
import 'package:machuco/database/repository/review/firestore_review_repository.dart';
import 'package:machuco/database/repository/review/review_repository.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/service/review/review_author_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthorProvider implements ReviewAuthorProvider {
  @override
  Future<ReviewAuthor?> currentAuthor() async => (id: 'uid-7', name: 'Ana');
}

/// Repositorio en memoria que, con [failing], falla como lo haría Firestore
/// sin conexión o sin permiso.
class _FlakyReviewRepository extends InMemoryReviewRepository {
  _FlakyReviewRepository() : super(seed: const []);

  bool failing = false;

  @override
  Future<List<Review>> getAll() async {
    if (failing) throw const ReviewRepositoryException('sin conexión');
    return super.getAll();
  }

  @override
  Future<void> add(Review review) async {
    if (failing) throw const ReviewRepositoryException('permiso denegado');
    return super.add(review);
  }
}

final _date = DateTime.utc(2026, 11, 9, 15, 30);

Map<String, dynamic> _validData() => {
  'authorId': 'uid-7',
  'authorName': 'Ana',
  'title': 'Muy bien',
  'body': 'Limpio y tranquilo',
  'rating': 4,
  'date': Timestamp.fromDate(_date),
  'motelId': '1',
  'type': 'motel',
  'status': 'visible',
};

const ReviewDraft _draft = (
  type: ReviewType.room,
  roomId: 'room-3',
  rating: 5,
  title: 'Excelente',
  body: 'Todo perfecto',
);

void main() {
  group('reviewToFirestore / reviewFromFirestore', () {
    test('ida y vuelta conserva todos los campos', () {
      final review = Review(
        id: 'review-client-uid-7-1',
        authorId: 'uid-7',
        authorName: 'Ana',
        title: 'Muy bien',
        body: 'Limpio',
        rating: 4,
        date: _date,
        motelId: '1',
        roomId: 'room-3',
        type: ReviewType.room,
        status: ReviewModerationStatus.reported,
        reportReason: 'Spam',
        adminReply: 'Revisado',
        ownerReply: 'Gracias',
      );

      final back = reviewFromFirestore(review.id, reviewToFirestore(review))!;

      expect(back.id, review.id);
      expect(back.authorId, 'uid-7');
      expect(back.authorName, 'Ana');
      expect(back.title, 'Muy bien');
      expect(back.body, 'Limpio');
      expect(back.rating, 4);
      expect(back.date.isAtSameMomentAs(_date), isTrue);
      expect(back.motelId, '1');
      expect(back.roomId, 'room-3');
      expect(back.type, ReviewType.room);
      expect(back.status, ReviewModerationStatus.reported);
      expect(back.reportReason, 'Spam');
      expect(back.adminReply, 'Revisado');
      expect(back.ownerReply, 'Gracias');
    });

    test('una reseña nueva solo lleva los campos que permite la regla', () {
      final data = reviewToFirestore(reviewFromFirestore('r1', _validData())!);

      // Debe coincidir con hasValidReviewCreate en firestore.rules.
      expect(data.keys.toSet(), {
        'authorId',
        'authorName',
        'title',
        'body',
        'rating',
        'date',
        'motelId',
        'type',
        'status',
      });
      expect(data['date'], isA<Timestamp>());
      expect(data['type'], 'motel');
      expect(data['status'], 'visible');
    });

    test('documentos con campos obligatorios faltantes o de otro tipo '
        'devuelven null', () {
      for (final key in ['authorId', 'title', 'rating', 'date', 'motelId']) {
        expect(
          reviewFromFirestore('r1', _validData()..remove(key)),
          isNull,
          reason: 'sin $key',
        );
      }
      expect(
        reviewFromFirestore('r1', _validData()..['rating'] = 'cuatro'),
        isNull,
      );
      expect(
        reviewFromFirestore('r1', _validData()..['date'] = '2026-11-09'),
        isNull,
      );
    });

    test('opcionales inválidos no rompen la lectura', () {
      final review = reviewFromFirestore(
        'r1',
        _validData()
          ..['status'] = 'desconocido'
          ..['type'] = 42
          ..['roomId'] = 7
          ..['ownerReply'] = false,
      )!;

      expect(review.status, ReviewModerationStatus.visible);
      expect(review.type, ReviewType.motel);
      expect(review.roomId, isNull);
      expect(review.ownerReply, isNull);
    });

    test('acepta la calificación guardada como double', () {
      final review = reviewFromFirestore('r1', _validData()..['rating'] = 3.0)!;
      expect(review.rating, 3);
    });
  });

  group('ReviewsController con Firestore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'crearlo con valores por defecto no requiere Firebase inicializado',
      () {
        expect(ReviewsController.new, returnsNormally);
      },
    );

    test('el id de la reseña incluye el uid del autor', () async {
      final repository = InMemoryReviewRepository(seed: const []);
      final controller = ReviewsController(
        repository: repository,
        authorProvider: _FakeAuthorProvider(),
      );

      expect(await controller.submitReview('1', _draft), isTrue);

      final review = (await repository.getAll()).single;
      expect(review.id, matches(RegExp(r'^review-client-uid-7-[0-9]+$')));
    });

    test(
      'si el repositorio falla al guardar devuelve false y no notifica',
      () async {
        final controller = ReviewsController(
          repository: _FlakyReviewRepository()..failing = true,
          authorProvider: _FakeAuthorProvider(),
        );
        var notified = false;
        controller.addListener(() => notified = true);

        expect(await controller.submitReview('1', _draft), isFalse);
        expect(controller.totalCount, 0);
        expect(notified, isFalse);
      },
    );

    test(
      'si el repositorio falla al cargar no lanza y conserva la lista',
      () async {
        final repository = _FlakyReviewRepository();
        final controller = ReviewsController(
          repository: repository,
          authorProvider: _FakeAuthorProvider(),
        );
        await controller.submitReview('1', _draft);
        await controller.loadReviews();
        expect(controller.totalCount, 1);

        repository.failing = true;
        await expectLater(controller.loadReviews(), completes);
        expect(controller.totalCount, 1);
      },
    );
  });
}
