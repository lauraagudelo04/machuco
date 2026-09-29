import 'package:flutter/foundation.dart';

import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/motel/motel_model.dart';

/// Controlador mock (patrón `ChangeNotifier`, sin backend) para la
/// "Analítica de reservas del sistema" del Administrador.
///
/// El administrador ya llega con un propietario y un motel seleccionados
/// (navegación jerárquica fuera del alcance de esta rama); este controller
/// expone:
/// - El listado de moteles de un propietario con KPIs comparativos
///   (`motelsForOwner` + `motelKpiSummary`).
/// - El dashboard detallado de un motel: total histórico
///   (`historicalReservationsTotal`), evolución mensual filtrable por
///   estado (`reservationsEvolution`) y desglose de pagos por método
///   (`paymentBreakdownByMethod`).
///
/// El dataset (`_dataset`) es `static` y propio de este controller,
/// independiente del de `OwnerBookingController`, siguiendo la nota del
/// feature de que "cada controller mantiene sus propios datos mockeados".
/// Reutiliza los moteles `'1'`/`'2'` de `owner-1020304050` (ya usados por
/// Propietario) para que los datos sean coherentes entre roles, y agrega
/// reservas para el motel `'3'` de otro propietario (`owner-900123456`).
/// El motel `'3'` (Motel Eclipse) se deja deliberadamente sin reservas para
/// cubrir el escenario "motel sin histórico" del feature.
///
/// Los métodos públicos que representan consultas (`motelsForOwner`,
/// `motelKpiSummary`, `historicalReservationsTotal`,
/// `reservationsEvolution`, `paymentBreakdownByMethod`) son `Future`-based a
/// propósito, aunque hoy resuelven en memoria: así, en la etapa 2 (backend
/// real), su firma no debería tener que cambiar.
class SystemAdminBookingController extends ChangeNotifier {
  SystemAdminBookingController({MotelController? motelController})
    : _motelController = motelController ?? MotelController();

  final MotelController _motelController;

  static final _AdminMockDataset _dataset = _buildMockDataset();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isOffline = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;

  // --- Estado cacheado para "listado de moteles de un propietario" ---

  List<Motel> _motels = const [];
  Map<String, Map<String, dynamic>> _kpiByMotelId = const {};

  /// Moteles del propietario cargados por [loadOwnerMotels], cacheados
  /// desde la última llamada exitosa.
  List<Motel> get motels => List.unmodifiable(_motels);

  /// KPI comparativo ya calculado para un motel cacheado por
  /// [loadOwnerMotels]. `null` si ese motel no está en la caché actual.
  Map<String, dynamic>? kpiFor(String motelId) => _kpiByMotelId[motelId];

  // --- Estado cacheado para "dashboard detallado de un motel" ---

  Motel? _selectedMotel;
  int _historicalTotal = 0;
  List<Map<String, dynamic>> _evolution = const [];
  Map<String, dynamic> _paymentBreakdown = const {};

  Motel? get selectedMotel => _selectedMotel;
  int get historicalTotal => _historicalTotal;
  List<Map<String, dynamic>> get evolution => List.unmodifiable(_evolution);
  Map<String, dynamic> get paymentBreakdown =>
      Map.unmodifiable(_paymentBreakdown);

  /// Simula la carga del listado de moteles de [ownerId] junto con su KPI
  /// comparativo, para la pantalla de listado. Igual patrón que
  /// `OwnerBookingController.loadReservations`: expone
  /// `simulateError`/`simulateOffline` para poder demostrar de forma
  /// determinista los 6 estados exigidos a toda pantalla de datos.
  Future<void> loadOwnerMotels(
    String ownerId, {
    bool simulateError = false,
    bool simulateOffline = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _isOffline = false;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (simulateOffline) {
      _isOffline = true;
      _isLoading = false;
      notifyListeners();
      return;
    }
    if (simulateError) {
      _errorMessage =
          'No pudimos cargar los moteles de este propietario. Intenta de '
          'nuevo.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    final motels = await motelsForOwner(ownerId);
    final kpis = <String, Map<String, dynamic>>{};
    for (final motel in motels) {
      kpis[motel.id] = await motelKpiSummary(motel.id);
    }

    _motels = motels;
    _kpiByMotelId = kpis;
    _isLoading = false;
    notifyListeners();
  }

  /// Simula la carga del dashboard detallado de [motelId]: motel
  /// seleccionado, total histórico, evolución mensual (opcionalmente
  /// acotada por [status]) y desglose de pagos por método.
  Future<void> loadMotelDashboard(
    String motelId, {
    ReservationStatus? status,
    bool simulateError = false,
    bool simulateOffline = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _isOffline = false;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (simulateOffline) {
      _isOffline = true;
      _isLoading = false;
      notifyListeners();
      return;
    }
    if (simulateError) {
      _errorMessage =
          'No pudimos cargar el dashboard de este motel. Intenta de nuevo.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _selectedMotel = await _motelController.getMotelById(motelId);
    _historicalTotal = await historicalReservationsTotal(motelId);
    _evolution = await reservationsEvolution(motelId, status: status);
    _paymentBreakdown = await paymentBreakdownByMethod(motelId);

    _isLoading = false;
    notifyListeners();
  }

  /// Recalcula solo la serie de evolución del dashboard ya cargado, para el
  /// filtro interactivo por estado sobre el gráfico. No repite la carga
  /// completa del dashboard (total histórico y pagos no cambian con este
  /// filtro).
  Future<void> applyEvolutionStatusFilter(
    String motelId,
    ReservationStatus? status,
  ) async {
    _evolution = await reservationsEvolution(motelId, status: status);
    notifyListeners();
  }

  /// Moteles administrados por [ownerId]. Para el rol Administrador se
  /// apoya en `MotelController.getMotelsByOwnerId`, que ya expone esa
  /// relación de forma reutilizable (no se mockea una relación propia).
  Future<List<Motel>> motelsForOwner(String ownerId) {
    return _motelController.getMotelsByOwnerId(ownerId);
  }

  /// KPI comparativo de un motel: ciudad, total de reservas, activas,
  /// canceladas, promedio de reservas por día, tasa de ocupación, ingresos
  /// totales y promedio mensual de reservas (usado como KPI básico en el
  /// listado). Todo derivado en memoria de las reservas mockeadas de ese
  /// motel.
  Future<Map<String, dynamic>> motelKpiSummary(String motelId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final motel = await _motelController.getMotelById(motelId);
    final reservations = _dataset.reservations
        .where((reservation) => reservation.motelId == motelId)
        .toList();

    final totalReservations = reservations.length;
    final activeReservations = reservations
        .where(
          (reservation) =>
              reservation.status == ReservationStatus.active ||
              reservation.status == ReservationStatus.upcoming,
        )
        .length;
    final cancelledReservations = reservations
        .where(
          (reservation) => reservation.status == ReservationStatus.cancelled,
        )
        .length;
    final totalRevenue = reservations
        .where((reservation) => _isPaidStatus(reservation.status))
        .fold<int>(0, (sum, reservation) => sum + reservation.total);

    // El dataset mockeado cubre los últimos 12 meses (365 días) y 12 meses
    // exactos, respectivamente, para promedio/día y promedio mensual.
    const historyDays = 365;
    final averagePerDay = totalReservations / historyDays;
    final monthlyAverage = totalReservations / 12;

    // Tasa de ocupación aproximada (decisión de mockeo, documentada aquí
    // porque no hay tracking real de noches-habitación disponibles en esta
    // etapa): proporción de reservas de los últimos 30 días frente al
    // número de habitaciones del motel, acotada a 100%. Si se reemplaza por
    // datos reales, este es el punto a ajustar.
    final now = DateTime.now();
    final reservationsLast30Days = reservations.where((reservation) {
      final daysSinceCheckIn = now.difference(reservation.checkIn).inDays;
      return daysSinceCheckIn >= 0 && daysSinceCheckIn <= 30;
    }).length;
    final roomCount = motel?.roomCount ?? 0;
    final occupancyRate = roomCount == 0
        ? 0.0
        : (reservationsLast30Days / roomCount).clamp(0.0, 1.0);

    return {
      'city':
          motel?.generalLocation ?? motel?.address ?? 'Sin ciudad registrada',
      'totalReservations': totalReservations,
      'activeReservations': activeReservations,
      'cancelledReservations': cancelledReservations,
      'averagePerDay': averagePerDay,
      'occupancyRate': occupancyRate,
      'totalRevenue': totalRevenue,
      'monthlyAverage': monthlyAverage,
    };
  }

  /// Total histórico de reservas recibidas por un motel (todos los
  /// estados), para el indicador numérico del dashboard.
  Future<int> historicalReservationsTotal(String motelId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _dataset.reservations
        .where((reservation) => reservation.motelId == motelId)
        .length;
  }

  /// Serie temporal mensual (últimos 12 meses) con el conteo de reservas de
  /// un motel, opcionalmente filtrada por [status] para el filtro
  /// interactivo del gráfico de evolución.
  Future<List<Map<String, dynamic>>> reservationsEvolution(
    String motelId, {
    ReservationStatus? status,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final now = DateTime.now();
    final months = [
      for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i),
    ];

    final counts = {for (final month in months) _monthKey(month): 0};
    final reservations = _dataset.reservations.where(
      (reservation) =>
          reservation.motelId == motelId &&
          (status == null || reservation.status == status),
    );
    for (final reservation in reservations) {
      final key = _monthKey(reservation.checkIn);
      if (counts.containsKey(key)) {
        counts[key] = counts[key]! + 1;
      }
    }

    return [
      for (final month in months)
        {'label': _monthYearLabel(month), 'value': counts[_monthKey(month)]!},
    ];
  }

  /// Total y cantidad de reservas pagadas de un motel, agrupadas por
  /// método de pago. Estructura de retorno: `{'totalAmount': int,
  /// 'totalCount': int, 'byMethod': [{'method': String, 'total': int,
  /// 'count': int}, ...]}`, ordenado de mayor a menor monto.
  Future<Map<String, dynamic>> paymentBreakdownByMethod(String motelId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final reservations = _dataset.reservations.where(
      (reservation) => reservation.motelId == motelId,
    );

    final totalsByMethod = <String, int>{};
    final countsByMethod = <String, int>{};
    var totalAmount = 0;
    var totalCount = 0;

    for (final reservation in reservations) {
      final method = _dataset.paymentMethodByReservationId[reservation.id];
      if (method == null) continue;
      totalsByMethod[method] =
          (totalsByMethod[method] ?? 0) + reservation.total;
      countsByMethod[method] = (countsByMethod[method] ?? 0) + 1;
      totalAmount += reservation.total;
      totalCount++;
    }

    final byMethod =
        totalsByMethod.entries
            .map(
              (entry) => {
                'method': entry.key,
                'total': entry.value,
                'count': countsByMethod[entry.key] ?? 0,
              },
            )
            .toList()
          ..sort((a, b) => (b['total']! as int).compareTo(a['total']! as int));

    return {
      'totalAmount': totalAmount,
      'totalCount': totalCount,
      'byMethod': byMethod,
    };
  }
}

/// Determina si una reserva se considera "pagada" para efectos del
/// desglose de pagos e ingresos totales: activa, próxima o completada (una
/// reserva `pending` aún no se paga, y `cancelled` se asume sin cobro
/// efectivo en este dataset mockeado).
bool _isPaidStatus(ReservationStatus status) =>
    status == ReservationStatus.active ||
    status == ReservationStatus.upcoming ||
    status == ReservationStatus.completed;

String _monthKey(DateTime date) => '${date.year}-${date.month}';

String _monthYearLabel(DateTime date) {
  const monthNames = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final shortYear = (date.year % 100).toString().padLeft(2, '0');
  return '${monthNames[date.month - 1]} $shortYear';
}

/// Dataset mockeado propio de este controller: reservas de varios moteles
/// de distintos propietarios, más el método de pago (mock simple, no forma
/// parte del modelo `Reservation` compartido) de cada reserva pagada.
class _AdminMockDataset {
  const _AdminMockDataset(this.reservations, this.paymentMethodByReservationId);

  final List<Reservation> reservations;
  final Map<String, String> paymentMethodByReservationId;
}

_AdminMockDataset _buildMockDataset() {
  final now = DateTime.now();
  final paymentMethodByReservationId = <String, String>{};
  final reservations = <Reservation>[
    // Motel Paraíso Élite (id '1', owner-1020304050), ya usado por
    // Propietario: se reutiliza el mismo id para coherencia entre roles.
    ..._generateMotelHistory(
      motelId: '1',
      motelName: 'Motel Paraíso Élite',
      roomNumbers: const ['101', '102', '103'],
      baseNightly: 180000,
      baseMonthlyCount: 6,
      now: now,
      paymentMethodByReservationId: paymentMethodByReservationId,
    ),
    // Motel El Edén (id '2', owner-1020304050).
    ..._generateMotelHistory(
      motelId: '2',
      motelName: 'Motel El Edén',
      roomNumbers: const ['201', '202'],
      baseNightly: 200000,
      baseMonthlyCount: 4,
      now: now,
      paymentMethodByReservationId: paymentMethodByReservationId,
    ),
    // Motel Eclipse (id '3', owner-900123456) queda deliberadamente sin
    // reservas: cubre el escenario "Administrador abre el dashboard de un
    // motel sin reservas históricas" del feature.
  ];

  return _AdminMockDataset(reservations, paymentMethodByReservationId);
}

List<Reservation> _generateMotelHistory({
  required String motelId,
  required String motelName,
  required List<String> roomNumbers,
  required int baseNightly,
  required int baseMonthlyCount,
  required DateTime now,
  required Map<String, String> paymentMethodByReservationId,
}) {
  final reservations = <Reservation>[];
  var sequence = 0;

  for (var monthsAgo = 11; monthsAgo >= 0; monthsAgo--) {
    final monthDate = DateTime(now.year, now.month - monthsAgo);
    final countThisMonth = baseMonthlyCount + (monthsAgo % 3 == 0 ? 2 : 0);

    for (var i = 0; i < countThisMonth; i++) {
      sequence++;
      final day = 1 + ((i * 5 + monthsAgo) % 26);
      final checkIn = DateTime(
        monthDate.year,
        monthDate.month,
        day,
        14 + (i % 4),
      );
      final checkOut = checkIn.add(Duration(hours: 3 + (i % 3)));
      final status = _statusForSlot(monthsAgo, i);
      final roomNumber = roomNumbers[i % roomNumbers.length];
      final total = baseNightly + (i % 3) * 15000;
      final id = '$motelId-admin-res-$sequence';

      reservations.add(
        Reservation(
          id: id,
          requestId: '$id-req',
          motelId: motelId,
          motelName: motelName,
          roomId: '$motelId-room-$roomNumber',
          roomName: 'Habitación $roomNumber',
          roomNumber: roomNumber,
          checkIn: checkIn,
          checkOut: checkOut,
          stayMode: StayMode.dateWithHourBlock,
          guestCount: 2,
          services: const [],
          products: const [],
          roomTotal: total,
          total: total,
          status: status,
          createdAt: checkIn.subtract(const Duration(days: 1)),
          guestId: 'guest-$motelId-${i % 5}',
          guestName: _guestNameFor(i),
        ),
      );

      if (_isPaidStatus(status)) {
        paymentMethodByReservationId[id] = _paymentMethodFor(sequence);
      }
    }
  }

  return reservations;
}

ReservationStatus _statusForSlot(int monthsAgo, int index) {
  if (monthsAgo == 0) {
    // Mes actual: mezcla de estados para reflejar reservas en distintas
    // etapas (algunas ya completadas, otras en curso o por pagar).
    const currentMonthCycle = [
      ReservationStatus.completed,
      ReservationStatus.active,
      ReservationStatus.upcoming,
      ReservationStatus.pending,
      ReservationStatus.cancelled,
    ];
    return currentMonthCycle[index % currentMonthCycle.length];
  }
  // Meses pasados: mayormente completadas, con una fracción cancelada.
  return index % 5 == 0
      ? ReservationStatus.cancelled
      : ReservationStatus.completed;
}

String _paymentMethodFor(int sequence) {
  const methods = ['Efectivo', 'Tarjeta', 'Transferencia'];
  return methods[sequence % methods.length];
}

String _guestNameFor(int index) {
  const names = [
    'Camila Restrepo',
    'Julián Gómez',
    'Andrea Salazar',
    'Santiago Marín',
    'Laura Gómez',
  ];
  return names[index % names.length];
}
