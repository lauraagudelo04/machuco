import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/repository/review/review_repository.dart';
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

  /// Escrituras que llegaron al servidor, en orden: la operación, el id de
  /// la reseña y el texto enviado (respuesta, motivo o estado), si hay.
  final List<({String operation, String id, String? text})> sent = [];

  Future<void> _send(String operation, String id, [String? text]) async {
    calls++;
    if (error case final e?) throw e;
    sent.add((operation: operation, id: id, text: text));
  }

  @override
  Future<void> replyAsOwner(String id, String reply) =>
      _send('replyAsOwner', id, reply);

  @override
  Future<void> reportAsOwner(String id, String reason) =>
      _send('reportAsOwner', id, reason);

  @override
  Future<void> setHiddenAsAdmin(String id, {required bool hidden}) =>
      _send('setHiddenAsAdmin', id, '$hidden');

  @override
  Future<void> dismissReportAsAdmin(String id) =>
      _send('dismissReportAsAdmin', id);

  @override
  Future<void> replyAsAdmin(String id, String reply) =>
      _send('replyAsAdmin', id, reply);

  @override
  Future<void> delete(String id) => _send('delete', id);
}

/// Rechazo de un `@check`, armado como lo hace el SDK 0.4.1 cuando el
/// servidor responde 200 con `errors` (ver `core/ref.dart`).
DataConnectOperationError<Object?> _checkFailed(String serverMessage) =>
    DataConnectOperationError(
      DataConnectErrorCode.other,
      'Failed to invoke operation: ',
      DataConnectOperationFailureResponse(
        [DataConnectOperationFailureResponseErrorInfo([], serverMessage)],
        null,
        null,
      ),
    );

/// Error HTTP armado como lo hace el transporte REST del SDK 0.4.1: solo el
/// 401 es `unauthorized`; cualquier otro estado llega como `other`.
DataConnectError _httpError(int status, String body) => DataConnectError(
  status == 401
      ? DataConnectErrorCode.unauthorized
      : DataConnectErrorCode.other,
  "Received a status code of $status with a message '$body'",
);

/// Sin red, el transporte REST envuelve la excepción en un error `other`.
final _networkError = DataConnectError(
  DataConnectErrorCode.other,
  'Failed to invoke operation: ClientException with SocketException: '
  'Connection refused',
);

Matcher _failsWith(String message) => throwsA(
  isA<ReviewRepositoryException>().having((e) => e.message, 'message', message),
);

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

      expect(gateway.sent, [
        (operation: 'replyAsOwner', id: 'uuid-1', text: 'Gracias, Ana'),
      ]);
    });

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

    test('reportAsOwner envía el id y el motivo al gateway', () async {
      await repository.reportAsOwner('uuid-1', 'Spam');

      expect(gateway.sent, [
        (operation: 'reportAsOwner', id: 'uuid-1', text: 'Spam'),
      ]);
    });

    test(
      'reportAsOwner con un error inesperado usa el mensaje genérico',
      () async {
        gateway.error = StateError('falla');

        await expectLater(
          repository.reportAsOwner('uuid-1', 'Spam'),
          throwsA(
            isA<ReviewRepositoryException>().having(
              (e) => e.message,
              'message',
              'No fue posible reportar la reseña',
            ),
          ),
        );
      },
    );

    test('las acciones del administrador llegan al gateway', () async {
      await repository.setHiddenAsAdmin('uuid-1', hidden: true);
      await repository.setHiddenAsAdmin('uuid-1', hidden: false);
      await repository.dismissReportAsAdmin('uuid-1');
      await repository.replyAsAdmin('uuid-1', 'Revisado');
      await repository.delete('uuid-1');

      expect(gateway.sent, [
        (operation: 'setHiddenAsAdmin', id: 'uuid-1', text: 'true'),
        (operation: 'setHiddenAsAdmin', id: 'uuid-1', text: 'false'),
        (operation: 'dismissReportAsAdmin', id: 'uuid-1', text: null),
        (operation: 'replyAsAdmin', id: 'uuid-1', text: 'Revisado'),
        (operation: 'delete', id: 'uuid-1', text: null),
      ]);
    });

    test('un error inesperado al moderar dice qué acción falló', () async {
      gateway.error = StateError('falla');

      await expectLater(
        repository.setHiddenAsAdmin('uuid-1', hidden: true),
        _failsWith('No fue posible actualizar la reseña'),
      );
      await expectLater(
        repository.dismissReportAsAdmin('uuid-1'),
        _failsWith('No fue posible descartar el reporte'),
      );
      await expectLater(
        repository.replyAsAdmin('uuid-1', 'x'),
        _failsWith('No fue posible guardar la respuesta'),
      );
      await expectLater(
        repository.delete('uuid-1'),
        _failsWith('No fue posible eliminar la reseña'),
      );
    });

    group('mensajes de error reales del servidor', () {
      test('un @check rechazado muestra el mensaje del servidor', () async {
        gateway.error = _checkFailed(
          'Solo el propietario del motel puede responder esta reseña '
          '(aborted)\n(rolled back)',
        );

        await expectLater(
          repository.replyAsOwner('uuid-1', 'x'),
          _failsWith(
            'Solo el propietario del motel puede responder esta reseña',
          ),
        );
      });

      test('con varios @check rechazados muestra el primero', () async {
        gateway.error = _checkFailed(
          'La reseña no existe (aborted)\n'
          'Solo el propietario del motel puede reportar esta reseña (aborted)\n'
          '(rolled back)',
        );

        await expectLater(
          repository.reportAsOwner('uuid-1', 'Spam'),
          _failsWith('La reseña no existe'),
        );
      });

      test('el @check de existencia del administrador llega a la UI', () async {
        gateway.error = _checkFailed(
          'La reseña no existe (aborted)\n(rolled back)',
        );

        await expectLater(
          repository.delete('uuid-1'),
          _failsWith('La reseña no existe'),
        );
        await expectLater(
          repository.replyAsAdmin('uuid-1', 'x'),
          _failsWith('La reseña no existe'),
        );
      });

      test(
        'un error de operación que no es un @check usa el genérico',
        () async {
          gateway.error = _checkFailed('internal: database error');

          await expectLater(
            repository.reportAsOwner('uuid-1', 'Spam'),
            _failsWith('No fue posible reportar la reseña'),
          );
        },
      );

      test('sin rol de administrador (HTTP 403) lo dice claramente', () async {
        gateway.error = _httpError(
          403,
          'unauthorized: you are not authorized to perform this operation',
        );
        const reason = 'Solo un administrador puede moderar reseñas';

        await expectLater(
          repository.setHiddenAsAdmin('uuid-1', hidden: true),
          _failsWith(reason),
        );
        await expectLater(
          repository.dismissReportAsAdmin('uuid-1'),
          _failsWith(reason),
        );
        await expectLater(
          repository.replyAsAdmin('uuid-1', 'x'),
          _failsWith(reason),
        );
        await expectLater(repository.delete('uuid-1'), _failsWith(reason));
      });

      test('sin sesión (HTTP 401) pide iniciar sesión', () async {
        gateway.error = _httpError(
          401,
          'unauthenticated: this operation requires a signed-in user',
        );

        await expectLater(
          repository.replyAsOwner('uuid-1', 'x'),
          _failsWith('Debes iniciar sesión para publicar o ver reseñas'),
        );
        await expectLater(
          repository.delete('uuid-1'),
          _failsWith('Debes iniciar sesión para publicar o ver reseñas'),
        );
      });

      test('sin red avisa que no hay conexión', () async {
        gateway.error = _networkError;

        await expectLater(
          repository.getAll(),
          _failsWith('No hay conexión con el servidor de reseñas'),
        );
        await expectLater(
          repository.replyAsOwner('uuid-1', 'x'),
          _failsWith('No hay conexión con el servidor de reseñas'),
        );
      });
    });
  });
}
