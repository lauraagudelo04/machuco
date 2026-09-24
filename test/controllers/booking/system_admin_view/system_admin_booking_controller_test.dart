import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/controllers/booking/system_admin_view/system_admin_booking_controller.dart';
import 'package:machuco/models/booking/booking.dart';

void main() {
  group('SystemAdminBookingController.motelsForOwner', () {
    test('filtra los moteles correctamente por propietario', () async {
      final controller = SystemAdminBookingController();

      final ownerOneMotels = await controller.motelsForOwner(
        'owner-1020304050',
      );
      final ownerTwoMotels = await controller.motelsForOwner('owner-900123456');
      final unknownOwnerMotels = await controller.motelsForOwner(
        'owner-que-no-existe',
      );

      expect(ownerOneMotels.map((m) => m.id).toSet(), {'1', '2'});
      expect(ownerTwoMotels.map((m) => m.id).toSet(), {'3'});
      expect(unknownOwnerMotels, isEmpty);
    });
  });

  group('SystemAdminBookingController.historicalReservationsTotal', () {
    test('un motel con histórico reporta un total mayor a cero', () async {
      final controller = SystemAdminBookingController();

      final total = await controller.historicalReservationsTotal('1');

      expect(total, greaterThan(0));
    });

    test('un motel sin histórico reporta cero sin explotar', () async {
      final controller = SystemAdminBookingController();

      final total = await controller.historicalReservationsTotal('3');

      expect(total, 0);
    });
  });

  group('SystemAdminBookingController.motelKpiSummary', () {
    test('un motel con datos calcula KPIs consistentes con el total '
        'histórico', () async {
      final controller = SystemAdminBookingController();

      final total = await controller.historicalReservationsTotal('1');
      final kpi = await controller.motelKpiSummary('1');

      expect(kpi['totalReservations'], total);
      expect(kpi['city'], 'Rionegro - Zona Rosa');
      expect(kpi['monthlyAverage'], total / 12);
      expect(kpi['averagePerDay'], total / 365);
      expect(
        (kpi['activeReservations'] as int) +
            (kpi['cancelledReservations'] as int),
        lessThanOrEqualTo(total),
      );
      expect(kpi['totalRevenue'], greaterThan(0));
      expect(kpi['occupancyRate'], greaterThanOrEqualTo(0));
      expect(kpi['occupancyRate'], lessThanOrEqualTo(1));
    });

    test('un motel sin histórico da cero/vacío en vez de explotar', () async {
      final controller = SystemAdminBookingController();

      final kpi = await controller.motelKpiSummary('3');

      expect(kpi['totalReservations'], 0);
      expect(kpi['activeReservations'], 0);
      expect(kpi['cancelledReservations'], 0);
      expect(kpi['averagePerDay'], 0);
      expect(kpi['occupancyRate'], 0.0);
      expect(kpi['totalRevenue'], 0);
      expect(kpi['monthlyAverage'], 0);
      expect(kpi['city'], 'Rionegro - Centro');
    });

    test(
      'un motel desconocido no explota y devuelve totales en cero',
      () async {
        final controller = SystemAdminBookingController();

        final kpi = await controller.motelKpiSummary('motel-inexistente');

        expect(kpi['totalReservations'], 0);
        expect(kpi['city'], 'Sin ciudad registrada');
      },
    );
  });

  group('SystemAdminBookingController.reservationsEvolution', () {
    test('siempre devuelve 12 puntos (uno por mes), con o sin datos', () async {
      final controller = SystemAdminBookingController();

      final withData = await controller.reservationsEvolution('1');
      final withoutData = await controller.reservationsEvolution('3');

      expect(withData, hasLength(12));
      expect(withoutData, hasLength(12));
      expect(withoutData.every((point) => point['value'] == 0), isTrue);
    });

    test(
      'la suma de la serie sin filtro coincide con el total histórico',
      () async {
        final controller = SystemAdminBookingController();

        final total = await controller.historicalReservationsTotal('1');
        final evolution = await controller.reservationsEvolution('1');
        final sum = evolution.fold<int>(
          0,
          (acc, point) => acc + (point['value'] as int),
        );

        expect(sum, total);
      },
    );

    test('filtrar por cada estado reparte exactamente el total sin filtro '
        '(partición completa por estado)', () async {
      final controller = SystemAdminBookingController();

      final totalSum = (await controller.reservationsEvolution(
        '1',
      )).fold<int>(0, (acc, point) => acc + (point['value'] as int));

      var sumByStatus = 0;
      for (final status in ReservationStatus.values) {
        final evolution = await controller.reservationsEvolution(
          '1',
          status: status,
        );
        sumByStatus += evolution.fold<int>(
          0,
          (acc, point) => acc + (point['value'] as int),
        );
      }

      expect(sumByStatus, totalSum);
    });

    test('un motel sin histórico también reparte en cero por estado', () async {
      final controller = SystemAdminBookingController();

      final evolution = await controller.reservationsEvolution(
        '3',
        status: ReservationStatus.completed,
      );

      expect(evolution, hasLength(12));
      expect(evolution.every((point) => point['value'] == 0), isTrue);
    });
  });

  group('SystemAdminBookingController.paymentBreakdownByMethod', () {
    test(
      'totaliza correctamente monto y cantidad por método de pago',
      () async {
        final controller = SystemAdminBookingController();

        final breakdown = await controller.paymentBreakdownByMethod('1');
        final byMethod = (breakdown['byMethod'] as List)
            .cast<Map<String, dynamic>>();

        final sumAmount = byMethod.fold<int>(
          0,
          (acc, entry) => acc + (entry['total'] as int),
        );
        final sumCount = byMethod.fold<int>(
          0,
          (acc, entry) => acc + (entry['count'] as int),
        );

        expect(breakdown['totalAmount'], sumAmount);
        expect(breakdown['totalCount'], sumCount);
        expect(breakdown['totalAmount'], greaterThan(0));

        // El desglose debe venir ordenado de mayor a menor monto.
        for (var i = 0; i < byMethod.length - 1; i++) {
          expect(
            byMethod[i]['total'] as int,
            greaterThanOrEqualTo(byMethod[i + 1]['total'] as int),
          );
        }
      },
    );

    test('el monto total pagado coincide con los ingresos totales del KPI '
        '(misma regla de "reserva pagada")', () async {
      final controller = SystemAdminBookingController();

      final kpi = await controller.motelKpiSummary('2');
      final breakdown = await controller.paymentBreakdownByMethod('2');

      expect(breakdown['totalAmount'], kpi['totalRevenue']);
    });

    test('un motel sin histórico no tiene pagos que desglosar', () async {
      final controller = SystemAdminBookingController();

      final breakdown = await controller.paymentBreakdownByMethod('3');

      expect(breakdown['totalAmount'], 0);
      expect(breakdown['totalCount'], 0);
      expect(breakdown['byMethod'], isEmpty);
    });
  });

  group('SystemAdminBookingController carga de pantallas', () {
    test('loadOwnerMotels puebla motels y kpiFor tras cargar', () async {
      final controller = SystemAdminBookingController();

      final future = controller.loadOwnerMotels('owner-1020304050');
      expect(controller.isLoading, isTrue);
      await future;

      expect(controller.isLoading, isFalse);
      expect(controller.motels, isNotEmpty);
      expect(controller.kpiFor('1'), isNotNull);
    });

    test(
      'loadOwnerMotels con simulateError expone un mensaje de error',
      () async {
        final controller = SystemAdminBookingController();

        await controller.loadOwnerMotels(
          'owner-1020304050',
          simulateError: true,
        );

        expect(controller.errorMessage, isNotNull);
        expect(controller.isOffline, isFalse);
      },
    );

    test('loadOwnerMotels con simulateOffline marca isOffline', () async {
      final controller = SystemAdminBookingController();

      await controller.loadOwnerMotels(
        'owner-1020304050',
        simulateOffline: true,
      );

      expect(controller.isOffline, isTrue);
      expect(controller.errorMessage, isNull);
    });

    test('loadMotelDashboard puebla selectedMotel, historicalTotal, '
        'evolution y paymentBreakdown', () async {
      final controller = SystemAdminBookingController();

      await controller.loadMotelDashboard('1');

      expect(controller.selectedMotel?.id, '1');
      expect(controller.historicalTotal, greaterThan(0));
      expect(controller.evolution, hasLength(12));
      expect(controller.paymentBreakdown['totalAmount'], isNotNull);
    });

    test(
      'applyEvolutionStatusFilter recalcula solo la serie de evolución',
      () async {
        final controller = SystemAdminBookingController();
        await controller.loadMotelDashboard('1');
        final totalBefore = controller.historicalTotal;

        await controller.applyEvolutionStatusFilter(
          '1',
          ReservationStatus.cancelled,
        );

        final cancelledSum = controller.evolution.fold<int>(
          0,
          (acc, point) => acc + (point['value'] as int),
        );
        expect(cancelledSum, lessThanOrEqualTo(totalBefore));
        // No repite la carga completa: el total histórico no cambia.
        expect(controller.historicalTotal, totalBefore);
      },
    );
  });
}
