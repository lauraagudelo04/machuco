// Flujos críticos de Google/GitHub en la interfaz, con un SocialAuthService
// falso. Los ID [SOC-UI-xx] enlazan con docs/auth/escenarios-auth-social.feature.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/auth_routes.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/auth_provider_kind.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/social_auth_result.dart';
import 'package:machuco/models/auth/social_profile_data.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/firebase_social_auth_service.dart';
import 'package:machuco/views/account_review/account_review_page.dart';
import 'package:machuco/views/login/login_page.dart';
import 'package:machuco/views/register/complete_profile_page.dart';
import 'package:machuco/widgets/auth/delete_account_sheet.dart';
import 'package:machuco/widgets/auth/forgot_password_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_support.dart';

AuthSession _session({
  RegisteredUserRole role = RegisteredUserRole.client,
  AccountStatus status = AccountStatus.active,
}) => AuthSession(
  userId: 'u1',
  name: 'Ana Pérez',
  email: 'ana@example.com',
  role: role,
  accessToken: 'a',
  idToken: 'i',
  accountStatus: status,
);

const _incomplete = SocialAuthIncompleteProfile(
  uid: 'u1',
  email: 'ana@example.com',
  emailVerified: true,
  provider: AuthProviderKind.google,
  displayName: 'Ana María Pérez',
);

void main() {
  late FakeAuthService auth;
  late LoginController controller;
  late _FakeSocial social;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthService();
    controller = buildTestController(auth);
    social = _FakeSocial();
  });

  /// Rutas de prueba: "Completar perfil" real (con el controller de prueba)
  /// y el resto como una pantalla que muestra su nombre y argumentos.
  Route<dynamic> routes(RouteSettings settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) {
      final args = settings.arguments;
      if (settings.name == AuthRoutes.completeProfile &&
          args is CompleteProfileArgs) {
        return CompleteProfilePage(
          args: CompleteProfileArgs(
            profile: args.profile,
            social: args.social,
            controller: controller,
            loginBuilder: (_) => const Scaffold(body: Text('pantalla login')),
          ),
        );
      }
      final detail = args is AccountReviewArgs
          ? ' rechazada=${args.rejected} motivo=${args.rejectionReason}'
          : '';
      return Scaffold(body: Text('ruta:${settings.name}$detail'));
    },
  );

  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginPage(controller: controller, socialAuthService: social),
        onGenerateRoute: routes,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapProvider(WidgetTester tester, AuthProviderKind kind) async {
    await tester.tap(find.byKey(ValueKey('social-${kind.name}')));
    await tester.pumpAndSettle();
  }

  group('ingreso desde el login', () {
    testWidgets('[SOC-UI-03] carga mientras el proveedor responde y un '
        'segundo toque no abre otro flujo', (tester) async {
      final pending = Completer<SocialAuthResult>();
      social.googleResults.add(pending.future);
      await pumpLogin(tester);

      await tester.tap(find.byKey(const ValueKey('social-google')));
      await tester.pump();
      final google = tester.widget<AppButton>(
        find.byKey(const ValueKey('social-google')),
      );
      expect(google.loading, isTrue);
      await tester.tap(
        find.byKey(const ValueKey('social-github')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(social.gitHubCalls, 0);

      pending.complete(SocialAuthActive(_session()));
      await tester.pumpAndSettle();
      expect(social.googleCalls, 1);
      expect(find.text('ruta:${AppRoutes.clientMotels}'), findsOneWidget);
    });

    testWidgets('[SOC-UI-04] cancelar deja el login intacto y sin error', (
      tester,
    ) async {
      social.gitHubResults.add(Future.value(const SocialAuthCancelled()));
      await pumpLogin(tester);

      await tapProvider(tester, AuthProviderKind.github);

      expect(find.text('Inicia sesión o crea tu cuenta'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('[SOC-UI-05] sin conexión muestra "Reintentar" y reintenta '
        'con el mismo proveedor', (tester) async {
      social.googleResults
        ..add(
          Future.value(
            const SocialAuthError(
              AuthFailure(
                AuthFailureType.network,
                'No hay conexión. Revisa tu internet e intenta nuevamente.',
              ),
            ),
          ),
        )
        ..add(Future.value(SocialAuthActive(_session())));
      await pumpLogin(tester);

      await tapProvider(tester, AuthProviderKind.google);
      expect(find.textContaining('No hay conexión'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(social.googleCalls, 2);
      expect(find.text('ruta:${AppRoutes.clientMotels}'), findsOneWidget);
    });

    testWidgets('[SOC-UI-06] configuración incorrecta o correo no '
        'verificado se informan en español', (tester) async {
      social.gitHubResults.add(
        Future.value(
          const SocialAuthError(
            AuthFailure(
              AuthFailureType.emailNotVerified,
              'No pudimos confirmar que el correo de GitHub esté verificado.',
            ),
          ),
        ),
      );
      await pumpLogin(tester);

      await tapProvider(tester, AuthProviderKind.github);

      expect(find.textContaining('No pudimos confirmar'), findsOneWidget);
    });

    testWidgets('[SOC-UI-07] perfil incompleto lleva a "Completar perfil"', (
      tester,
    ) async {
      social.googleResults.add(Future.value(_incomplete));
      await pumpLogin(tester);

      await tapProvider(tester, AuthProviderKind.google);

      expect(find.text('Completa tu perfil'), findsOneWidget);
    });

    testWidgets('[SOC-UI-08] propietario pendiente va a "Cuenta en revisión"', (
      tester,
    ) async {
      social.googleResults.add(
        Future.value(
          SocialAuthPending(
            _session(
              role: RegisteredUserRole.owner,
              status: AccountStatus.pendingApproval,
            ),
          ),
        ),
      );
      await pumpLogin(tester);

      await tapProvider(tester, AuthProviderKind.google);

      expect(
        find.textContaining('ruta:${AuthRoutes.accountReview}'),
        findsOneWidget,
      );
    });

    testWidgets('[SOC-UI-09] rechazado muestra el motivo', (tester) async {
      social.googleResults.add(
        Future.value(const SocialAuthRejected(reason: 'NIT inválido')),
      );
      await pumpLogin(tester);

      await tapProvider(tester, AuthProviderKind.google);

      expect(
        find.text(
          'ruta:${AuthRoutes.accountReview} rechazada=true motivo=NIT inválido',
        ),
        findsOneWidget,
      );
    });

    testWidgets('[SOC-UI-10] cuenta deshabilitada se avisa en el login', (
      tester,
    ) async {
      social.gitHubResults.add(Future.value(const SocialAuthDisabled()));
      await pumpLogin(tester);

      await tapProvider(tester, AuthProviderKind.github);

      expect(find.textContaining('deshabilitada'), findsOneWidget);
    });

    testWidgets('[SOC-UI-11] conflicto de correo: tras entrar con la '
        'contraseña ofrece vincular el proveedor', (tester) async {
      social.gitHubResults.add(
        Future.value(
          const SocialAuthError(
            AuthFailure(
              AuthFailureType.accountExistsWithDifferentCredential,
              'Ya existe una cuenta con este correo.',
            ),
          ),
        ),
      );
      await pumpLogin(tester);
      await tapProvider(tester, AuthProviderKind.github);
      expect(find.textContaining('Ya existe una cuenta'), findsOneWidget);

      social.pendingLinkProvider = AuthProviderKind.github;
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'ana@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secreto123',
      );
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('Vincular GitHub'), findsWidgets);
      await tester.tap(find.widgetWithText(TextButton, 'Vincular GitHub'));
      await tester.pumpAndSettle();
      expect(social.linkPendingCalls, 1);
    });

    testWidgets('[SOC-UI-23] "Reintentar" tras autenticar no abre otro '
        'flujo del proveedor: vuelve a leer el perfil', (tester) async {
      social.googleResults.add(
        Future.value(
          const SocialAuthError(
            AuthFailure(
              AuthFailureType.network,
              'No hay conexión. Revisa tu internet e intenta nuevamente.',
            ),
          ),
        ),
      );
      await pumpLogin(tester);
      await tapProvider(tester, AuthProviderKind.google);
      expect(find.text('Reintentar'), findsOneWidget);

      // Firebase ya autenticó al usuario; solo falló Firestore.
      social.linked = [AuthProviderKind.google];
      social.resumeResult = SocialAuthActive(_session());
      final resumesBefore = social.resumeCalls; // incluye la del arranque
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(social.googleCalls, 1);
      expect(social.resumeCalls, resumesBefore + 1);
      expect(find.text('ruta:${AppRoutes.clientMotels}'), findsOneWidget);
    });

    testWidgets('[SOC-UI-12] al abrir la app retoma "Completar perfil"', (
      tester,
    ) async {
      social.resumeResult = _incomplete;
      await pumpLogin(tester);

      expect(find.text('Completa tu perfil'), findsOneWidget);
    });
  });

  group('Completar perfil', () {
    Future<void> pumpComplete(
      WidgetTester tester, {
      SocialAuthIncompleteProfile profile = _incomplete,
    }) async {
      tester.view.physicalSize = const Size(700, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await controller.loadCountryPhoneCodes();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          onGenerateRoute: routes,
          home: CompleteProfilePage(
            args: CompleteProfileArgs(
              profile: profile,
              social: social,
              controller: controller,
              loginBuilder: (_) => const Scaffold(body: Text('pantalla login')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder field(String label) => find.widgetWithText(TextFormField, label);

    testWidgets('[SOC-UI-13] precarga nombres, correo en solo lectura, sin '
        'contraseña ni Administrador', (tester) async {
      await pumpComplete(tester);

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('María Pérez'), findsOneWidget);
      final email = tester.widget<TextFormField>(field('Correo electrónico'));
      expect(email.enabled, isFalse);
      expect(field('Contraseña'), findsNothing);
      expect(find.text('Administrador'), findsNothing);
      expect(find.text('Términos y condiciones'), findsOneWidget);
    });

    testWidgets('[SOC-UI-24] precarga el celular del proveedor separando el '
        'indicativo', (tester) async {
      await pumpComplete(
        tester,
        profile: const SocialAuthIncompleteProfile(
          uid: 'u1',
          email: 'ana@example.com',
          emailVerified: true,
          provider: AuthProviderKind.google,
          displayName: 'Ana Pérez',
          phoneNumber: '+573001234567',
        ),
      );

      expect(find.text('3001234567'), findsOneWidget);
      expect(controller.selectedCountryPhoneCode?.dialCode, '+57');
    });

    testWidgets('[SOC-UI-24] un celular de un país fuera del catálogo no se '
        'precarga', (tester) async {
      await pumpComplete(
        tester,
        profile: const SocialAuthIncompleteProfile(
          uid: 'u1',
          email: 'ana@example.com',
          emailVerified: true,
          provider: AuthProviderKind.github,
          phoneNumber: '+447911123456',
        ),
      );

      expect(find.textContaining('7911123456'), findsNothing);
    });

    testWidgets('[SOC-UI-14] cliente: guarda con el indicativo y entra', (
      tester,
    ) async {
      social.completeResult = SocialAuthActive(_session());
      await pumpComplete(tester);

      await tester.enterText(field('Celular'), '3001234567');
      await tester.enterText(field('Fecha de nacimiento'), '10/05/1995');
      await tester.tap(find.byKey(const ValueKey('complete-profile-submit')));
      await tester.pumpAndSettle();

      final data = social.completed.single;
      expect(data.role, RegisteredUserRole.client);
      expect(data.phoneNumber, '+573001234567');
      expect(data.firstNames, 'Ana');
      expect(find.text('ruta:${AppRoutes.clientMotels}'), findsOneWidget);
    });

    testWidgets('[SOC-UI-15] propietario: pide tipo de persona, NIT y plan, '
        'y queda en revisión', (tester) async {
      social.completeResult = SocialAuthPending(
        _session(
          role: RegisteredUserRole.owner,
          status: AccountStatus.pendingApproval,
        ),
      );
      await pumpComplete(tester);

      await tester.tap(find.text('Propietario'));
      await tester.pumpAndSettle();
      expect(field('Fecha de nacimiento'), findsNothing);
      await tester.enterText(field('Celular'), '3001234567');
      await tester.enterText(field('NIT'), '1020304050-8');
      await tester.tap(find.text('Básico'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('complete-profile-submit')));
      await tester.pumpAndSettle();

      final data = social.completed.single;
      expect(data.role, RegisteredUserRole.owner);
      expect(data.nit, '1020304050-8');
      expect(data.planId, 1);
      expect(
        find.textContaining('ruta:${AuthRoutes.accountReview}'),
        findsOneWidget,
      );
    });

    testWidgets('[SOC-UI-16] datos inválidos no se envían', (tester) async {
      await pumpComplete(tester);

      await tester.enterText(field('Fecha de nacimiento'), '01/01/2015');
      await tester.tap(find.byKey(const ValueKey('complete-profile-submit')));
      await tester.pumpAndSettle();

      expect(social.completed, isEmpty);
    });

    testWidgets('[SOC-UI-17] falla al guardar conserva los datos y ofrece '
        '"Reintentar"', (tester) async {
      social.completeResult = const SocialAuthError(
        AuthFailure(AuthFailureType.network, 'No hay conexión.'),
      );
      await pumpComplete(tester);

      await tester.enterText(field('Celular'), '3001234567');
      await tester.enterText(field('Fecha de nacimiento'), '10/05/1995');
      await tester.tap(find.byKey(const ValueKey('complete-profile-submit')));
      await tester.pumpAndSettle();

      expect(find.text('No hay conexión.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('3001234567'), findsOneWidget);
      expect(find.text('Completa tu perfil'), findsOneWidget);
    });

    testWidgets('[SOC-UI-18] cancelar abandona el registro y vuelve al login '
        '(D10)', (tester) async {
      await pumpComplete(tester);

      await tester.tap(find.byKey(const ValueKey('complete-profile-cancel')));
      await tester.pumpAndSettle();

      expect(social.abandonCalls, 1);
      expect(social.deleteCalls, 0);
      expect(find.text('pantalla login'), findsOneWidget);
    });

    testWidgets(
      '[SOC-UI-18] "atrás" no abandona mientras se guarda el perfil',
      (tester) async {
        await pumpComplete(tester);
        final gate = Completer<void>();
        social.completeGate = gate;

        await tester.enterText(field('Celular'), '3001234567');
        await tester.enterText(field('Fecha de nacimiento'), '10/05/1995');
        await tester.tap(find.byKey(const ValueKey('complete-profile-submit')));
        await tester.pump();
        expect(social.completed, hasLength(1));

        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(social.abandonCalls, 0);

        gate.complete();
        await tester.pumpAndSettle();
      },
    );
  });

  group('eliminación y recuperación', () {
    Future<void> openFrom(
      WidgetTester tester,
      Future<void> Function(BuildContext context) open,
    ) async {
      tester.view.physicalSize = const Size(700, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => open(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('[SOC-UI-19] cuenta solo de Google: confirma con Google, sin '
        'contraseña', (tester) async {
      social.linked = [AuthProviderKind.google];
      bool? deleted;
      await openFrom(
        tester,
        (context) async => deleted = await showDeleteAccountSheet(
          context,
          controller: controller,
          socialAuthService: social,
        ),
      );

      expect(find.text('Contraseña actual'), findsNothing);
      expect(find.textContaining('El acceso con Google'), findsOneWidget);
      final submit = find.byKey(const ValueKey('delete-account-submit'));
      expect(tester.widget<AppButton>(submit).onPressed, isNull);

      await tester.enterText(find.byType(TextFormField).last, 'ELIMINAR');
      await tester.pump();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(social.deleteCalls, 1);
      expect(auth.deletedWithPasswords, isEmpty);
      expect(auth.logoutCalled, isTrue);
      expect(deleted, isTrue);
    });

    testWidgets('[SOC-UI-20] cancelar la confirmación con el proveedor no '
        'cierra la hoja', (tester) async {
      social.linked = [AuthProviderKind.github];
      social.deleteFailure = const AuthFailure(
        AuthFailureType.cancelled,
        'Se canceló la confirmación. Tu cuenta no se eliminó.',
      );
      await openFrom(
        tester,
        (context) => showDeleteAccountSheet(
          context,
          controller: controller,
          socialAuthService: social,
        ),
      );

      await tester.enterText(find.byType(TextFormField).last, 'ELIMINAR');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('delete-account-submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tu cuenta no se eliminó'), findsOneWidget);
      expect(auth.logoutCalled, isFalse);
    });

    testWidgets('[SOC-UI-21] cuenta con contraseña y Google sigue pidiendo '
        'la contraseña', (tester) async {
      social.linked = [AuthProviderKind.password, AuthProviderKind.google];
      await openFrom(
        tester,
        (context) => showDeleteAccountSheet(
          context,
          controller: controller,
          socialAuthService: social,
        ),
      );

      expect(find.text('Contraseña actual'), findsOneWidget);
    });

    testWidgets('[SOC-UI-22] recuperación: aviso para cuentas sociales sin '
        'revelar si el correo existe', (tester) async {
      await openFrom(
        tester,
        (context) => showForgotPasswordSheet(
          context,
          controller: controller,
          initialEmail: 'cualquiera@example.com',
        ),
      );
      await tester.tap(find.text('Enviar instrucciones'));
      await tester.pumpAndSettle();

      expect(find.text(passwordResetNeutralMessage), findsOneWidget);
      expect(find.text(socialAccountResetHint), findsOneWidget);
      // Detiene la cuenta regresiva de 60 s del controller.
      controller.dispose();
    });
  });
}

final class _FakeSocial implements SocialAuthService {
  final googleResults = <Future<SocialAuthResult>>[];
  final gitHubResults = <Future<SocialAuthResult>>[];
  SocialAuthResult? resumeResult;
  SocialAuthResult completeResult = const SocialAuthCancelled();

  /// Si no es `null`, `completeProfile` espera a que se complete.
  Completer<void>? completeGate;
  final completed = <SocialProfileData>[];
  List<AuthProviderKind> linked = const [];
  AuthFailure? deleteFailure;
  int googleCalls = 0;
  int gitHubCalls = 0;
  int abandonCalls = 0;
  int deleteCalls = 0;
  int linkPendingCalls = 0;

  @override
  AuthProviderKind? pendingLinkProvider;

  @override
  String? get pendingLinkEmail => null;

  @override
  List<AuthProviderKind> get linkedProviders => linked;

  @override
  Future<SocialAuthResult> signInWithGoogle() {
    googleCalls++;
    return googleResults.removeAt(0);
  }

  @override
  Future<SocialAuthResult> signInWithGitHub() {
    gitHubCalls++;
    return gitHubResults.removeAt(0);
  }

  int resumeCalls = 0;

  @override
  Future<SocialAuthResult?> resumeSession() async {
    resumeCalls++;
    final result = resumeResult;
    resumeResult = null;
    return result;
  }

  @override
  Future<SocialAuthResult> completeProfile(SocialProfileData data) async {
    completed.add(data);
    await completeGate?.future;
    return completeResult;
  }

  @override
  Future<void> abandonProfileCompletion() async => abandonCalls++;

  @override
  Future<void> linkPendingProvider() async {
    linkPendingCalls++;
    pendingLinkProvider = null;
  }

  @override
  Future<void> linkProvider(AuthProviderKind kind) async {}

  @override
  Future<void> unlinkProvider(AuthProviderKind kind) async {}

  @override
  Future<void> deleteAccount({String? password}) async {
    final failure = deleteFailure;
    if (failure != null) throw failure;
    deleteCalls++;
  }

  @override
  Future<void> signOut() async {}
}
