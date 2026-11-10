import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/auth_routes.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/database/model/auth/auth_user_profile_entry.dart';
import 'package:machuco/database/repository/auth/auth_catalog_repository.dart';
import 'package:machuco/database/repository/auth/auth_user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _colombia = CountryPhoneCode(
  id: 1,
  isoCode: 'CO',
  countryName: 'Colombia',
  dialCode: '+57',
  phoneMinLength: 10,
  phoneMaxLength: 10,
);

void main() {
  late AuthPreferences preferences;
  late InMemoryAuthUserProfileRepository cache;
  late _FakeAuthService auth;
  late _ManualTimers timers;

  LoginController buildController({AuthCatalogRepository? catalog}) =>
      LoginController(
        authService: auth,
        preferences: preferences,
        catalogRepository: catalog,
        profileCache: cache,
        timerFactory: timers.create,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    preferences = AuthPreferences(
      preferences: SharedPreferencesLocalService(namespace: 'auth'),
    );
    cache = InMemoryAuthUserProfileRepository();
    auth = _FakeAuthService();
    timers = _ManualTimers();
  });

  group('ruta posterior al login', () {
    test('propietario pendiente va a la revisión de cuenta', () {
      final controller = buildController();
      final route = controller.resolvePostLoginRoute(
        _session(
          RegisteredUserRole.owner,
          status: AccountStatus.pendingApproval,
        ),
      );
      expect(route, AuthRoutes.accountReview);
      expect(AuthRoutes.accountReview, '/auth/account-review');
    });

    test('las cuentas activas conservan su ruta por rol', () {
      final controller = buildController();
      expect(
        controller.resolvePostLoginRoute(_session(RegisteredUserRole.client)),
        AppRoutes.clientMotels,
      );
      expect(
        controller.resolvePostLoginRoute(_session(RegisteredUserRole.owner)),
        AppRoutes.ownerMotels,
      );
      expect(
        controller.resolvePostLoginRoute(_session(RegisteredUserRole.admin)),
        AppRoutes.ownerManagement,
      );
    });

    test('constantes de rutas de administración', () {
      expect(AuthRoutes.adminOwnerApprovals, '/auth/admin/owner-approvals');
      expect(
        AuthRoutes.adminOwnerApprovalDetail,
        '/auth/admin/owner-approvals/detail',
      );
      expect(AuthRoutes.adminAdministrators, '/auth/admin/administrators');
    });
  });

  group('perfil en SQLite', () {
    test('se guarda al iniciar sesión y reemplaza al anterior', () async {
      final controller = buildController();
      auth.nextSession = _session(
        RegisteredUserRole.client,
        status: AccountStatus.active,
        uid: 'a',
      );
      await controller.login(email: 'a@example.com', password: 'secret123');
      expect((await controller.loadCachedProfile())?.uid, 'a');

      auth.nextSession = _session(
        RegisteredUserRole.client,
        status: AccountStatus.active,
        uid: 'b',
      );
      await controller.login(email: 'b@example.com', password: 'secret123');
      expect((await controller.loadCachedProfile())?.uid, 'b');
    });

    test('no guarda NIT ni fecha de nacimiento', () async {
      final controller = buildController();
      auth.nextSession = _session(
        RegisteredUserRole.owner,
        status: AccountStatus.active,
        profile: UserProfile(
          uid: 'o1',
          fullName: 'Luz Mora',
          email: 'luz@example.com',
          phoneNumber: '+573001234567',
          role: RegisteredUserRole.owner,
          accountStatus: AccountStatus.active,
          firstNames: 'Luz',
          lastNames: 'Mora',
          personType: PersonType.juridica,
          nit: '900123456-8',
          companyName: 'Moteles SAS',
          birthDate: DateTime.utc(1990, 1, 1),
        ),
      );
      await controller.login(email: 'luz@example.com', password: 'secret123');

      final entry = await controller.loadCachedProfile();
      expect(entry?.companyName, 'Moteles SAS');
      expect(entry?.firstNames, 'Luz');
      expect(entry?.role, 'owner');
      expect(entry?.accountStatus, 'active');
      final text = [
        entry?.uid,
        entry?.email,
        entry?.firstNames,
        entry?.lastNames,
        entry?.phoneNumber,
        entry?.companyName,
        entry?.syncedAt,
      ].join('|');
      expect(text, isNot(contains('900123456')));
      expect(text, isNot(contains('1990')));
    });

    test('un perfil sin datos de Firestore usa los de la sesión', () async {
      final controller = buildController();
      auth.nextSession = _session(RegisteredUserRole.client);
      await controller.login(email: 'ana@example.com', password: 'secret123');
      expect((await controller.loadCachedProfile())?.email, 'ana@example.com');
    });

    test('se guarda al restaurar la sesión', () async {
      final controller = buildController();
      auth.restored = _session(RegisteredUserRole.client, uid: 'r1');
      await controller.restoreSession();
      expect((await controller.loadCachedProfile())?.uid, 'r1');
    });

    test('se borra al cerrar sesión', () async {
      final controller = buildController();
      auth.nextSession = _session(RegisteredUserRole.client);
      await controller.login(email: 'ana@example.com', password: 'secret123');
      await controller.logout();
      expect(await controller.loadCachedProfile(), isNull);
    });

    test('se borra si la sesión no se restaura', () async {
      final controller = buildController();
      auth.nextSession = _session(RegisteredUserRole.client);
      await controller.login(email: 'ana@example.com', password: 'secret123');
      auth.restored = null;
      await controller.restoreSession();
      expect(await controller.loadCachedProfile(), isNull);
    });

    test('se borra si el login revela una cuenta deshabilitada', () async {
      final controller = buildController();
      auth.nextSession = _session(RegisteredUserRole.client);
      await controller.login(email: 'ana@example.com', password: 'secret123');

      auth.loginFailure = const AuthFailure(
        AuthFailureType.accountDisabled,
        'Deshabilitada',
      );
      await expectLater(
        controller.login(email: 'ana@example.com', password: 'secret123'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.type,
            'type',
            AuthFailureType.accountDisabled,
          ),
        ),
      );
      expect(await controller.loadCachedProfile(), isNull);
    });

    test('un error de red al restaurar conserva el perfil', () async {
      final controller = buildController();
      auth.nextSession = _session(RegisteredUserRole.client);
      await controller.login(email: 'ana@example.com', password: 'secret123');
      auth.restoreFailure = const AuthFailure(AuthFailureType.network, 'red');
      await expectLater(
        controller.restoreSession(),
        throwsA(isA<AuthFailure>()),
      );
      expect(await controller.loadCachedProfile(), isNotNull);
    });

    test(
      'un fallo del almacenamiento local no impide iniciar sesión',
      () async {
        final controller = LoginController(
          authService: auth,
          profileCache: _ThrowingProfileCache(),
        );
        auth.nextSession = _session(RegisteredUserRole.client);
        final session = await controller.login(
          email: 'ana@example.com',
          password: 'secret123',
        );
        expect(session.email, 'ana@example.com');
        expect(await controller.loadCachedProfile(), isNull);
      },
    );
  });

  group('recuperación de contraseña', () {
    test('inicia un enfriamiento de 60 s que baja cada segundo', () async {
      final controller = buildController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.requestPasswordReset(email: ' Ana@Example.com ');

      expect(auth.resetEmails, ['ana@example.com']);
      expect(controller.resetCooldownSeconds, 60);
      final before = notifications;
      timers.tick();
      expect(controller.resetCooldownSeconds, 59);
      expect(notifications, before + 1);
      for (var i = 0; i < 59; i++) {
        timers.tick();
      }
      expect(controller.resetCooldownSeconds, 0);
      expect(timers.active, isFalse);
    });

    test('durante el enfriamiento no vuelve a llamar al backend', () async {
      final controller = buildController();
      await controller.requestPasswordReset(email: 'ana@example.com');

      await expectLater(
        controller.requestPasswordReset(email: 'ana@example.com'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.type,
            'type',
            AuthFailureType.tooManyRequests,
          ),
        ),
      );
      expect(auth.resetEmails, hasLength(1));

      for (var i = 0; i < 60; i++) {
        timers.tick();
      }
      await controller.requestPasswordReset(email: 'ana@example.com');
      expect(auth.resetEmails, hasLength(2));
    });

    test('ignora un segundo envío mientras el primero está en curso', () async {
      final controller = buildController();
      final gate = Completer<void>();
      auth.resetGate = gate;

      final first = controller.requestPasswordReset(email: 'ana@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isRequestingPasswordReset, isTrue);
      await controller.requestPasswordReset(email: 'ana@example.com');
      expect(auth.resetEmails, hasLength(1));

      gate.complete();
      await first;
      expect(controller.isRequestingPasswordReset, isFalse);
    });

    test('too-many-requests de Firebase también activa la espera', () async {
      final controller = buildController();
      auth.resetFailure = const AuthFailure(
        AuthFailureType.tooManyRequests,
        'Demasiados intentos',
      );
      await expectLater(
        controller.requestPasswordReset(email: 'ana@example.com'),
        throwsA(isA<AuthFailure>()),
      );
      expect(controller.resetCooldownSeconds, 60);
    });

    test(
      'un error distinto no activa el enfriamiento (permite reintentar)',
      () async {
        final controller = buildController();
        auth.resetFailure = const AuthFailure(
          AuthFailureType.network,
          'sin red',
        );
        await expectLater(
          controller.requestPasswordReset(email: 'ana@example.com'),
          throwsA(isA<AuthFailure>()),
        );
        expect(controller.resetCooldownSeconds, 0);
        expect(controller.isRequestingPasswordReset, isFalse);
      },
    );

    test(
      'rechaza un correo con formato inválido sin llamar al backend',
      () async {
        final controller = buildController();
        await expectLater(
          controller.requestPasswordReset(email: "' OR '1'='1' --"),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.type,
              'type',
              AuthFailureType.invalidInput,
            ),
          ),
        );
        expect(auth.resetEmails, isEmpty);
      },
    );

    test('dispose cancela el temporizador', () async {
      final controller = buildController();
      await controller.requestPasswordReset(email: 'ana@example.com');
      expect(timers.active, isTrue);
      controller.dispose();
      expect(timers.active, isFalse);
    });
  });

  group('registro por rol', () {
    Future<LoginController> readyController() async {
      final controller = buildController(
        catalog: _FakeCatalogRepository(preferences),
      );
      await controller.loadCountryPhoneCodes();
      return controller;
    }

    RegistrationData client({String phone = '300 123 4567'}) =>
        RegistrationData.client(
          firstNames: '  Ana María ',
          lastNames: 'Pérez',
          phoneCountryCodeId: 1,
          phoneNumber: phone,
          email: ' Ana@Example.COM ',
          password: 'secreto123',
          birthDate: DateTime(1990, 5, 20),
        );

    test('cliente: normaliza y envía el celular con indicativo', () async {
      final controller = await readyController();

      await controller.registerAccount(client());

      final sent = auth.registered.single;
      expect(sent.role, RegisteredUserRole.client);
      expect(sent.email, 'ana@example.com');
      expect(sent.firstNames, 'Ana María');
      expect(sent.phoneNumber, '+573001234567');
      expect(sent.phoneCountryCodeId, 1);
      expect(await preferences.loadLastCountryCodeId(), 1);
    });

    test('propietario jurídico: NIT canónico y razón social', () async {
      final controller = await readyController();

      await controller.registerAccount(
        RegistrationData.owner(
          firstNames: 'Luz',
          lastNames: 'Mora',
          phoneCountryCodeId: 1,
          phoneNumber: '3001234567',
          email: 'luz@example.com',
          password: 'secreto123',
          personType: PersonType.juridica,
          nit: '9001234568',
          companyName: '  Moteles del Sur S.A.S. ',
          planId: 2,
        ),
      );

      final sent = auth.registered.single;
      expect(sent.role, RegisteredUserRole.owner);
      expect(sent.nit, '900123456-8');
      expect(sent.companyName, 'Moteles del Sur S.A.S.');
      expect(sent.planId, 2);
    });

    test('propietario natural ignora la razón social', () {
      final data = RegistrationData.owner(
        firstNames: 'Luz',
        lastNames: 'Mora',
        phoneCountryCodeId: 1,
        phoneNumber: '3001234567',
        email: 'luz@example.com',
        password: 'secreto123',
        personType: PersonType.natural,
        nit: '1020304050-8',
        companyName: 'No aplica',
        planId: 1,
      );
      expect(data.companyName, isNull);
    });

    Future<void> expectInvalid(
      LoginController controller,
      RegistrationData data,
    ) async {
      await expectLater(
        controller.registerAccount(data),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.type,
            'type',
            AuthFailureType.invalidInput,
          ),
        ),
      );
      expect(auth.registered, isEmpty);
    }

    test('rechaza datos inválidos sin llamar al backend', () async {
      final controller = await readyController();
      await expectInvalid(controller, client(phone: '12345'));
      await expectInvalid(controller, client(phone: "' OR '1'='1' --"));
      await expectInvalid(
        controller,
        RegistrationData.client(
          firstNames: "Robert'); DROP TABLE users;--",
          lastNames: 'Pérez',
          phoneCountryCodeId: 1,
          phoneNumber: '3001234567',
          email: 'ana@example.com',
          password: 'secreto123',
          birthDate: DateTime(1990, 5, 20),
        ),
      );
      await expectInvalid(
        controller,
        RegistrationData.client(
          firstNames: 'Ana',
          lastNames: 'Pérez',
          phoneCountryCodeId: 1,
          phoneNumber: '3001234567',
          email: 'ana@example.com',
          password: 'secreto123',
          birthDate: DateTime.now(),
        ),
      );
      await expectInvalid(
        controller,
        RegistrationData.owner(
          firstNames: 'Luz',
          lastNames: 'Mora',
          phoneCountryCodeId: 1,
          phoneNumber: '3001234567',
          email: 'luz@example.com',
          password: 'secreto123',
          personType: PersonType.juridica,
          nit: '900123456-7',
          companyName: 'Moteles SAS',
          planId: 1,
        ),
      );
      await expectInvalid(
        controller,
        RegistrationData.owner(
          firstNames: 'Luz',
          lastNames: 'Mora',
          phoneCountryCodeId: 1,
          phoneNumber: '3001234567',
          email: 'luz@example.com',
          password: 'secreto123',
          personType: PersonType.juridica,
          nit: '900123456-8',
          planId: 1,
        ),
      );
    });

    test('rechaza un indicativo que no está en el maestro', () async {
      final controller = await readyController();
      await expectInvalid(
        controller,
        RegistrationData.client(
          firstNames: 'Ana',
          lastNames: 'Pérez',
          phoneCountryCodeId: 999,
          phoneNumber: '3001234567',
          email: 'ana@example.com',
          password: 'secreto123',
          birthDate: DateTime(1990, 5, 20),
        ),
      );
    });

    test('un fallo del servicio se propaga y libera isSubmitting', () async {
      final controller = await readyController();
      auth.registerFailure = const AuthFailure(
        AuthFailureType.emailAlreadyExists,
        'Ya existe',
      );
      await expectLater(
        controller.registerAccount(client()),
        throwsA(isA<AuthFailure>()),
      );
      expect(controller.isSubmitting, isFalse);
    });
  });

  group('eliminación de cuenta', () {
    test('exige escribir ELIMINAR y una contraseña', () async {
      final controller = buildController();
      for (final text in ['', 'eliminar', 'ELIMINA', 'BORRAR']) {
        await expectLater(
          controller.deleteAccount(
            password: 'x1234567',
            confirmationText: text,
          ),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.type,
              'type',
              AuthFailureType.invalidInput,
            ),
          ),
        );
      }
      await expectLater(
        controller.deleteAccount(password: '', confirmationText: 'ELIMINAR'),
        throwsA(isA<AuthFailure>()),
      );
      expect(auth.deletedWithPasswords, isEmpty);
    });

    test(
      'éxito: limpia SQLite y todo el namespace auth, conserva maestros',
      () async {
        final catalog = _FakeCatalogRepository(preferences);
        final controller = buildController(catalog: catalog);
        await controller.loadCountryPhoneCodes();
        auth.nextSession = _session(RegisteredUserRole.client);
        await controller.login(email: 'ana@example.com', password: 'secret123');
        await preferences.saveLastCountryCodeId(1);
        // Otro módulo con namespace propio no debe verse afectado.
        final other = SharedPreferencesLocalService(namespace: 'bookings');
        await other.setString('draft', 'x');

        await controller.deleteAccount(
          password: 'secret123',
          confirmationText: ' ELIMINAR ',
        );

        expect(auth.deletedWithPasswords, ['secret123']);
        expect(controller.session, isNull);
        expect(controller.currentUserEmail, isNull);
        expect(await cache.loadCurrent(), isNull);
        expect(await preferences.loadCurrentUserEmail(), isNull);
        expect(await preferences.loadLastCountryCodeId(), isNull);
        expect(await other.getString('draft'), 'x');
        expect(controller.countryPhoneCodes, isNotEmpty);
        expect(controller.isDeletingAccount, isFalse);
      },
    );

    test('si el backend falla no borra nada local', () async {
      final controller = buildController();
      auth.nextSession = _session(RegisteredUserRole.client);
      await controller.login(email: 'ana@example.com', password: 'secret123');
      auth.deleteFailure = const AuthFailure(
        AuthFailureType.invalidCredentials,
        'Contraseña incorrecta',
      );

      await expectLater(
        controller.deleteAccount(
          password: 'mala-clave',
          confirmationText: 'ELIMINAR',
        ),
        throwsA(isA<AuthFailure>()),
      );

      expect(controller.session, isNotNull);
      expect(await cache.loadCurrent(), isNotNull);
      expect(await preferences.loadCurrentUserEmail(), 'ana@example.com');
      expect(controller.isDeletingAccount, isFalse);
    });

    test('ignora un segundo intento mientras hay uno en curso', () async {
      final controller = buildController();
      final gate = Completer<void>();
      auth.deleteGate = gate;
      final first = controller.deleteAccount(
        password: 'secret123',
        confirmationText: 'ELIMINAR',
      );
      await Future<void>.delayed(Duration.zero);
      await controller.deleteAccount(
        password: 'secret123',
        confirmationText: 'ELIMINAR',
      );
      expect(auth.deletedWithPasswords, hasLength(1));
      gate.complete();
      await first;
    });
  });

  group('planes de suscripción', () {
    test('se cargan desde el repositorio', () async {
      final controller = buildController(
        catalog: _FakeCatalogRepository(preferences),
      );
      await controller.loadSubscriptionPlans();
      expect(controller.subscriptionPlans, const [
        SubscriptionPlanOption(id: 1, name: 'Básico'),
        SubscriptionPlanOption(id: 2, name: 'Premium'),
      ]);
      expect(controller.subscriptionPlansError, isNull);
      expect(controller.isLoadingSubscriptionPlans, isFalse);
    });

    test('un error se expone y permite reintentar', () async {
      final catalog = _FakeCatalogRepository(preferences, failPlans: true);
      final controller = buildController(catalog: catalog);
      await controller.loadSubscriptionPlans();
      expect(controller.subscriptionPlans, isEmpty);
      expect(controller.subscriptionPlansError, isNotNull);

      catalog.failPlans = false;
      await controller.loadSubscriptionPlans(forceRefresh: true);
      expect(controller.subscriptionPlans, hasLength(2));
      expect(controller.subscriptionPlansError, isNull);
    });

    test('sin repositorio informa que no están disponibles', () async {
      final controller = buildController();
      await controller.loadSubscriptionPlans();
      expect(controller.subscriptionPlansError, isNotNull);
    });
  });
}

AuthSession _session(
  RegisteredUserRole role, {
  AccountStatus status = AccountStatus.active,
  String uid = 'user-1',
  UserProfile? profile,
}) => AuthSession(
  userId: uid,
  name: 'Ana',
  email: 'ana@example.com',
  role: role,
  accessToken: 'access',
  idToken: 'header.payload.signature',
  accountStatus: status,
  profile: profile,
);

final class _FakeAuthService implements AuthService {
  AuthSession nextSession = _session(RegisteredUserRole.client);
  AuthSession? restored;
  AuthFailure? loginFailure;
  AuthFailure? restoreFailure;
  AuthFailure? resetFailure;
  AuthFailure? registerFailure;
  AuthFailure? deleteFailure;
  Completer<void>? resetGate;
  Completer<void>? deleteGate;
  final resetEmails = <String>[];
  final registered = <RegistrationData>[];
  final deletedWithPasswords = <String>[];

  @override
  Future<AuthSession?> restoreSession() async {
    final failure = restoreFailure;
    if (failure != null) throw failure;
    return restored;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final failure = loginFailure;
    if (failure != null) throw failure;
    return nextSession;
  }

  @override
  Future<AuthSession> loginWithGoogle({bool preferSignup = false}) async =>
      nextSession;

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required RegisteredUserRole role,
  }) async {}

  @override
  Future<void> registerAccount(RegistrationData data) async {
    final failure = registerFailure;
    if (failure != null) throw failure;
    registered.add(data);
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    resetEmails.add(email);
    await resetGate?.future;
    final failure = resetFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount({required String password}) async {
    deletedWithPasswords.add(password);
    await deleteGate?.future;
    final failure = deleteFailure;
    if (failure != null) {
      deletedWithPasswords.remove(password);
      throw failure;
    }
  }
}

final class _FakeCatalogRepository extends AuthCatalogRepository {
  _FakeCatalogRepository(AuthPreferences preferences, {this.failPlans = false})
    : super(supabaseUrl: '', publishableKey: '', preferences: preferences);

  bool failPlans;

  @override
  Future<List<CountryPhoneCode>> getCountryPhoneCodes({
    bool forceRefresh = false,
  }) async => const [_colombia];

  @override
  Future<List<SubscriptionPlanOption>> getSubscriptionPlans({
    bool forceRefresh = false,
  }) async {
    if (failPlans) {
      throw const AuthCatalogRepositoryException('sin conexión');
    }
    return const [
      SubscriptionPlanOption(id: 1, name: 'Básico'),
      SubscriptionPlanOption(id: 2, name: 'Premium'),
    ];
  }
}

final class _ThrowingProfileCache implements AuthUserProfileRepository {
  @override
  Future<void> saveCurrent(UserProfile profile) async =>
      throw StateError('disco lleno');

  @override
  Future<AuthUserProfileEntry?> loadCurrent() async =>
      throw StateError('disco lleno');

  @override
  Future<void> clear() async => throw StateError('disco lleno');
}

/// Temporizador manual: el test decide cuándo transcurre cada segundo.
final class _ManualTimers {
  void Function(Timer)? _callback;
  _ManualTimer? _timer;

  bool get active => _timer?.isActive ?? false;

  Timer create(Duration period, void Function(Timer) callback) {
    _callback = callback;
    return _timer = _ManualTimer();
  }

  void tick() {
    final timer = _timer;
    if (timer == null || !timer.isActive) return;
    _callback?.call(timer);
  }
}

final class _ManualTimer implements Timer {
  bool _active = true;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}
