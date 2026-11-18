/// A motel the client can file a PQRS against (display data for the form).
class PqrsMotelOption {
  const PqrsMotelOption({
    required this.id,
    required this.name,
    this.ownerId = '',
  });

  final String id;
  final String name;

  /// Owner of the motel, empty when unknown (options built from reservations,
  /// which do not carry it). Only used for the local copy: the repository
  /// reads the authoritative value from `motels/{id}` when it sends the
  /// request.
  final String ownerId;
}
