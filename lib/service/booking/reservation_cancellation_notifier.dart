import 'package:flutter/foundation.dart';

import 'package:machuco/database/repository/notification/notification_repository.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/notification/notification_model.dart';
import 'package:machuco/utils/date_formatter.dart';

/// Tells the guest that the motel cancelled their reservation.
///
/// Returns `true` only when the notification was actually stored. It never
/// throws for delivery problems: a cancellation is already persisted when
/// this runs, so a failed notification must not undo or hide it.
abstract class ReservationCancellationNotifier {
  Future<bool> notifyCancelled(Reservation reservation);
}

/// Default notifier when no notification backend is wired (tests, demo
/// without database): it notifies nobody and reports so.
class NoopReservationCancellationNotifier
    implements ReservationCancellationNotifier {
  const NoopReservationCancellationNotifier();

  @override
  Future<bool> notifyCancelled(Reservation reservation) async => false;
}

/// Stores the cancellation as a `reservation` notification for the guest
/// through the shared notification module ([NotificationRepository]).
///
/// The recipient is the reservation's `guestId` (Firebase uid with a
/// session), the same identity the owner notification view already uses.
/// Notifications are local to the device: they do not travel to the guest's
/// phone until the notification module gets a remote store.
class NotificationRepositoryCancellationNotifier
    implements ReservationCancellationNotifier {
  NotificationRepositoryCancellationNotifier({
    NotificationRepository? repository,
  }) : _repository = repository ?? NotificationRepository();

  static const String reservationTypeCode = 'reservation';
  static const String title = 'Reserva cancelada';

  final NotificationRepository _repository;

  @override
  Future<bool> notifyCancelled(Reservation reservation) async {
    final recipient = reservation.guestId.trim();
    if (recipient.isEmpty) return false;
    try {
      final types = await _repository.findTypes();
      final type = types
          .where((type) => type.code == reservationTypeCode)
          .firstOrNull;
      if (type == null) return false;
      await _repository.saveNotification(
        typeId: type.id,
        title: title,
        message: _messageFor(reservation),
        target: NotificationTarget.specificUser,
        recipientUid: recipient,
      );
      return true;
    } catch (error) {
      debugPrint(
        'No se pudo notificar la cancelación ${reservation.id}: $error',
      );
      return false;
    }
  }

  static String _messageFor(Reservation reservation) {
    final reason = reservation.cancellationReason?.trim();
    final buffer = StringBuffer(
      'Tu reserva en ${reservation.motelName} '
      '(${reservation.roomName}, habitación ${reservation.roomNumber}) '
      'para el ${formatDateTimeLabel(reservation.checkIn)} fue cancelada '
      'por el motel.',
    );
    if (reason != null && reason.isNotEmpty) buffer.write(' Motivo: $reason.');
    return buffer.toString();
  }
}

/// Shared notifier instance, swapped in `main.dart` like the other
/// providers, so widget tests keep the [NoopReservationCancellationNotifier].
class ReservationCancellationNotifierProvider {
  ReservationCancellationNotifierProvider._();

  static ReservationCancellationNotifier instance =
      const NoopReservationCancellationNotifier();

  static void useNotificationRepository() {
    instance = NotificationRepositoryCancellationNotifier();
  }
}
