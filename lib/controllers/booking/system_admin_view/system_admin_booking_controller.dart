import 'package:flutter/foundation.dart';

import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_category.dart';
import 'package:machuco/repositories/booking/reservation_category_repository.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/service/booking/booking_service.dart';

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
/// Solo guarda estado de pantalla; los KPIs, la evolución y el desglose de
/// pagos los calcula `BookingService` sobre las mismas reservas compartidas
/// (`BookingRepository`) que ven Cliente y Propietario. El motel `'3'`
/// (Motel Eclipse) se deja deliberadamente sin reservas en el seed para
/// cubrir el escenario "motel sin histórico" del feature.
///
/// Los métodos públicos que representan consultas (`motelsForOwner`,
/// `motelKpiSummary`, `historicalReservationsTotal`,
/// `reservationsEvolution`, `paymentBreakdownByMethod`) son `Future`-based a
/// propósito, aunque hoy resuelven en memoria: así, en la etapa 2 (backend
/// real), su firma no debería tener que cambiar.
class SystemAdminBookingController extends ChangeNotifier {
  SystemAdminBookingController({
    MotelController? motelController,
    ReservationCategoryRepository? categoryRepository,
    BookingService? bookingService,
  }) : _motelController = motelController ?? MotelController(),
       _categoryRepository =
           categoryRepository ?? ReservationCategoryRepositoryProvider.instance,
       _service = bookingService ?? BookingService();

  final MotelController _motelController;
  final ReservationCategoryRepository _categoryRepository;
  final BookingService _service;

  List<ReservationCategory> _categories = const [];

  /// Category catalog cached by [loadMotelDashboard], used to build the
  /// category filter. Empty if the catalog could not be loaded.
  List<ReservationCategory> get categories => List.unmodifiable(_categories);

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

    try {
      final motels = await motelsForOwner(ownerId);
      final kpis = <String, Map<String, dynamic>>{};
      for (final motel in motels) {
        kpis[motel.id] = await motelKpiSummary(motel.id);
      }
      _motels = motels;
      _kpiByMotelId = kpis;
    } catch (_) {
      // A failed query must never look like "no motels".
      _errorMessage =
          'No pudimos cargar los moteles de este propietario. Intenta de '
          'nuevo.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Simula la carga del dashboard detallado de [motelId]: motel
  /// seleccionado, total histórico, evolución mensual (opcionalmente
  /// acotada por [status]) y desglose de pagos por método.
  Future<void> loadMotelDashboard(
    String motelId, {
    ReservationStatus? status,
    int? categoryId,
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

    try {
      _categories = await _categoryRepository.getCategories();
    } catch (_) {
      // The category filter is optional: the dashboard loads without it.
      _categories = const [];
    }

    try {
      final motel = await _motelController.getMotelById(motelId);
      final total = await historicalReservationsTotal(motelId);
      final series = await reservationsEvolution(
        motelId,
        status: status,
        categoryId: categoryId,
      );
      final payments = await paymentBreakdownByMethod(motelId);
      _selectedMotel = motel;
      _historicalTotal = total;
      _evolution = series;
      _paymentBreakdown = payments;
    } catch (_) {
      // A failed query must never look like "no reservations".
      _errorMessage =
          'No pudimos cargar el dashboard de este motel. Intenta de nuevo.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Recalcula solo la serie de evolución del dashboard ya cargado, para el
  /// filtro interactivo por estado sobre el gráfico. No repite la carga
  /// completa del dashboard (total histórico y pagos no cambian con este
  /// filtro).
  Future<void> applyEvolutionStatusFilter(
    String motelId,
    ReservationStatus? status, {
    int? categoryId,
  }) async {
    _evolution = await reservationsEvolution(
      motelId,
      status: status,
      categoryId: categoryId,
    );
    notifyListeners();
  }

  /// Moteles administrados por [ownerId]. Para el rol Administrador se
  /// apoya en `MotelController.getMotelsByOwnerId`, que ya expone esa
  /// relación de forma reutilizable (no se mockea una relación propia).
  Future<List<Motel>> motelsForOwner(String ownerId) {
    return _motelController.getMotelsByOwnerId(ownerId);
  }

  Future<List<Reservation>> _reservationsOf(String motelId) async {
    final all = await _service.getReservations();
    return _service.filterReservations(all, motelId: motelId);
  }

  /// KPI comparativo de un motel: ciudad, total de reservas, activas,
  /// canceladas, promedio de reservas por día, tasa de ocupación, ingresos
  /// totales y promedio mensual de reservas (usado como KPI básico en el
  /// listado). Todo derivado de las reservas compartidas de ese motel.
  Future<Map<String, dynamic>> motelKpiSummary(String motelId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final motel = await _motelController.getMotelById(motelId);
    final kpis = _service.computeKpis(
      await _reservationsOf(motelId),
      roomCount: motel?.roomCount ?? 0,
    );

    return {
      'city':
          motel?.generalLocation ?? motel?.address ?? 'Sin ciudad registrada',
      'totalReservations': kpis.totalReservations,
      'activeReservations': kpis.activeReservations,
      'cancelledReservations': kpis.cancelledReservations,
      'averagePerDay': kpis.averagePerDay,
      'occupancyRate': kpis.occupancyRate,
      'totalRevenue': kpis.totalRevenue,
      'monthlyAverage': kpis.monthlyAverage,
    };
  }

  /// Total histórico de reservas recibidas por un motel (todos los
  /// estados), para el indicador numérico del dashboard.
  Future<int> historicalReservationsTotal(String motelId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return (await _reservationsOf(motelId)).length;
  }

  /// Serie temporal mensual (últimos 12 meses) con el conteo de reservas de
  /// un motel, opcionalmente filtrada por [status] para el filtro
  /// interactivo del gráfico de evolución.
  Future<List<Map<String, dynamic>>> reservationsEvolution(
    String motelId, {
    ReservationStatus? status,
    int? categoryId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final series = _service.reservationsEvolution(
      await _reservationsOf(motelId),
      status: status,
      categoryId: categoryId,
    );
    return [
      for (final point in series)
        {'label': _monthYearLabel(point.month), 'value': point.count},
    ];
  }

  /// Total y cantidad de reservas pagadas de un motel, agrupadas por
  /// método de pago. Estructura de retorno: `{'totalAmount': int,
  /// 'totalCount': int, 'byMethod': [{'method': String, 'total': int,
  /// 'count': int}, ...]}`, ordenado de mayor a menor monto.
  Future<Map<String, dynamic>> paymentBreakdownByMethod(String motelId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final breakdown = _service.paymentBreakdown(await _reservationsOf(motelId));
    return {
      'totalAmount': breakdown.totalAmount,
      'totalCount': breakdown.totalCount,
      'byMethod': [
        for (final entry in breakdown.byMethod)
          {'method': entry.method, 'total': entry.total, 'count': entry.count},
      ],
    };
  }
}

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
