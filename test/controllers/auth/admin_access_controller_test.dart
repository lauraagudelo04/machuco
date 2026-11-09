import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/admin_access_controller.dart';
import 'package:machuco/database/repository/auth/admin_access_repository.dart';
import 'package:machuco/models/auth/owner_approval_request.dart';
import 'package:machuco/models/auth/owner_request_alert.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';

OwnerApplication _owner(
  String uid, {
  String name = 'Luz',
  String nit = '900123456-8',
  int? planId = 1,
}) => OwnerApplication(
  uid: uid,
  firstNames: name,
  lastNames: 'Mora',
  email: '$uid@example.com',
  phoneNumber: '+573001234567',
  personType: PersonType.juridica,
  nit: nit,
  companyName: 'Moteles SAS',
  planId: planId,
  createdAt: DateTime.utc(2026, 11, 1),
);

void main() {
  late InMemoryAdminAccessRepository repository;
  late AdminAccessController controller;

  setUp(() {
    repository = InMemoryAdminAccessRepository([_owner('a'), _owner('b')]);
    controller = AdminAccessController(repository: repository);
  });

  test('carga las solicitudes pendientes y expone el contador', () async {
    final states = <bool>[];
    controller.addListener(() => states.add(controller.isLoading));

    await controller.loadPendingOwners();

    expect(controller.pendingOwners.map((o) => o.uid), ['a', 'b']);
    expect(controller.pendingCount, 2);
    expect(controller.error, isNull);
    expect(controller.isLoading, isFalse);
    expect(states, [true, false]);
    expect(controller.findPending('b')?.fullName, 'Luz Mora');
    expect(controller.findPending('zzz'), isNull);
  });

  test('un error de carga se expone y se puede reintentar', () async {
    repository.failNext = const AdminAccessRepositoryException(
      AdminAccessFailureType.network,
      'No hay conexión.',
    );
    await controller.loadPendingOwners();
    expect(controller.error, 'No hay conexión.');
    expect(controller.pendingOwners, isEmpty);

    await controller.loadPendingOwners();
    expect(controller.error, isNull);
    expect(controller.pendingCount, 2);
  });

  test('un error inesperado no filtra detalles', () async {
    final failing = AdminAccessController(repository: _ThrowingRepository());
    await failing.loadPendingOwners();
    expect(failing.error, isNot(contains('secreto-interno')));
    expect(failing.error, isNotNull);
    expect(failing.isLoading, isFalse);
  });

  test('aprobar quita la solicitud de la lista', () async {
    await controller.loadPendingOwners();

    final ok = await controller.approveOwner('a');

    expect(ok, isTrue);
    expect(repository.approvedUids, ['a']);
    expect(controller.pendingOwners.map((o) => o.uid), ['b']);
    expect(controller.isSubmitting, isFalse);
  });

  test('rechazar exige un motivo de 10 a 300 caracteres', () async {
    await controller.loadPendingOwners();

    expect(await controller.rejectOwner('a', reason: 'corto'), isFalse);
    expect(controller.error, isNotNull);
    expect(repository.rejected, isEmpty);
    expect(controller.pendingCount, 2);

    expect(await controller.rejectOwner('a', reason: 'a' * 301), isFalse);

    final ok = await controller.rejectOwner(
      'a',
      reason: '  El NIT no coincide con el RUT.  ',
    );
    expect(ok, isTrue);
    expect(repository.rejected['a'], 'El NIT no coincide con el RUT.');
    expect(controller.pendingOwners.map((o) => o.uid), ['b']);
    expect(controller.error, isNull);
  });

  test(
    'si otro admin ya la atendió muestra el mensaje y la saca de la lista',
    () async {
      await controller.loadPendingOwners();
      await controller.approveOwner('a');

      final ok = await controller.approveOwner('a');

      expect(ok, isFalse);
      expect(controller.error, 'La solicitud ya fue atendida');
    },
  );

  group('alertas de la solicitud', () {
    // 900123456-8 es un NIT con dígito de verificación válido.
    Future<OwnerRequestAlerts> alertsFor(
      OwnerApplication application, {
      List<SubscriptionPlanOption> plans = const [
        SubscriptionPlanOption(id: 1, name: 'Básico'),
      ],
      Object? planError,
    }) {
      controller = AdminAccessController(
        repository: repository,
        loadPlans: () async {
          if (planError != null) throw planError;
          return plans;
        },
      );
      return controller.loadAlerts(application);
    }

    test('una solicitud correcta no tiene alertas', () async {
      final alerts = await alertsFor(_owner('a'));
      expect(alerts.isEmpty, isTrue);
      expect(controller.alertsFor('a'), same(alerts));
      expect(controller.isCheckingAlerts('a'), isFalse);
    });

    test('dígito de verificación inválido', () async {
      final alerts = await alertsFor(_owner('a', nit: '900123456-9'));
      expect(alerts.has(OwnerRequestAlertType.invalidNitCheckDigit), isTrue);
      expect(alerts.alerts, hasLength(1));
    });

    test('NIT sin formato reconocible', () async {
      final alerts = await alertsFor(_owner('a', nit: 'abc'));
      expect(alerts.has(OwnerRequestAlertType.invalidNitCheckDigit), isTrue);
    });

    test(
      'NIT duplicado en otro propietario, excluyendo al solicitante',
      () async {
        repository.nitOwners['900123456-8'] = {'a', 'otro'};
        expect(
          (await alertsFor(
            _owner('a'),
          )).has(OwnerRequestAlertType.duplicateNit),
          isTrue,
        );

        repository.nitOwners['900123456-8'] = {'a'};
        expect(
          (await alertsFor(
            _owner('a'),
          )).has(OwnerRequestAlertType.duplicateNit),
          isFalse,
        );
      },
    );

    test('plan inexistente o ausente', () async {
      expect(
        (await alertsFor(
          _owner('a'),
          plans: const [SubscriptionPlanOption(id: 9, name: 'Otro')],
        )).has(OwnerRequestAlertType.planNotAvailable),
        isTrue,
      );
      expect(
        (await alertsFor(
          _owner('a', planId: null),
        )).has(OwnerRequestAlertType.planNotAvailable),
        isTrue,
      );
    });

    test('si no se puede comprobar, informa y no lanza', () async {
      repository.failNext = const AdminAccessRepositoryException(
        AdminAccessFailureType.network,
        'sin red',
      );
      final alerts = await alertsFor(_owner('a'), planError: StateError('x'));
      expect(
        alerts.alerts.where(
          (a) => a.type == OwnerRequestAlertType.verificationUnavailable,
        ),
        hasLength(2),
      );
    });

    test('las alertas no bloquean la aprobación', () async {
      repository.nitOwners['900123456-8'] = {'a', 'otro'};
      await controller.loadPendingOwners();
      final alerts = await alertsFor(_owner('a', nit: '900123456-9'));
      expect(alerts.isNotEmpty, isTrue);

      await controller.loadPendingOwners();
      expect(await controller.approveOwner('a'), isTrue);
    });
  });

  test('un fallo de permisos conserva la solicitud', () async {
    await controller.loadPendingOwners();
    repository.failNext = const AdminAccessRepositoryException(
      AdminAccessFailureType.permissionDenied,
      'No tienes permisos para realizar esta operación.',
    );

    final ok = await controller.approveOwner('a');

    expect(ok, isFalse);
    expect(controller.error, contains('permisos'));
    expect(controller.pendingCount, 2);
    controller.clearError();
    expect(controller.error, isNull);
  });
}

final class _ThrowingRepository implements AdminAccessRepository {
  @override
  Future<List<OwnerApplication>> listPendingOwners() async =>
      throw StateError('secreto-interno');

  @override
  Future<void> approveOwner(String uid) async {}

  @override
  Future<void> rejectOwner(String uid, {required String reason}) async {}

  @override
  Future<bool> isNitUsedByAnotherOwner({
    required String nit,
    required String excludeUid,
  }) async => false;
}
