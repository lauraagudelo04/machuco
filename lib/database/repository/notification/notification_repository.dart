import 'dart:convert';

import 'package:floor/floor.dart';
import 'package:http/http.dart' as http;
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/notification/notification.dart';
import 'package:machuco/models/notification/notification_model.dart';

@dao
abstract class NotificationDao {
  @Query('SELECT * FROM notifications ORDER BY sentAt DESC, id DESC')
  Future<List<NotificationEntry>> findAll();

  @Query(
    "SELECT * FROM notifications WHERE target = 'all' OR lower(recipientUser) = lower(:recipientUser) ORDER BY sentAt DESC, id DESC",
  )
  Future<List<NotificationEntry>> findForRecipient(String recipientUser);

  @insert
  Future<int> insertNotification(NotificationEntry notification);

  @Query('SELECT notificationId FROM notification_reads WHERE userId = :userId')
  Future<List<int>> findReadNotificationIds(String userId);

  @Query(
    'SELECT * FROM notification_reads WHERE notificationId = :notificationId AND userId = :userId LIMIT 1',
  )
  Future<NotificationRead?> findRead(int notificationId, String userId);

  @insert
  Future<int> insertRead(NotificationRead notificationRead);
}

class NotificationRepositoryException implements Exception {
  const NotificationRepositoryException(this.message);
  final String message;
}

class NotificationRepository {
  NotificationRepository({
    AppDatabase? database,
    http.Client? client,
    String? supabaseUrl,
    String? publishableKey,
  }) : _database = database == null
           ? AppDatabaseProvider.database
           : Future.value(database),
       _get = client?.get ?? http.get,
       _supabaseUrl =
           supabaseUrl ??
           const String.fromEnvironment(
             'SUPABASE_URL',
             defaultValue: 'https://ogrbbuwtsyezegkpwtsl.supabase.co',
           ),
       _publishableKey =
           publishableKey ??
           const String.fromEnvironment(
             'SUPABASE_PUBLISHABLE_KEY',
             defaultValue: 'sb_publishable_Wv16MVxsTzA89lBeocarLQ_YL33Ya_E',
           );

  final Future<AppDatabase> _database;
  final Future<http.Response> Function(Uri, {Map<String, String>? headers})
  _get;
  final String _supabaseUrl;
  final String _publishableKey;

  Future<List<NotificationType>> findTypes() async {
    final base = Uri.tryParse(_supabaseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        _publishableKey.isEmpty) {
      throw const NotificationRepositoryException(
        'La consulta de tipos de notificación no está configurada.',
      );
    }
    final uri = base.replace(
      path: '/rest/v1/notification_types',
      queryParameters: {
        'select': 'id,code,name,description',
        'is_active': 'eq.true',
        'order': 'sort_order.asc',
      },
    );
    late final http.Response response;
    try {
      response = await _get(
        uri,
        headers: {'apikey': _publishableKey, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const NotificationRepositoryException(
        'No se pudo conectar con el catálogo de tipos.',
      );
    }
    if (response.statusCode != 200) {
      throw const NotificationRepositoryException(
        'No se pudieron consultar los tipos de notificación.',
      );
    }
    try {
      final rows = jsonDecode(utf8.decode(response.bodyBytes));
      if (rows is! List) throw const FormatException('Respuesta inválida');
      return rows
          .map((row) => NotificationType.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    } on FormatException {
      throw const NotificationRepositoryException(
        'El catálogo de tipos devolvió datos inválidos.',
      );
    } on TypeError {
      throw const NotificationRepositoryException(
        'El catálogo de tipos devolvió datos inválidos.',
      );
    }
  }

  Future<List<NotificationEntry>> findAllNotifications() async =>
      (await _database).notificationDao.findAll();

  Future<List<NotificationEntry>> findNotificationsForRecipient(
    String recipientUser,
  ) async => (await _database).notificationDao.findForRecipient(
    recipientUser.trim().toLowerCase(),
  );

  Future<Set<int>> findReadNotificationIds(String userId) async =>
      (await _database).notificationDao
          .findReadNotificationIds(userId.trim().toLowerCase())
          .then((ids) => ids.toSet());

  Future<int> saveNotification({
    required int typeId,
    required String title,
    required String message,
    required NotificationTarget target,
    String? recipientUser,
  }) async {
    final normalizedRecipient = recipientUser?.trim().toLowerCase();
    return (await _database).notificationDao.insertNotification(
      NotificationEntry(
        typeId: typeId,
        title: title.trim(),
        message: message.trim(),
        sentAt: DateTime.now(),
        target: target.name,
        recipientUser: normalizedRecipient?.isEmpty ?? true
            ? null
            : normalizedRecipient,
      ),
    );
  }

  Future<void> markAsRead({
    required int notificationId,
    required String userId,
  }) async {
    final normalizedUserId = userId.trim().toLowerCase();
    final dao = (await _database).notificationDao;
    if (await dao.findRead(notificationId, normalizedUserId) != null) return;
    await dao.insertRead(
      NotificationRead(
        notificationId: notificationId,
        userId: normalizedUserId,
        readAt: DateTime.now(),
      ),
    );
  }
}
