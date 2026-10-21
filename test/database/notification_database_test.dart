import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/notification/notification_repository.dart';
import 'package:machuco/models/notification/notification_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late AppDatabase database;
  late NotificationRepository repository;
  late http.Client client;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_notification_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}notifications.db',
    );
    client = MockClient((request) async {
      expect(request.url.path, '/rest/v1/notification_types');
      expect(request.url.queryParameters['select'], 'id,code,name,description');
      expect(request.url.queryParameters['is_active'], 'eq.true');
      expect(request.headers['apikey'], 'publishable-key');
      return http.Response(
        '[{"id":1,"code":"reservation","name":"Reservas","description":"Avisos"}]',
        200,
      );
    });
    repository = NotificationRepository(
      database: database,
      client: client,
      supabaseUrl: 'https://example.supabase.co',
      publishableKey: 'publishable-key',
    );
  });

  tearDown(() async {
    client.close();
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'consulta los tipos activos desde Supabase sin guardarlos en SQLite',
    () async {
      final types = await repository.findTypes();

      expect(types, hasLength(1));
      expect(types.single.id, 1);
      expect(types.single.code, 'reservation');
      expect(types.single.name, 'Reservas');
    },
  );

  test(
    'persiste destinatarios y conserva lecturas independientes por usuario',
    () async {
      final allId = await repository.saveNotification(
        typeId: 1,
        title: 'Mantenimiento',
        message: 'El sistema tendrá mantenimiento.',
        target: NotificationTarget.all,
      );
      final specificId = await repository.saveNotification(
        typeId: 1,
        title: 'Pago aprobado',
        message: 'Tu pago fue aprobado.',
        target: NotificationTarget.specificUser,
        recipientUser: ' Laura@Machuco.com ',
      );

      final lauraNotifications = await repository.findNotificationsForRecipient(
        'laura@machuco.com',
      );
      final camiloNotifications = await repository
          .findNotificationsForRecipient('camilo@machuco.com');

      expect(lauraNotifications.map((item) => item.id), [specificId, allId]);
      expect(camiloNotifications.map((item) => item.id), [allId]);

      await repository.markAsRead(
        notificationId: allId,
        userId: 'laura@machuco.com',
      );
      await repository.markAsRead(
        notificationId: allId,
        userId: 'laura@machuco.com',
      );

      expect(await repository.findReadNotificationIds('laura@machuco.com'), {
        allId,
      });
      expect(
        await repository.findReadNotificationIds('camilo@machuco.com'),
        isEmpty,
      );
    },
  );
}
