import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/notification/notification_repository.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/notification/notification_model.dart';
import 'package:machuco/repositories/booking/booking_seed_data.dart';
import 'package:machuco/service/booking/reservation_cancellation_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late AppDatabase database;
  late http.Client client;
  late String typesBody;

  NotificationRepository repository() => NotificationRepository(
    database: database,
    client: client,
    supabaseUrl: 'https://example.supabase.co',
    publishableKey: 'publishable-key',
  );

  Reservation cancelledReservation({String guestId = 'Guest-UID-42'}) {
    final seed = buildSeedReservations(DateTime(2026, 11, 10)).first;
    return Reservation(
      id: seed.id,
      requestId: seed.requestId,
      motelId: seed.motelId,
      motelName: seed.motelName,
      roomId: seed.roomId,
      roomName: seed.roomName,
      roomNumber: seed.roomNumber,
      checkIn: seed.checkIn,
      checkOut: seed.checkOut,
      stayMode: seed.stayMode,
      guestCount: seed.guestCount,
      services: seed.services,
      products: seed.products,
      roomTotal: seed.roomTotal,
      total: seed.total,
      status: ReservationStatus.cancelled,
      createdAt: seed.createdAt,
      guestId: guestId,
      guestName: seed.guestName,
      cancellationReason: 'Mantenimiento de la habitación',
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_cancel_notify_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}notifications.db',
    );
    typesBody =
        '[{"id":7,"code":"reservation","name":"Reservas"},'
        '{"id":8,"code":"payment","name":"Pagos"}]';
    client = MockClient((_) async => http.Response(typesBody, 200));
  });

  tearDown(() async {
    client.close();
    await database.close();
    await directory.delete(recursive: true);
  });

  group('NotificationRepositoryCancellationNotifier', () {
    test('guarda una notificación de tipo reserva para el huésped', () async {
      final reservation = cancelledReservation();
      final notifier = NotificationRepositoryCancellationNotifier(
        repository: repository(),
      );

      final notified = await notifier.notifyCancelled(reservation);

      expect(notified, isTrue);
      final saved = await repository().findNotificationsForRecipient(
        'Guest-UID-42',
        role: 'client',
      );
      expect(saved, hasLength(1));
      final entry = saved.single;
      expect(entry.typeId, 7);
      expect(entry.target, NotificationTarget.specificUser.name);
      expect(entry.recipientUid, 'Guest-UID-42');
      expect(entry.title, 'Reserva cancelada');
      expect(entry.message, contains(reservation.motelName));
      expect(entry.message, contains('Mantenimiento de la habitación'));
    });

    test('no guarda nada si el catálogo no tiene el tipo reserva', () async {
      typesBody = '[{"id":8,"code":"payment","name":"Pagos"}]';
      final notifier = NotificationRepositoryCancellationNotifier(
        repository: repository(),
      );

      final notified = await notifier.notifyCancelled(cancelledReservation());

      expect(notified, isFalse);
      expect(await repository().findAllNotifications(), isEmpty);
    });

    test('no guarda nada si la reserva no tiene huésped', () async {
      final notifier = NotificationRepositoryCancellationNotifier(
        repository: repository(),
      );

      final notified = await notifier.notifyCancelled(
        cancelledReservation(guestId: '  '),
      );

      expect(notified, isFalse);
      expect(await repository().findAllNotifications(), isEmpty);
    });

    test('devuelve false sin lanzar si el catálogo no responde', () async {
      client.close();
      client = MockClient((_) async => http.Response('error', 500));
      final notifier = NotificationRepositoryCancellationNotifier(
        repository: repository(),
      );

      final notified = await notifier.notifyCancelled(cancelledReservation());

      expect(notified, isFalse);
      expect(await repository().findAllNotifications(), isEmpty);
    });
  });
}
