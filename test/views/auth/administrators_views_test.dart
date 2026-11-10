import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/admin_access_controller.dart';
import 'package:machuco/controllers/auth/administrators_controller.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/auth/admin_access_repository.dart';
import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/owner_approval_request.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/password_change_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';
import 'package:machuco/views/admin_access/admin_change_password_page.dart';
import 'package:machuco/widgets/auth/auth_date_format.dart';
import 'package:machuco/views/admin_access/admin_route_guard.dart';
import 'package:machuco/views/admin_access/administrator_detail_page.dart';
import 'package:machuco/views/admin_access/administrators_page.dart';
import 'package:machuco/views/admin_access/create_admin_page.dart';
import 'package:machuco/views/admin_access/owner_approval_detail_page.dart';
import 'package:machuco/views/login/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/auth/administrators_test_support.dart';
import 'auth_test_support.dart';

/// Repositorio que se detiene hasta que la prueba abre la compuerta.
class _GatedRepository extends FakeAdministratorsRepository {
  Completer<void>? listGate;
  Completer<void>? createGate;
  int createRequests = 0;

  @override
  Future<List<UserProfile>> listAdministrators() async {
    await listGate?.future;
    return super.listAdministrators();
  }

  @override
  Future<CreatedAdministrator> createAdministrator(
    NewAdministratorData data,
  ) async {
    createRequests++;
    await createGate?.future;
    return super.createAdministrator(data);
  }
}

class _FakePasswordService implements PasswordChangeService {
  AuthFailure? failure;
  final changed = <String>[];

  @override
  Future<void> changePassword({required String newPassword}) async {
    final f = failure;
    if (f != null) throw f;
    changed.add(newPassword);
  }
}

AdministratorsController _controller(
  FakeAdministratorsRepository repository, {
  PasswordChangeService? passwords,
}) => AdministratorsController(
  repository: repository,
  passwordChangeService: passwords,
  currentUid: () => 'me',
);

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(700, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Abre [page] desde una pantalla anfitriona para poder hacer `pop`.
Future<void> _openFromHost(
  WidgetTester tester,
  Widget page, {
  void Function(Object? result)? onResult,
}) async {
  _bigScreen(tester);
  await tester.pumpWidget(
    testApp(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result = await Navigator.of(
                  context,
                ).push<Object?>(MaterialPageRoute(builder: (_) => page));
                onResult?.call(result);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> _fillCreateForm(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Carlos Andrés');
  await tester.enterText(fields.at(1), 'Rodríguez Pérez');
  await tester.enterText(fields.at(2), '3001234567');
  await tester.enterText(fields.at(3), 'nuevo@example.com');
  await tester.pump();
}

final _me = adminProfile('me', name: 'Ana Admin');
final _other = adminProfile(
  'other',
  name: 'Beto Admin',
  mustChangePassword: true,
);

void main() {
  late FakeAdministratorsRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = FakeAdministratorsRepository()..admins = [_me, _other];
  });

  group('Lista de administradores', () {
    Future<void> pumpList(
      WidgetTester tester,
      AdministratorsController controller,
    ) async {
      _bigScreen(tester);
      await tester.pumpWidget(
        testApp(AdministratorsPage(controller: controller, currentUid: 'me')),
      );
    }

    testWidgets('[AG-01] muestra nombre, correo, estado y "Tú"', (
      tester,
    ) async {
      await pumpList(tester, _controller(repository));
      await tester.pumpAndSettle();

      expect(find.text('Ana Admin'), findsOneWidget);
      expect(find.text('Beto Admin'), findsOneWidget);
      expect(find.text('me@example.com'), findsOneWidget);
      expect(find.text('Tú'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);
      expect(find.text('Pendiente de cambiar contraseña'), findsOneWidget);
      expect(find.text('Crear administrador'), findsOneWidget);
    });

    testWidgets('muestra la carga y luego el contenido', (tester) async {
      final gated = _GatedRepository()
        ..admins = [_me]
        ..listGate = Completer<void>();
      await pumpList(tester, _controller(gated));
      await tester.pump();

      expect(find.bySemanticsLabel('Cargando administradores'), findsOne);
      expect(find.text('Ana Admin'), findsNothing);

      gated.listGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Ana Admin'), findsOneWidget);
    });

    testWidgets('estado vacío', (tester) async {
      repository.admins = [];
      await pumpList(tester, _controller(repository));
      await tester.pumpAndSettle();

      expect(find.text('No hay administradores'), findsOneWidget);
      expect(find.text('Crear administrador'), findsOneWidget);
    });

    testWidgets('[AG-02] error de red con "Reintentar"', (tester) async {
      repository.failList = const AdministratorsRepositoryException(
        AdministratorsFailureType.network,
        'Sin conexión. Revisa tu internet.',
      );
      await pumpList(tester, _controller(repository));
      await tester.pumpAndSettle();

      expect(find.text('Sin conexión. Revisa tu internet.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      repository.failList = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Ana Admin'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('Crear administrador', () {
    late LoginController catalog;
    late AdministratorsController controller;

    setUp(() {
      catalog = buildTestController(FakeAuthService());
      controller = _controller(repository);
    });

    Widget page() => CreateAdminPage(controller: controller, catalog: catalog);

    testWidgets('no pide contraseña ni documento y valida los campos', (
      tester,
    ) async {
      await _openFromHost(tester, page());

      expect(find.text('Contraseña'), findsNothing);
      expect(find.text('Número de celular'), findsOneWidget);
      expect(
        identityDocumentTexts(tester.widgetList<Text>(find.byType(Text))),
        isEmpty,
      );

      await tester.tap(find.text('Crear'));
      await tester.pump();
      expect(repository.calls, isNot(contains('create')));
      expect(find.text('Ingresa tu número de celular.'), findsOneWidget);
    });

    testWidgets('muestra la contraseña temporal una sola vez', (tester) async {
      Object? result;
      await _openFromHost(tester, page(), onResult: (r) => result = r);
      await _fillCreateForm(tester);
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(find.text('Temp-Password-1!'), findsOneWidget);
      expect(find.textContaining('No se volverá a mostrar'), findsOneWidget);
      expect(repository.lastCreate?.phoneNumber, '+573001234567');

      // No se descarta tocando fuera ni con "atrás".
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Temp-Password-1!'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Temp-Password-1!'), findsOneWidget);

      // Copiar usa el portapapeles.
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.text('Copiar contraseña'));
      await tester.pump();
      expect(copied, 'Temp-Password-1!');

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.text('Temp-Password-1!'), findsNothing);
      expect(find.text('Crear administrador'), findsNothing);
    });

    testWidgets('[AG-12] el doble toque crea una sola cuenta', (tester) async {
      final gated = _GatedRepository()..createGate = Completer<void>();
      controller = _controller(gated);
      await _openFromHost(tester, page());
      await _fillCreateForm(tester);

      await tester.tap(find.text('Crear'));
      await tester.pump();
      await tester.tap(find.text('Crear'), warnIfMissed: false);
      await tester.pump();

      expect(gated.createRequests, 1);
      expect(controller.isSubmitting, isTrue);

      gated.createGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Temp-Password-1!'), findsOneWidget);
      expect(gated.calls.where((c) => c == 'create'), hasLength(1));
    });

    testWidgets('correo en uso se señala junto al campo', (tester) async {
      repository.failNext = const AdministratorsRepositoryException(
        AdministratorsFailureType.emailInUse,
        'Ese correo ya está en uso.',
      );
      await _openFromHost(tester, page());
      await _fillCreateForm(tester);
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(find.text('Ese correo ya está en uso.'), findsOneWidget);
      expect(find.text('Temp-Password-1!'), findsNothing);
      expect(find.text('nuevo@example.com'), findsOneWidget);
    });

    testWidgets('error de red conserva lo escrito y permite reintentar', (
      tester,
    ) async {
      repository.failNext = const AdministratorsRepositoryException(
        AdministratorsFailureType.network,
        'Sin conexión. Revisa tu internet.',
      );
      await _openFromHost(tester, page());
      await _fillCreateForm(tester);
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(find.text('Sin conexión. Revisa tu internet.'), findsOneWidget);
      expect(find.text('Carlos Andrés'), findsOneWidget);
      expect(find.text('nuevo@example.com'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Temp-Password-1!'), findsOneWidget);
    });
  });

  group('Detalle y eliminación', () {
    late LoginController catalog;
    late FakeAuthService auth;
    late AdministratorsController controller;

    setUp(() async {
      auth = FakeAuthService();
      catalog = buildTestController(auth);
      controller = _controller(repository);
      await controller.load();
    });

    Widget detail(String uid) => AdministratorDetailPage(
      uid: uid,
      controller: controller,
      currentUid: 'me',
      catalog: catalog,
    );

    testWidgets('muestra datos, fecha de creación y acciones', (tester) async {
      await _openFromHost(tester, detail('other'));

      expect(find.text('Beto Admin'), findsOneWidget);
      expect(find.text('other@example.com'), findsOneWidget);
      expect(
        find.text(formatDate(DateTime.utc(2026, 1, 1).toLocal())),
        findsOneWidget,
      );
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar cuenta'), findsOneWidget);
    });

    testWidgets('editar deja correo y rol de solo lectura', (tester) async {
      await _openFromHost(tester, detail('other'));
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      expect(tester.widget<TextFormField>(fields.at(0)).enabled, isTrue);
      final email = find.byKey(const ValueKey('readonly-email'));
      expect(
        tester
            .widget<TextFormField>(
              find.descendant(of: email, matching: find.byType(TextFormField)),
            )
            .enabled,
        isFalse,
      );

      await tester.enterText(fields.at(0), 'Beto Nuevo');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(repository.calls, contains('update:other'));
      expect(repository.lastChanges?.firstNames, 'Beto Nuevo');
      expect(find.text('Datos actualizados.'), findsOneWidget);
    });

    testWidgets('eliminar a otro exige escribir ELIMINAR', (tester) async {
      Object? result = 'sin cerrar';
      await _openFromHost(tester, detail('other'), onResult: (r) => result = r);
      await tester.tap(find.text('Eliminar cuenta'));
      await tester.pumpAndSettle();

      expect(find.textContaining('correo seguirá ocupado'), findsOneWidget);
      final submit = find.byKey(const ValueKey('delete-administrator-submit'));
      expect(tester.widget<AppButton>(submit).onPressed, isNull);

      await tester.enterText(find.byType(TextFormField), 'ELIMINAR');
      await tester.pump();
      expect(tester.widget<AppButton>(submit).onPressed, isNotNull);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(repository.calls, contains('anonymize:other'));
      expect(result, isNull);
      expect(find.text('Administrador eliminado.'), findsOneWidget);
    });

    testWidgets('lastAdmin informa y no cierra la hoja', (tester) async {
      repository.failNext = const AdministratorsRepositoryException(
        AdministratorsFailureType.lastAdmin,
        'x',
      );
      await _openFromHost(tester, detail('other'));
      await tester.tap(find.text('Eliminar cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'ELIMINAR');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('delete-administrator-submit')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('único administrador activo'), findsOneWidget);
      expect(find.text('Eliminar administrador'), findsOneWidget);
    });

    testWidgets('notFound refresca la lista y cierra el detalle', (
      tester,
    ) async {
      repository.failNext = const AdministratorsRepositoryException(
        AdministratorsFailureType.notFound,
        'Esa cuenta de administrador ya no existe.',
      );
      await _openFromHost(tester, detail('other'));
      final listCalls = repository.calls.where((c) => c == 'list').length;
      await tester.tap(find.text('Eliminar cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'ELIMINAR');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('delete-administrator-submit')),
      );
      await tester.pumpAndSettle();

      expect(repository.calls.where((c) => c == 'list').length, listCalls + 1);
      expect(find.textContaining('ya no existe'), findsOneWidget);
      expect(find.text('Detalle del administrador'), findsNothing);
    });

    testWidgets('la cuenta propia usa la hoja de eliminar cuenta', (
      tester,
    ) async {
      auth.deleteFailure = const AuthFailure(
        AuthFailureType.lastAdministrator,
        'mensaje del servicio',
      );
      await _openFromHost(tester, detail('me'));
      expect(find.text('Ana Admin (Tú)'), findsOneWidget);
      await tester.tap(find.text('Eliminar cuenta'));
      await tester.pumpAndSettle();

      expect(find.textContaining('anonimizará tu cuenta'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Clave-Segura-1');
      await tester.enterText(fields.at(1), 'ELIMINAR');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('delete-account-submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('único administrador activo'), findsOneWidget);
      expect(auth.deletedWithPasswords, isEmpty);
    });
  });

  group('Cambio de contraseña obligatorio', () {
    AuthSession session({required bool mustChange}) => AuthSession(
      userId: 'me',
      name: 'Ana',
      email: 'ana@example.com',
      role: RegisteredUserRole.admin,
      accessToken: 'a',
      idToken: 'i',
      accountStatus: AccountStatus.active,
      profile: adminProfile('me', mustChangePassword: mustChange),
    );

    testWidgets('el guard redirige a cambiar la contraseña', (tester) async {
      var redirected = false;
      await tester.pumpWidget(
        testApp(
          AdminRouteGuard(
            sessionLoader: () async => session(mustChange: true),
            onPasswordChangeRequired: (_) => redirected = true,
            child: const Text('contenido admin'),
          ),
        ),
      );
      // El indicador de verificación nunca se asienta: se usa pump.
      await tester.pump();
      await tester.pump();

      expect(redirected, isTrue);
      expect(find.text('contenido admin'), findsNothing);
    });

    testWidgets('el guard de la propia pantalla no entra en bucle', (
      tester,
    ) async {
      var redirected = false;
      await tester.pumpWidget(
        testApp(
          AdminRouteGuard(
            allowPendingPasswordChange: true,
            sessionLoader: () async => session(mustChange: true),
            onPasswordChangeRequired: (_) => redirected = true,
            child: const Text('pantalla de cambio'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(redirected, isFalse);
      expect(find.text('pantalla de cambio'), findsOneWidget);
    });

    testWidgets('con la contraseña ya cambiada el guard permite entrar', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          AdminRouteGuard(
            sessionLoader: () async => session(mustChange: false),
            child: const Text('contenido admin'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('contenido admin'), findsOneWidget);
    });

    Future<_FakePasswordService> pumpChange(
      WidgetTester tester, {
      VoidCallback? onLogout,
    }) async {
      _bigScreen(tester);
      final passwords = _FakePasswordService();
      await tester.pumpWidget(
        testApp(
          AdminChangePasswordPage(
            homeRoute: '/home',
            controller: _controller(repository, passwords: passwords),
            onLogout: onLogout,
          ),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Text('inicio del admin'),
          ),
        ),
      );
      return passwords;
    }

    Future<void> submitPasswords(WidgetTester tester, String password) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), password);
      await tester.enterText(fields.at(1), password);
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();
    }

    testWidgets('no se abandona con "atrás" y termina en la ruta inicial', (
      tester,
    ) async {
      final passwords = await pumpChange(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Define tu contraseña'), findsOneWidget);

      await submitPasswords(tester, 'Clave-Segura-1');

      expect(passwords.changed, ['Clave-Segura-1']);
      expect(repository.calls, contains('clearMark'));
      expect(find.text('inicio del admin'), findsOneWidget);
    });

    testWidgets('contraseña débil muestra el mensaje y permite reintentar', (
      tester,
    ) async {
      final passwords = await pumpChange(tester);
      passwords.failure = const AuthFailure(
        AuthFailureType.weakPassword,
        'La contraseña es demasiado débil.',
      );
      await submitPasswords(tester, 'Clave-Segura-1');
      expect(find.text('La contraseña es demasiado débil.'), findsOneWidget);
      expect(find.text('inicio del admin'), findsNothing);
    });

    testWidgets('requiresRecentLogin pide volver a iniciar sesión', (
      tester,
    ) async {
      var loggedOut = false;
      final passwords = await pumpChange(
        tester,
        onLogout: () => loggedOut = true,
      );
      passwords.failure = const AuthFailure(
        AuthFailureType.requiresRecentLogin,
        'x',
      );
      await submitPasswords(tester, 'Clave-Segura-1');

      expect(find.textContaining('vuelve a iniciar sesión'), findsOneWidget);
      await tester.tap(find.text('Iniciar sesión de nuevo'));
      expect(loggedOut, isTrue);
    });

    testWidgets('"Cerrar sesión" es la salida permitida', (tester) async {
      var loggedOut = false;
      await pumpChange(tester, onLogout: () => loggedOut = true);
      await tester.tap(find.text('Cerrar sesión'));
      expect(loggedOut, isTrue);
    });
  });

  group('Alertas al aprobar una solicitud', () {
    final application = OwnerApplication(
      uid: 'o1',
      firstNames: 'Ana',
      lastNames: 'Pérez',
      email: 'ana@example.com',
      phoneNumber: '+573001234567',
      personType: PersonType.juridica,
      nit: '900123456-8',
      companyName: 'Moteles del Sur SAS',
      planId: 2,
      createdAt: DateTime(2026, 5, 20),
    );

    Future<InMemoryAdminAccessRepository> pumpDetail(
      WidgetTester tester, {
      required List<SubscriptionPlanOption> plans,
    }) async {
      _bigScreen(tester);
      final access = InMemoryAdminAccessRepository([application]);
      final controller = AdminAccessController(
        repository: access,
        loadPlans: () async => plans,
      );
      await controller.loadPendingOwners();
      await tester.pumpWidget(
        testApp(OwnerApprovalDetailPage(uid: 'o1', controller: controller)),
      );
      await tester.pumpAndSettle();
      return access;
    }

    testWidgets('muestra las alertas y las repite al confirmar', (
      tester,
    ) async {
      await pumpDetail(tester, plans: const []);

      expect(find.text('Revisa antes de aprobar'), findsOneWidget);
      expect(find.text('El plan elegido ya no está disponible.'), findsOne);

      await tester.tap(find.text('Aprobar'));
      await tester.pumpAndSettle();

      expect(find.text('Aprobar con advertencias'), findsOneWidget);
      expect(
        find.textContaining('• El plan elegido ya no está disponible.'),
        findsOneWidget,
      );
      // Informan, no bloquean: se puede aprobar.
      await tester.tap(find.widgetWithText(FilledButton, 'Aprobar'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle de la solicitud'), findsNothing);
    });

    testWidgets('sin alertas la confirmación es la habitual', (tester) async {
      await pumpDetail(
        tester,
        plans: const [SubscriptionPlanOption(id: 2, name: 'Premium')],
      );

      expect(find.text('Revisa antes de aprobar'), findsNothing);
      await tester.tap(find.text('Aprobar'));
      await tester.pumpAndSettle();
      expect(find.text('Aprobar solicitud'), findsOneWidget);
    });
  });

  group('Recordar mi correo', () {
    late AuthPreferences preferences;
    late FakeAuthService auth;

    setUp(() {
      auth = FakeAuthService();
      preferences = AuthPreferences(
        preferences: SharedPreferencesLocalService(namespace: 'auth'),
      );
    });

    Future<void> pumpLogin(WidgetTester tester) async {
      _bigScreen(tester);
      final controller = LoginController(
        authService: auth,
        preferences: preferences,
        catalogRepository: FakeCatalogRepository(),
      );
      await tester.pumpWidget(
        testApp(
          LoginPage(controller: controller),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Text('inicio'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    CheckboxListTile checkbox(WidgetTester tester) => tester
        .widget<CheckboxListTile>(find.byKey(const ValueKey('remember-email')));

    testWidgets('precarga el correo y marca la casilla', (tester) async {
      await preferences.saveRememberedEmail('ana@example.com');
      await pumpLogin(tester);

      expect(find.text('ana@example.com'), findsOneWidget);
      expect(checkbox(tester).value, isTrue);
    });

    testWidgets('marcada guarda el correo al ingresar', (tester) async {
      await pumpLogin(tester);
      expect(checkbox(tester).value, isFalse);

      await tester.enterText(find.byType(TextFormField).at(0), 'Ana@Mail.com');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Clave-Segura-1',
      );
      await tester.tap(find.byKey(const ValueKey('remember-email')));
      await tester.pump();
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      final saved = await preferences.loadRememberedEmail();
      expect(saved.remember, isTrue);
      expect(saved.email, 'ana@mail.com');
    });

    testWidgets('desmarcada elimina el correo recordado', (tester) async {
      await preferences.saveRememberedEmail('ana@example.com');
      await pumpLogin(tester);

      await tester.tap(find.byKey(const ValueKey('remember-email')));
      await tester.pump();
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Clave-Segura-1',
      );
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect((await preferences.loadRememberedEmail()).remember, isFalse);
    });

    testWidgets('una cuenta eliminada se informa como tal', (tester) async {
      auth.loginFailure = const AuthFailure(
        AuthFailureType.accountDeleted,
        'Esta cuenta ya no existe.',
      );
      await pumpLogin(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'ana@mail.com');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Clave-Segura-1',
      );
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('Esta cuenta ya no existe.'), findsOneWidget);
      expect(find.byIcon(Icons.person_off_outlined), findsOneWidget);
    });
  });
}
