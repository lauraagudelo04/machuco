import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/repository/review/firestore_review_repository.dart';
import 'package:machuco/database/repository/review/review_sql_connect_gateway.dart';
import 'package:machuco/database/repository/review/sql_connect_review_repository.dart';
import 'package:machuco/models/review/review.dart';

/// Doble del gateway: guarda lo que se le pide y, con [error], falla como lo
/// haría SQL Connect sin sesión o sin conexión.
class _FakeGateway implements ReviewSqlConnectGateway {
  List<SqlConnectReviewRow> rows = [];
  final List<Review> created = [];
  Object? error;
  int calls = 0;

  @override
  Future<List<SqlConnectReviewRow>> listAll() async {
    calls++;
    if (error case final e?) throw e;
    return rows;
  }

  @override
  Future<String> createMine(Review review) async {
    calls++;
    if (error case final e?) throw e;
    created.add(review);
    return 'uuid-nuevo';
  }

  final List<({String id, String reply})> ownerReplies = [];

  @override
  Future<void> replyAsOwner(String id, String reply) async {
    calls++;
    if (error case final e?) throw e;
    ownerReplies.add((id: id, reply: reply));
  }

  final List<String> adminActions = [];

  @override
  Future<void> setStatusAsAdmin(String id, String status) async {
    calls++;
    if (error case final e?) throw e;
    adminActions.add('status $id $status');
  }

  @override
  Future<void> dismissReportAsAdmin(String id) async {
    calls++;
    if (error case final e?) throw e;
    adminActions.add('dismiss $id');
  }

  @override
  Future<void> replyAsAdmin(String id, String reply) async {
    calls++;
    if (error case final e?) throw e;
    adminActions.add('reply $id $reply');
  }

  @override
  Future<void> deleteAsAdmin(String id) async {
    calls++;
    if (error case final e?) throw e;
    adminActions.add('delete $id');
  }
}

SqlConnectReviewRow _row({
  String status = 'visible',
  int typeId = 1,
  String? roomId = 'room-3',
}) => (
  id: 'uuid-1',
  authorId: 'uid-7',
  authorName: 'Ana',
  title: 'Muy limpio',
  body: 'La habitación estaba impecable.',
  rating: 5,
  motelId: 'motel-1',
  roomId: roomId,
  typeId: typeId,
  status: status,
  reportReason: null,
  adminReply: null,
  ownerReply: 'Gracias, Ana',
  createdAt: DateTime.utc(2026, 11, 10, 15, 30),
);

final _review = Review(
  id: 'review-client-uid-7-1',
  authorId: 'uid-7',
  authorName: 'Ana',
  title: 'Muy limpio',
  body: 'La habitación estaba impecable.',
  rating: 5,
  date: DateTime.utc(2026, 11, 10),
  motelId: 'motel-1',
  roomId: 'room-3',
  type: ReviewType.room,
);

void main() {
  late _FakeGateway gateway;
  late SqlConnectReviewRepository repository;

  setUp(() {
    gateway = _FakeGateway();
    repository = SqlConnectReviewRepository(gateway: gateway);
  });

  group('reviewFromSqlConnect', () {
    test('convierte una fila en una Review del dominio', () {
      final review = reviewFromSqlConnect(_row());

      expect(review.id, 'uuid-1');
      expect(review.authorId, 'uid-7');
      expect(review.authorName, 'Ana');
      expect(review.rating, 5);
      expect(review.motelId, 'motel-1');
      expect(review.roomId, 'room-3');
      expect(review.type, ReviewType.room);
      expect(review.status, ReviewModerationStatus.visible);
      expect(review.ownerReply, 'Gracias, Ana');
      expect(review.date, DateTime.utc(2026, 11, 10, 15, 30));
    });

    test('traduce los estados de moderación conocidos', () {
      expect(
        reviewFromSqlConnect(_row(status: 'hidden')).status,
        ReviewModerationStatus.hidden,
      );
      expect(
        reviewFromSqlConnect(_row(status: 'reported')).status,
        ReviewModerationStatus.reported,
      );
    });

    test('un estado o tipo desconocido no rompe la lista', () {
      final review = reviewFromSqlConnect(_row(status: 'otro', typeId: 99));

      expect(review.status, ReviewModerationStatus.visible);
      expect(review.type, ReviewType.motel);
    });

    test('roomId null es una reseña del motel', () {
      expect(reviewFromSqlConnect(_row(roomId: null)).roomId, isNull);
    });
  });

  group('SqlConnectReviewRepository', () {
    test('getAll devuelve las filas convertidas y en el mismo orden', () async {
      gateway.rows = [_row(), _row(typeId: 3)];

      final reviews = await repository.getAll();

      expect(reviews, hasLength(2));
      expect(reviews.last.type, ReviewType.attention);
    });

    test('add envía la reseña al gateway', () async {
      await repository.add(_review);

      expect(gateway.created.single.title, 'Muy limpio');
      expect(gateway.created.single.type.id, ReviewType.room.id);
    });

    test('sin sesión, getAll y add lanzan ReviewRepositoryException', () async {
      gateway.error = DataConnectError(
        DataConnectErrorCode.unauthorized,
        'unauthenticated',
      );

      await expectLater(
        repository.getAll(),
        throwsA(
          isA<ReviewRepositoryException>().having(
            (e) => e.message,
            'message',
            'Debes iniciar sesión para publicar o ver reseñas',
          ),
        ),
      );
      await expectLater(
        repository.add(_review),
        throwsA(isA<ReviewRepositoryException>()),
      );
    });

    test('replyAsOwner envía el id y la respuesta al gateway', () async {
      await repository.replyAsOwner('uuid-1', 'Gracias, Ana');

      expect(gateway.ownerReplies.single, (
        id: 'uuid-1',
        reply: 'Gracias, Ana',
      ));
    });

    test(
      'replyAsOwner rechazado por el servidor explica que no es su motel',
      () async {
        gateway.error = DataConnectOperationError(
          DataConnectErrorCode.other,
          'Solo el propietario del motel puede responder esta reseña',
          DataConnectOperationFailureResponse([], null, null),
        );

        await expectLater(
          repository.replyAsOwner('uuid-1', 'x'),
          throwsA(
            isA<ReviewRepositoryException>().having(
              (e) => e.message,
              'message',
              'Solo puedes responder reseñas de tus moteles',
            ),
          ),
        );
      },
    );

    test(
      'replyAsOwner con un error inesperado usa el mensaje genérico',
      () async {
        gateway.error = StateError('falla');

        await expectLater(
          repository.replyAsOwner('uuid-1', 'x'),
          throwsA(
            isA<ReviewRepositoryException>().having(
              (e) => e.message,
              'message',
              'No fue posible guardar la respuesta',
            ),
          ),
        );
      },
    );

    test('un error inesperado usa el mensaje genérico', () async {
      gateway.error = StateError('falla');

      await expectLater(
        repository.add(_review),
        throwsA(
          isA<ReviewRepositoryException>().having(
            (e) => e.message,
            'message',
            'No fue posible publicar la reseña',
          ),
        ),
      );
    });

    test('update no está disponible y no toca la base', () async {
      await expectLater(
        repository.update(_review),
        throwsA(isA<ReviewRepositoryException>()),
      );
      expect(gateway.calls, 0);
    });

    test('las acciones del administrador llegan al gateway', () async {
      await repository.setHiddenAsAdmin('uuid-1', hidden: true);
      await repository.setHiddenAsAdmin('uuid-1', hidden: false);
      await repository.dismissReportAsAdmin('uuid-1');
      await repository.replyAsAdmin('uuid-1', 'Revisado');
      await repository.delete('uuid-1');

      expect(gateway.adminActions, [
        'status uuid-1 hidden',
        'status uuid-1 visible',
        'dismiss uuid-1',
        'reply uuid-1 Revisado',
        'delete uuid-1',
      ]);
    });

    test(
      'sin rol de administrador, el servidor rechaza la moderación',
      () async {
        gateway.error = DataConnectError(
          DataConnectErrorCode.unauthorized,
          'unauthorized',
        );
        final reason = isA<ReviewRepositoryException>().having(
          (e) => e.message,
          'message',
          'Solo un administrador puede moderar reseñas',
        );

        await expectLater(
          repository.setHiddenAsAdmin('uuid-1', hidden: true),
          throwsA(reason),
        );
        await expectLater(
          repository.dismissReportAsAdmin('uuid-1'),
          throwsA(reason),
        );
        await expectLater(
          repository.replyAsAdmin('uuid-1', 'x'),
          throwsA(reason),
        );
        await expectLater(repository.delete('uuid-1'), throwsA(reason));
      },
    );

    test('un error inesperado al moderar usa un mensaje genérico', () async {
      gateway.error = StateError('falla');

      await expectLater(
        repository.delete('uuid-1'),
        throwsA(
          isA<ReviewRepositoryException>().having(
            (e) => e.message,
            'message',
            'No fue posible actualizar la reseña',
          ),
        ),
      );
    });
  });
}
