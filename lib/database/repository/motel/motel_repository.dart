import 'package:machuco/models/motel/motel_model.dart';

/// Error de acceso a los datos de moteles, con mensaje en español listo para
/// mostrar al usuario.
class MotelRepositoryException implements Exception {
  const MotelRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Contrato de acceso a los moteles.
///
/// La implementación vigente es `SqlConnectMotelRepository` (Firebase SQL
/// Connect). La autorización por dueño la aplica el backend con el uid del
/// token de Firebase Auth: los métodos "My" nunca reciben el dueño desde la
/// app.
abstract interface class MotelRepository {
  /// Todos los moteles (administrador del sistema).
  Future<List<Motel>> getMotels();

  /// Moteles del propietario autenticado.
  Future<List<Motel>> getMyMotels();

  /// Moteles habilitados.
  Future<List<Motel>> getAvailableMotels();

  Future<Motel?> getMotelById(String id);

  /// El propietario autenticado registra un motel propio.
  Future<Motel> addMyMotel(Motel motel);

  /// El administrador registra un motel para `motel.ownerId`.
  Future<Motel> addMotelForOwner(Motel motel);

  /// El propietario autenticado edita un motel propio.
  Future<Motel> updateMyMotel(Motel motel);

  /// El administrador edita cualquier motel (incluida su disponibilidad).
  Future<Motel> updateMotelAsAdmin(Motel motel);

  /// El propietario autenticado habilita o inhabilita un motel propio.
  Future<void> setMyMotelAvailability(String id, bool isAvailable);
}
