import 'package:machuco/models/pqrs/pqrs.dart';

/// Client the client view acts as while there is no session layer.
const pqrsCurrentClientId = 'c-ana';

/// Motel the owner view acts as while there is no session layer.
const pqrsCurrentMotelId = 'm-aurora';

/// In-memory PQRS repository shared by the client, owner and system
/// administrator views.
///
/// It only holds the data; the lifecycle rules and the change notifications
/// live in `PqrsController`. There is no backend yet, so the store is seeded
/// from [defaultRequests].
class PqrsStore {
  PqrsStore({List<PqrsRequest>? requests})
    : requests = List.of(requests ?? defaultRequests);

  /// Shared instance used by the views while there is no dependency injection.
  static final PqrsStore instance = PqrsStore();

  /// Simulated PQRS data covering every status and both traceability actors.
  ///
  /// It cannot be `const` because the dates are relative to `DateTime.now()`,
  /// so a fresh list is built on every read.
  static List<PqrsRequest> get defaultRequests {
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

  /// Every request currently stored, in presentation order.
  final List<PqrsRequest> requests;
}
