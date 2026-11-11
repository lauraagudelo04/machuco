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
        recipientUid: 'laura-firebase-uid',
      );

      final lauraNotifications = await repository.findNotificationsForRecipient(
        'laura-firebase-uid',
        role: 'client',
      );
      final camiloNotifications = await repository
          .findNotificationsForRecipient('camilo-firebase-uid', role: 'client');

      expect(lauraNotifications.map((item) => item.id), [specificId, allId]);
      expect(camiloNotifications.map((item) => item.id), [allId]);

      await repository.markAsRead(
        notificationId: allId,
        userId: 'laura-firebase-uid',
      );
      await repository.markAsRead(
        notificationId: allId,
        userId: 'laura-firebase-uid',
      );

      expect(await repository.findReadNotificationIds('laura-firebase-uid'), {
        allId,
      });
      expect(
        await repository.findReadNotificationIds('camilo-firebase-uid'),
        isEmpty,
      );
    },
  );

  test('filtra los avisos masivos por rol', () async {
    await repository.saveNotification(
      typeId: 1,
      title: 'Clientes',
      message: 'Solo clientes',
      target: NotificationTarget.clients,
    );
    await repository.saveNotification(
      typeId: 1,
      title: 'Propietarios',
      message: 'Solo propietarios',
      target: NotificationTarget.owners,
    );

    expect(
      (await repository.findNotificationsForRecipient(
        'client-1',
        role: 'client',
      )).map((notification) => notification.title),
      ['Clientes'],
    );
    expect(
      (await repository.findNotificationsForRecipient(
        'owner-1',
        role: 'owner',
      )).map((notification) => notification.title),
      ['Propietarios'],
    );
  });

  test(
    'actualiza la misma fila cuando se reintenta con el mismo remoteId',
    () async {
      final firstId = await repository.saveNotification(
        typeId: 1,
        title: 'Mantenimiento',
        message: 'El sistema tendrá mantenimiento.',
        target: NotificationTarget.specificUser,
        recipientUid: 'client-1',
        recipientName: 'Laura Gómez',
        recipientEmail: 'laura@example.com',
        remoteId: 'manual-stable-id',
        syncState: 'pending',
      );
      final retryId = await repository.saveNotification(
        typeId: 1,
        title: 'Mantenimiento',
        message: 'El sistema tendrá mantenimiento.',
        target: NotificationTarget.specificUser,
        recipientUid: 'client-1',
        recipientName: 'Laura Gómez',
        recipientEmail: 'laura@example.com',
        remoteId: 'manual-stable-id',
      );

      final notifications = await repository.findAllNotifications();
      expect(retryId, firstId);
      expect(notifications, hasLength(1));
      expect(notifications.single.remoteId, 'manual-stable-id');
      expect(notifications.single.syncState, 'synced');
      expect(notifications.single.recipientName, 'Laura Gómez');
    },
  );
}
