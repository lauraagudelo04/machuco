import 'package:machuco/models/review/review.dart';
import 'package:sqflite/sqflite.dart';

/// Copia local de las reseñas en SQLite, para mostrarlas sin conexión.
///
/// Usa su propia tabla `review_cache` y la crea la primera vez que se usa,
/// como `RoomDao`. Así no cambia la versión compartida de `AppDatabase` ni
/// necesita una migración de Floor.
class ReviewDao {
  ReviewDao(this._openDatabase);

  final Future<Database> Function() _openDatabase;

  /// Reemplaza toda la copia por [reviews].
  Future<void> replaceAll(List<Review> reviews) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await transaction.delete(_table);
      for (final review in reviews) {
        await transaction.insert(_table, _toRow(review));
      }
    });
  }

  /// Las reseñas guardadas, de la más reciente a la más antigua.
  Future<List<Review>> findAll() async {
    final rows = await (await _database).query(_table, orderBy: 'date DESC');
    return rows.map(_fromRow).toList();
  }

  /// La base con la tabla lista. `CREATE TABLE IF NOT EXISTS` no hace nada
  /// si ya existe, así que es seguro llamarlo en cada operación.
  Future<Database> get _database async {
    final database = await _openDatabase();
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id TEXT PRIMARY KEY,
        author_id TEXT NOT NULL,
        author_name TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        rating INTEGER NOT NULL,
        date INTEGER NOT NULL,
        motel_id TEXT NOT NULL,
        room_id TEXT,
        type_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        report_reason TEXT,
        admin_reply TEXT,
        owner_reply TEXT
      )
    ''');
    return database;
  }
}

const _table = 'review_cache';

Map<String, Object?> _toRow(Review review) => {
  'id': review.id,
  'author_id': review.authorId,
  'author_name': review.authorName,
  'title': review.title,
  'body': review.body,
  'rating': review.rating,
  'date': review.date.millisecondsSinceEpoch,
  'motel_id': review.motelId,
  'room_id': review.roomId,
  'type_id': review.type.id,
  'status': review.status.name,
  'report_reason': review.reportReason,
  'admin_reply': review.adminReply,
  'owner_reply': review.ownerReply,
};

/// Un tipo o estado desconocido no rompe la lista: se usa `motel` y
/// `visible`, igual que al leer de SQL Connect.
Review _fromRow(Map<String, Object?> row) => Review(
  id: row['id']! as String,
  authorId: row['author_id']! as String,
  authorName: row['author_name']! as String,
  title: row['title']! as String,
  body: row['body']! as String,
  rating: row['rating']! as int,
  date: DateTime.fromMillisecondsSinceEpoch(row['date']! as int, isUtc: true),
  motelId: row['motel_id']! as String,
  roomId: row['room_id'] as String?,
  type: ReviewType.fromId(row['type_id']! as int) ?? ReviewType.motel,
  status:
      ReviewModerationStatus.values.asNameMap()[row['status']] ??
      ReviewModerationStatus.visible,
  reportReason: row['report_reason'] as String?,
  adminReply: row['admin_reply'] as String?,
  ownerReply: row['owner_reply'] as String?,
);
