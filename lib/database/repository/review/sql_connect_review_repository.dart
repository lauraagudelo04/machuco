import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/database/repository/review/firestore_review_repository.dart';
import 'package:machuco/database/repository/review/review_repository.dart';
import 'package:machuco/database/repository/review/review_sql_connect_gateway.dart';
import 'package:machuco/models/review/review.dart';

/// [ReviewRepository] respaldado por la tabla `reviews` de Firebase SQL
/// Connect (PostgreSQL), conector `review`.
///
/// Solo cubre la funcionalidad de ingresar reseñas: listar ([getAll]) y
/// publicar ([add]). Responder, moderar y eliminar son de las ramas de
/// propietario y administrador, así que [update] y [delete] lanzan
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
  Future<List<Review>> getAll() async {
    try {
      final rows = await _remote.listAll();
      return rows.map(reviewFromSqlConnect).toList();
    } catch (error) {
      throw ReviewRepositoryException(
        _messageFor(error, fallback: 'No fue posible consultar las reseñas'),
      );
    }
  }

  /// Publica [review]. El id, el autor y el estado los asigna el backend.
  @override
  Future<void> add(Review review) async {
    try {
      await _remote.createMine(review);
    } catch (error) {
      throw ReviewRepositoryException(
        _messageFor(error, fallback: 'No fue posible publicar la reseña'),
      );
    }
  }

  @override
  Future<void> update(Review review) async =>
      throw const ReviewRepositoryException(
        'Editar reseñas no está disponible en SQL Connect',
      );

  @override
  Future<void> delete(String id) async => throw const ReviewRepositoryException(
    'Eliminar reseñas no está disponible en SQL Connect',
  );

  static String _messageFor(Object error, {required String fallback}) {
    if (kDebugMode) {
      debugPrint('SqlConnectReviewRepository: ${error.runtimeType}');
    }
    if (error is DataConnectError &&
        error.dataConnectErrorCode == DataConnectErrorCode.unauthorized) {
      return 'Debes iniciar sesión para publicar o ver reseñas';
    }
    if (error is DataConnectError &&
        error.dataConnectErrorCode == DataConnectErrorCode.unavailable) {
      return 'No hay conexión con el servidor de reseñas';
    }
    return fallback;
  }
}

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
