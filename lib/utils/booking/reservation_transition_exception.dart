import 'package:machuco/models/booking/booking.dart';

/// Thrown when a payment related transition (confirm payment, cash payment)
/// is not allowed for the current status of a reservation.
///
/// A missing reservation is reported with the shared
/// `ReservationCancellationException(notFound)` contract instead, so the UI
/// keeps a single "not found" path across every state-changing action.
class ReservationTransitionException implements Exception {
  const ReservationTransitionException(this.from);

  /// Status the reservation had when the transition was rejected.
  final ReservationStatus from;

  String get message => switch (from) {
    ReservationStatus.cancelled =>
      'La reserva está cancelada y ya no admite pagos.',
    ReservationStatus.completed =>
      'La reserva ya fue completada y no admite pagos.',
    ReservationStatus.upcoming ||
    ReservationStatus.active => 'La reserva ya está pagada.',
    ReservationStatus.pending => 'La reserva no admite esta acción ahora.',
  };

  @override
  String toString() => message;
}
