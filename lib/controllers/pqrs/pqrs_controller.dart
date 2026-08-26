import 'package:flutter/foundation.dart';
import 'package:machuco/models/pqrs/pqrs.dart';

/// Client the client view acts as while there is no session layer.
const pqrsCurrentClientId = 'c-ana';

/// Motel the owner view acts as while there is no session layer.
const pqrsCurrentMotelId = 'm-aurora';

/// Simulated PQRS data covering every status and both traceability actors.
List<PqrsRequest> pqrsMockRequests() {
  final now = DateTime.now();
  DateTime ago(int days, {int hours = 0}) =>
      now.subtract(Duration(days: days, hours: hours));

  return [
    PqrsRequest(
      id: 'pqrs-001',
      motelId: pqrsCurrentMotelId,
      motelName: 'Motel Aurora',
      clientId: pqrsCurrentClientId,
      clientName: 'Ana Pérez',
      type: PqrsType.queja,
      subject: 'Ruido en la habitación 204',
      description:
          'Durante mi estadía hubo ruido excesivo proveniente del pasillo durante toda la noche.',
      createdAt: ago(6),
      status: PqrsStatus.inProgress,
      attachments: [
        PqrsAttachment.simulated(
          author: PqrsActor.client,
          label: 'pasillo-204.jpg',
          capturedAt: ago(6),
          seed: 11,
        ),
      ],
      trace: [
        PqrsTraceEntry(
          id: 'pqrs-001-t1',
          author: PqrsActor.owner,
          message:
              'Recibimos tu queja. Enviamos personal de mantenimiento a revisar el aislamiento del pasillo.',
          createdAt: ago(5, hours: 20),
          statusChange: PqrsStatus.inProgress,
        ),
        PqrsTraceEntry(
          id: 'pqrs-001-t2',
          author: PqrsActor.owner,
          message: 'Instalamos burletes en las puertas del pasillo. Adjuntamos el avance.',
          createdAt: ago(3),
          attachments: [
            PqrsAttachment.simulated(
              author: PqrsActor.owner,
              label: 'avance-burletes.jpg',
              capturedAt: ago(3),
              seed: 24,
            ),
          ],
        ),
        PqrsTraceEntry(
          id: 'pqrs-001-t3',
          author: PqrsActor.client,
          message: 'Gracias, sigo atenta. Aún se escucha algo desde la habitación contigua.',
          createdAt: ago(2),
        ),
      ],
    ),
    PqrsRequest(
      id: 'pqrs-002',
      motelId: pqrsCurrentMotelId,
      motelName: 'Motel Aurora',
      clientId: pqrsCurrentClientId,
      clientName: 'Ana Pérez',
      type: PqrsType.reclamo,
      subject: 'Cobro duplicado del servicio adicional',
      description:
          'Me cobraron dos veces el servicio de limpieza adicional en la factura del 12 de agosto.',
      createdAt: ago(9),
      status: PqrsStatus.resolved,
      trace: [
        PqrsTraceEntry(
          id: 'pqrs-002-t1',
          author: PqrsActor.owner,
          message: 'Verificamos la factura con el área de pagos.',
          createdAt: ago(8, hours: 18),
          statusChange: PqrsStatus.inProgress,
        ),
        PqrsTraceEntry(
          id: 'pqrs-002-t2',
          author: PqrsActor.owner,
          message:
              'Confirmamos el cobro duplicado y aplicamos la devolución. Adjuntamos el soporte.',
          createdAt: ago(4),
          attachments: [
            PqrsAttachment.simulated(
              author: PqrsActor.owner,
              label: 'soporte-devolucion.jpg',
              capturedAt: ago(4),
              seed: 37,
            ),
          ],
          statusChange: PqrsStatus.resolved,
        ),
      ],
    ),
    PqrsRequest(
      id: 'pqrs-003',
      motelId: pqrsCurrentMotelId,
      motelName: 'Motel Aurora',
      clientId: 'c-luis',
      clientName: 'Luis Gómez',
      type: PqrsType.peticion,
      subject: 'Solicitud de factura electrónica',
      description: 'Necesito la factura electrónica de mi reserva del 2 de agosto.',
      createdAt: ago(1, hours: 4),
      status: PqrsStatus.pending,
    ),
    PqrsRequest(
      id: 'pqrs-004',
      motelId: pqrsCurrentMotelId,
      motelName: 'Motel Aurora',
      clientId: pqrsCurrentClientId,
      clientName: 'Ana Pérez',
      type: PqrsType.sugerencia,
      subject: 'Ampliar el horario de recepción',
      description: 'Sería útil contar con recepción disponible las 24 horas.',
      createdAt: ago(21),
      status: PqrsStatus.closed,
      trace: [
        PqrsTraceEntry(
          id: 'pqrs-004-t1',
          author: PqrsActor.owner,
          message: 'Evaluamos la propuesta con el equipo de operaciones.',
          createdAt: ago(20),
          statusChange: PqrsStatus.inProgress,
        ),
        PqrsTraceEntry(
          id: 'pqrs-004-t2',
          author: PqrsActor.owner,
          message: 'Ampliamos la recepción hasta las 2:00 a. m. desde este mes.',
          createdAt: ago(16),
          statusChange: PqrsStatus.resolved,
        ),
        PqrsTraceEntry(
          id: 'pqrs-004-t3',
          author: PqrsActor.client,
          message: 'Excelente, la solución cubre lo que necesitaba. Cierro la solicitud.',
          createdAt: ago(15),
          statusChange: PqrsStatus.closed,
        ),
      ],
    ),
    PqrsRequest(
      id: 'pqrs-005',
      motelId: 'm-eclipse',
      motelName: 'Motel Eclipse',
      clientId: 'c-marta',
      clientName: 'Marta Ruiz',
      type: PqrsType.queja,
      subject: 'Aire acondicionado sin funcionar',
      description: 'El aire acondicionado de la habitación 108 no encendió durante la noche.',
      createdAt: ago(12),
      status: PqrsStatus.rejected,
      trace: [
        PqrsTraceEntry(
          id: 'pqrs-005-t1',
          author: PqrsActor.owner,
          message:
              'Revisamos el equipo y estaba operativo; el control remoto se encontraba sin baterías.',
          createdAt: ago(11),
          statusChange: PqrsStatus.rejected,
        ),
      ],
    ),
    PqrsRequest(
      id: 'pqrs-006',
      motelId: 'm-eclipse',
      motelName: 'Motel Eclipse',
      clientId: 'c-jorge',
      clientName: 'Jorge Salas',
      type: PqrsType.reclamo,
      subject: 'Demora en el check-in',
      description: 'Esperé cuarenta minutos para recibir la llave de la habitación.',
      createdAt: ago(2, hours: 6),
      status: PqrsStatus.inProgress,
      trace: [
        PqrsTraceEntry(
          id: 'pqrs-006-t1',
          author: PqrsActor.owner,
          message: 'Estamos reforzando el turno de recepción los fines de semana.',
          createdAt: ago(2),
          statusChange: PqrsStatus.inProgress,
        ),
      ],
    ),
    PqrsRequest(
      id: 'pqrs-007',
      motelId: 'm-eclipse',
      motelName: 'Motel Eclipse',
      clientId: 'c-marta',
      clientName: 'Marta Ruiz',
      type: PqrsType.sugerencia,
      subject: 'Incluir opción de pago con QR',
      description: 'Facilitaría el pago al momento del check-out.',
      createdAt: ago(30),
      status: PqrsStatus.closed,
      trace: [
        PqrsTraceEntry(
          id: 'pqrs-007-t1',
          author: PqrsActor.owner,
          message: 'Habilitamos pago con QR en recepción.',
          createdAt: ago(27),
          statusChange: PqrsStatus.resolved,
        ),
        PqrsTraceEntry(
          id: 'pqrs-007-t2',
          author: PqrsActor.client,
          message: 'Ya lo probé y funciona. Cierro la solicitud.',
          createdAt: ago(26),
          statusChange: PqrsStatus.closed,
        ),
      ],
    ),
  ];
}

/// In-memory PQRS repository shared by the client, owner and system
/// administrator views.
///
/// It is a [ChangeNotifier] so the three views stay in sync with plain Flutter
/// state management: a widget listens with `ListenableBuilder` and rebuilds
/// whenever a request changes. There is no backend yet, so the data is seeded
/// from [pqrsMockRequests].
class PqrsController extends ChangeNotifier {
  PqrsController.seeded(List<PqrsRequest> requests) : _requests = List.of(requests);

  /// Shared instance used by the views while there is no dependency injection.
  static final PqrsController instance = PqrsController.seeded(pqrsMockRequests());

  final List<PqrsRequest> _requests;

  /// All requests, newest first.
  List<PqrsRequest> get all => List.unmodifiable(_requests);

  List<PqrsRequest> byMotel(String motelId) =>
      _requests.where((request) => request.motelId == motelId).toList();

  List<PqrsRequest> byClient(String clientId) =>
      _requests.where((request) => request.clientId == clientId).toList();

  PqrsRequest byId(String requestId) =>
      _requests.firstWhere((request) => request.id == requestId);

  /// Distinct motels present in the data, for the administrator selector.
  List<({String id, String name})> get motels {
    final seen = <String, String>{};
    for (final request in _requests) {
      seen[request.motelId] = request.motelName;
    }
    return [for (final entry in seen.entries) (id: entry.key, name: entry.value)];
  }

  /// Registers a new request opened by a client.
  PqrsRequest createRequest({
    required String motelId,
    required String motelName,
    required String clientId,
    required String clientName,
    required PqrsType type,
    required String subject,
    required String description,
    List<PqrsAttachment> attachments = const [],
  }) {
    final request = PqrsRequest(
      id: 'pqrs-${DateTime.now().microsecondsSinceEpoch}',
      motelId: motelId,
      motelName: motelName,
      clientId: clientId,
      clientName: clientName,
      type: type,
      subject: subject,
      description: description,
      createdAt: DateTime.now(),
      attachments: attachments,
    );
    _requests.insert(0, request);
    notifyListeners();
    return request;
  }

  /// Appends a comment with optional photos.
  ///
  /// The first owner answer moves a pending request to
  /// [PqrsStatus.inProgress]; a client comment never changes the status.
  void addUpdate({
    required String requestId,
    required PqrsActor author,
    required String message,
    List<PqrsAttachment> attachments = const [],
  }) {
    final request = _mutable(requestId);
    final movesToInProgress =
        author == PqrsActor.owner && request.status == PqrsStatus.pending;

    _append(
      request,
      PqrsTraceEntry(
        id: _entryId(),
        author: author,
        message: message,
        createdAt: DateTime.now(),
        attachments: attachments,
        statusChange: movesToInProgress ? PqrsStatus.inProgress : null,
      ),
      status: movesToInProgress ? PqrsStatus.inProgress : null,
    );
  }

  /// The owner proposes a solution and waits for the client to confirm it.
  void markResolved({
    required String requestId,
    required String message,
    List<PqrsAttachment> attachments = const [],
  }) {
    final request = _mutable(requestId);
    if (request.status == PqrsStatus.resolved) {
      throw StateError('La solicitud ${request.id} ya está marcada como solucionada.');
    }

    _append(
      request,
      PqrsTraceEntry(
        id: _entryId(),
        author: PqrsActor.owner,
        message: message,
        createdAt: DateTime.now(),
        attachments: attachments,
        statusChange: PqrsStatus.resolved,
      ),
      status: PqrsStatus.resolved,
    );
  }

  /// The owner rejects the request, stating the reason.
  void reject({required String requestId, required String message}) {
    final request = _mutable(requestId);
    _append(
      request,
      PqrsTraceEntry(
        id: _entryId(),
        author: PqrsActor.owner,
        message: message,
        createdAt: DateTime.now(),
        statusChange: PqrsStatus.rejected,
      ),
      status: PqrsStatus.rejected,
    );
  }

  /// The client confirms the solution and closes the request.
  ///
  /// Only the client closes a PQRS, and only after the owner proposed a
  /// solution.
  void closeByClient({required String requestId, required String message}) {
    final request = _mutable(requestId);
    if (!request.canBeClosedByClient) {
      throw StateError(
        'Solo se puede cerrar una solicitud solucionada; '
        'la solicitud ${request.id} está en estado ${request.status.name}.',
      );
    }

    _append(
      request,
      PqrsTraceEntry(
        id: _entryId(),
        author: PqrsActor.client,
        message: message,
        createdAt: DateTime.now(),
        statusChange: PqrsStatus.closed,
      ),
      status: PqrsStatus.closed,
    );
  }

  /// Returns the request only when it still accepts changes.
  PqrsRequest _mutable(String requestId) {
    final request = byId(requestId);
    if (request.status.isFinal) {
      throw StateError(
        'La solicitud ${request.id} está ${request.status.name} '
        'y no admite más actualizaciones.',
      );
    }
    return request;
  }

  void _append(PqrsRequest request, PqrsTraceEntry entry, {PqrsStatus? status}) {
    final index = _requests.indexWhere((item) => item.id == request.id);
    _requests[index] = request.copyWith(
      status: status,
      trace: [...request.trace, entry],
    );
    notifyListeners();
  }

  String _entryId() => 'trace-${DateTime.now().microsecondsSinceEpoch}';
}
