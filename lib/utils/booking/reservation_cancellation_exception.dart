/// Motivo por el que falló un intento de cancelación de reserva. Se modela
/// como excepción (en vez de un booleano) para poder distinguir el caso de
/// "reserva no encontrada" del de "estado no cancelable" del de "motivo
/// vacío", cada uno con su propio mensaje para la UI.
///
/// Compartida entre los controllers de Cliente y Propietario del módulo
/// Bookings para no duplicar el mismo contrato de cancelación.
enum ReservationCancellationError { reasonRequired, notFound, invalidStatus }

class ReservationCancellationException implements Exception {
  const ReservationCancellationException(this.reason);

  final ReservationCancellationError reason;

  String get message => switch (reason) {
    ReservationCancellationError.reasonRequired =>
      'Debes indicar un motivo de cancelación.',
    ReservationCancellationError.notFound => 'No encontramos esa reserva.',
    ReservationCancellationError.invalidStatus =>
      'Solo se pueden cancelar reservas pendientes o próximas.',
  };

  @override
  String toString() => message;
}
