import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/database/repository/review/review_repository.dart';
import 'package:machuco/database/repository/review/review_sql_connect_gateway.dart';
import 'package:machuco/models/review/review.dart';

/// [ReviewRepository] respaldado por la tabla `reviews` de Firebase SQL
/// Connect (PostgreSQL), conector `review`.
///
/// Cubre listar ([getAll]), publicar ([add]), la respuesta y el reporte del
/// propietario ([replyAsOwner], [reportAsOwner]) y la moderación del
/// administrador ([setHiddenAsAdmin], [dismissReportAsAdmin],
/// [replyAsAdmin] y [delete]). No hay un [update] genérico porque cada rol
/// solo puede cambiar sus propios campos: [update] lanza
/// [ReviewRepositoryException].
///
/// La autorización (que haya sesión y que el autor sea el usuario del token)
/// la impone `@auth` en `dataconnect/review/`, no esta clase.
///
/// No toca Firebase hasta la primera operación, así crear el controlador no
/// requiere Firebase inicializado (por ejemplo, en pruebas).
class SqlConnectReviewRepository implements ReviewRepository {
  SqlConnectReviewRepository({ReviewSqlConnectGateway? gateway})
    : _gatewayOverride = gateway;

  final ReviewSqlConnectGateway? _gatewayOverride;
  ReviewSqlConnectGateway? _gateway;

  ReviewSqlConnectGateway get _remote =>
      _gateway ??= _gatewayOverride ?? GeneratedReviewSqlConnectGateway();

  /// Devuelve todas las reseñas, de la más reciente a la más antigua.
  @override
  Future<List<Review>> getAll() => _run(() async {
    final rows = await _remote.listAll();
    return rows.map(reviewFromSqlConnect).toList();
  }, fallback: 'No fue posible consultar las reseñas');

  /// Publica [review]. El id, el autor y el estado los asigna el backend.
  @override
  Future<void> add(Review review) => _run(
    () => _remote.createMine(review),
    fallback: 'No fue posible publicar la reseña',
  );

  /// Guarda la respuesta del propietario. Si la reseña no es de uno de sus
  /// moteles, el servidor la rechaza (`@check` en `ReplyToReviewAsOwner`).
  @override
  Future<void> replyAsOwner(String reviewId, String reply) => _run(
    () => _remote.replyAsOwner(reviewId, reply),
    fallback: 'No fue posible guardar la respuesta',
  );

  @override
  Future<void> update(Review review) async =>
      throw const ReviewRepositoryException(
        'Editar reseñas no está disponible en SQL Connect',
      );

  /// Reporta la reseña al administrador. El servidor exige que sea de un
  /// motel del usuario y que esté visible (`ReportReviewAsOwner`).
  @override
  Future<void> reportAsOwner(String reviewId, String reason) => _run(
    () => _remote.reportAsOwner(reviewId, reason),
    fallback: 'No fue posible reportar la reseña',
  );

  @override
  Future<void> setHiddenAsAdmin(String reviewId, {required bool hidden}) =>
      _asAdmin(
        () => _remote.setHiddenAsAdmin(reviewId, hidden: hidden),
        fallback: 'No fue posible actualizar la reseña',
      );

  @override
  Future<void> dismissReportAsAdmin(String reviewId) => _asAdmin(
    () => _remote.dismissReportAsAdmin(reviewId),
    fallback: 'No fue posible descartar el reporte',
  );

  @override
  Future<void> replyAsAdmin(String reviewId, String reply) => _asAdmin(
    () => _remote.replyAsAdmin(reviewId, reply),
    fallback: 'No fue posible guardar la respuesta',
  );

  @override
  Future<void> delete(String id) => _asAdmin(
    () => _remote.delete(id),
    fallback: 'No fue posible eliminar la reseña',
  );

  /// Operación de administrador: el servidor responde 403 si la sesión no
  /// tiene el custom claim `role: 'admin'`.
  Future<void> _asAdmin(
    Future<void> Function() operation, {
    required String fallback,
  }) => _run(
    operation,
    fallback: fallback,
    forbiddenMessage: 'Solo un administrador puede moderar reseñas',
  );

  /// Ejecuta [operation] y convierte cualquier error en
  /// [ReviewRepositoryException] con un mensaje para el usuario.
  Future<T> _run<T>(
    Future<T> Function() operation, {
    required String fallback,
    String? forbiddenMessage,
  }) async {
    try {
      return await operation();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SqlConnectReviewRepository: ${error.runtimeType}');
      }
      throw ReviewRepositoryException(
        _messageFor(
          error,
          fallback: fallback,
          forbiddenMessage: forbiddenMessage,
        ),
      );
    }
  }
}

/// Mensaje para el usuario según cómo arma los errores
/// `firebase_data_connect` 0.4.1:
/// - Un `@check` rechazado llega como [DataConnectOperationError] y se
///   muestra su `message:` del `.gql`.
/// - HTTP 401 (sin sesión) llega como [DataConnectErrorCode.unauthorized].
/// - HTTP 403 (`@auth(expr)` rechazado) y los fallos de red llegan como
///   [DataConnectErrorCode.other]; solo se distinguen por el texto.
///
/// [forbiddenMessage] es lo que se muestra ante un 403; sin él, [fallback].
String _messageFor(
  Object error, {
  required String fallback,
  String? forbiddenMessage,
}) {
  if (error is DataConnectOperationError) {
    return _checkMessage(error) ?? fallback;
  }
  if (error is! DataConnectError) return fallback;
  if (error.dataConnectErrorCode == DataConnectErrorCode.unauthorized) {
    return 'Debes iniciar sesión para publicar o ver reseñas';
  }
  if (_isForbidden(error)) return forbiddenMessage ?? fallback;
  if (_isNetworkFailure(error)) {
    return 'No hay conexión con el servidor de reseñas';
  }
  return fallback;
}

/// El primer `message:` de un `@check` rechazado. El servidor lo envía como
/// `"<mensaje> (aborted)"`, una línea por cada `@check` que falló.
String? _checkMessage(DataConnectOperationError error) {
  final pattern = RegExp(r'^(.+?) \(aborted\)$');
  for (final info in error.response.errors) {
    for (final line in info.message.split('\n')) {
      final match = pattern.firstMatch(line.trim());
      if (match != null) return match.group(1);
    }
  }
  return null;
}

bool _isForbidden(DataConnectError error) =>
    (error.message ?? '').contains('status code of 403');

bool _isNetworkFailure(DataConnectError error) {
  if (error.dataConnectErrorCode == DataConnectErrorCode.unavailable) {
    return true;
  }
  final text = (error.message ?? '').toLowerCase();
  return _networkHints.any((hint) => text.contains(hint));
}

const _networkHints = [
  'socketexception',
  'clientexception',
  'failed host lookup',
  'connection refused',
  'timed out',
];

/// Convierte una fila de SQL Connect en una [Review] del dominio.
///
/// Un estado o tipo desconocido no rompe la lista: se usa `visible` y
/// [ReviewType.motel], igual que al leer de Firestore.
Review reviewFromSqlConnect(SqlConnectReviewRow row) => Review(
  id: row.id,
  authorId: row.authorId,
  authorName: row.authorName,
  title: row.title,
  body: row.body,
  rating: row.rating,
  date: row.createdAt,
  motelId: row.motelId,
  roomId: row.roomId,
  type: ReviewType.fromId(row.typeId) ?? ReviewType.motel,
  status:
      ReviewModerationStatus.values.asNameMap()[row.status] ??
      ReviewModerationStatus.visible,
  reportReason: row.reportReason,
  adminReply: row.adminReply,
  ownerReply: row.ownerReply,
);
