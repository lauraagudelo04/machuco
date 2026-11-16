import 'package:machuco/models/review/review.dart';
import 'package:machuco/service/sql_connect/review_connector/review.dart';
import 'package:machuco/service/sql_connect/sql_connect_config.dart';

/// Fila de la tabla `reviews` tal como la devuelve Firebase SQL Connect.
///
/// `status` y `typeId` llegan como texto y número; los traduce a los enums
/// del dominio `SqlConnectReviewRepository`.
typedef SqlConnectReviewRow = ({
  String id,
  String authorId,
  String authorName,
  String title,
  String body,
  int rating,
  String motelId,
  String? roomId,
  int typeId,
  String status,
  String? reportReason,
  String? adminReply,
  String? ownerReply,
  DateTime createdAt,
});

/// Operaciones remotas de reseñas en Firebase SQL Connect (conector `review`).
///
/// Aísla el código generado (`lib/service/sql_connect/review_connector/`) para
/// que `SqlConnectReviewRepository` se pueda probar con un doble.
abstract interface class ReviewSqlConnectGateway {
  /// Todas las reseñas, de la más reciente a la más antigua.
  Future<List<SqlConnectReviewRow>> listAll();

  /// Publica [review] a nombre del usuario con sesión y devuelve el id que
  /// asignó la base. El autor y el estado los fija el backend: se ignoran
  /// `review.id`, `review.authorId` y `review.status`.
  Future<String> createMine(Review review);

  /// Guarda la respuesta del propietario. El servidor la rechaza si la
  /// reseña no es de un motel del usuario con sesión.
  Future<void> replyAsOwner(String id, String reply);

  /// Moderación del administrador. El servidor exige el custom claim
  /// `role: 'admin'`; [status] solo puede ser `visible` o `hidden`.
  Future<void> setStatusAsAdmin(String id, String status);

  Future<void> dismissReportAsAdmin(String id);

  Future<void> replyAsAdmin(String id, String reply);

  Future<void> deleteAsAdmin(String id);
}

/// Implementación con el SDK generado del conector `review`.
class GeneratedReviewSqlConnectGateway implements ReviewSqlConnectGateway {
  GeneratedReviewSqlConnectGateway({ReviewConnector? connector})
    : _connector = connector ?? _sharedConnector();

  final ReviewConnector _connector;

  static ReviewConnector? _shared;

  static ReviewConnector _sharedConnector() {
    final existing = _shared;
    if (existing != null) return existing;
    final connector = ReviewConnector.instance;
    if (SqlConnectConfig.useEmulator) {
      connector.dataConnect.useDataConnectEmulator(
        SqlConnectConfig.emulatorHost,
        SqlConnectConfig.emulatorPort,
      );
    }
    return _shared = connector;
  }

  @override
  Future<List<SqlConnectReviewRow>> listAll() async {
    final result = await _connector.listReviews().execute();
    return [
      for (final r in result.data.reviews)
        (
          id: r.id,
          authorId: r.authorId,
          authorName: r.authorName,
          title: r.title,
          body: r.body,
          rating: r.rating,
          motelId: r.motelId,
          roomId: r.roomId,
          typeId: r.typeId,
          status: r.status,
          reportReason: r.reportReason,
          adminReply: r.adminReply,
          ownerReply: r.ownerReply,
          createdAt: r.createdAt.toDateTime(),
        ),
    ];
  }

  @override
  Future<String> createMine(Review review) async {
    final result = await _connector
        .createMyReview(
          authorName: review.authorName,
          title: review.title,
          body: review.body,
          rating: review.rating,
          motelId: review.motelId,
          typeId: review.type.id,
        )
        .roomId(review.roomId)
        .execute();
    return result.data.review_insert.id;
  }

  @override
  Future<void> replyAsOwner(String id, String reply) async {
    await _connector.replyToReviewAsOwner(id: id, reply: reply).execute();
  }

  @override
  Future<void> setStatusAsAdmin(String id, String status) async {
    await _connector.adminSetReviewStatus(id: id, status: status).execute();
  }

  @override
  Future<void> dismissReportAsAdmin(String id) async {
    await _connector.adminDismissReviewReport(id: id).execute();
  }

  @override
  Future<void> replyAsAdmin(String id, String reply) async {
    await _connector.adminReplyToReview(id: id, reply: reply).execute();
  }

  @override
  Future<void> deleteAsAdmin(String id) async {
    await _connector.adminDeleteReview(id: id).execute();
  }
}
