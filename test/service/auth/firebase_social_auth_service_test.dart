// Pruebas de FirebaseSocialAuthService con FirebaseAuth, Firestore, SQLite y
// la API de GitHub simulados. Los ID [SOC-xx] enlazan cada prueba con un
// escenario de docs/auth/escenarios-auth-social.feature.
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/model/auth/auth_user_profile_entry.dart';
import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/database/repository/auth/auth_user_profile_repository.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/auth_provider_kind.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/social_auth_result.dart';
import 'package:machuco/models/auth/social_profile_data.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/analytics/analytics_service.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/firebase_social_auth_service.dart';
import 'package:machuco/service/auth/github_email_verifier.dart';

import '../analytics/recording_analytics_service.dart';

final _now = DateTime.utc(2026, 11, 4, 12);

UserProfile _profile({
  RegisteredUserRole role = RegisteredUserRole.client,
  AccountStatus? status = AccountStatus.active,
  String? rejectionReason,
}) => UserProfile(
  uid: 'u1',
  fullName: 'Ana Pérez',
  email: 'ana@example.com',
  phoneNumber: '+573001234567',
  role: role,
  accountStatus: status,
  rejectionReason: rejectionReason,
);

SocialProfileData _client({DateTime? birthDate}) => SocialProfileData.client(
  firstNames: 'Ana',
  lastNames: 'Pérez',
  phoneCountryCodeId: 1,
  phoneNumber: '+573001234567',
  birthDate: birthDate ?? DateTime.utc(1995, 5, 10),
);

SocialProfileData _owner() => SocialProfileData.owner(
  firstNames: 'Luis',
  lastNames: 'Gómez',
  phoneCountryCodeId: 1,
  phoneNumber: '+573001112233',
  personType: PersonType.juridica,
  nit: '900123456-8',
  companyName: 'Inversiones Ejemplo S.A.S.',
  planId: 2,
);

void main() {
  late _FakeAuth auth;
  late _FakeProfiles profiles;
  late _FakeCache cache;
  late _StubAdministrators administrators;
  late List<http.Request> gitHubRequests;
  late http.Response Function() gitHubResponse;
  late FirebaseSocialAuthService service;

  setUp(() {
    auth = _FakeAuth();
    profiles = _FakeProfiles();
    cache = _FakeCache();
    administrators = _StubAdministrators();
    gitHubRequests = [];
    gitHubResponse = () => http.Response(
      jsonEncode([
        {'email': 'ana@example.com', 'verified': true, 'primary': true},
      ]),
      200,
    );
    service = FirebaseSocialAuthService(
      firebaseAuth: auth,
      profileRepository: profiles,
      profileCache: cache,
      administratorsRepository: administrators,
      gitHubEmailVerifier: GitHubEmailVerifier(
        httpClient: MockClient((request) async {
          gitHubRequests.add(request);
          return gitHubResponse();
        }),
      ),
      clock: () => _now,
    );
  });

  _FakeUser googleUser({bool verified = true, String? email}) => _FakeUser(
    auth,
    emailValue: email ?? 'ana@example.com',
    emailVerifiedValue: verified,
    providers: ['google.com'],
  );

  _FakeUser gitHubUser({String? email = 'ana@example.com'}) => _FakeUser(
    auth,
    emailValue: email,
    emailVerifiedValue: false, // Firebase no marca verificados los de GitHub.
    providers: ['github.com'],
  );

  T expectType<T>(Object? value) {
    expect(value, isA<T>());
    return value as T;
  }

  group('registro e ingreso', () {
    test('[SOC-01] Google nuevo: perfil incompleto con datos del proveedor '
        'y selector de cuenta', () async {
      auth.nextUser = googleUser();

      final result = expectType<SocialAuthIncompleteProfile>(
        await service.signInWithGoogle(),
      );

      expect(result.provider, AuthProviderKind.google);
      expect(result.email, 'ana@example.com');
      expect(result.emailVerified, isTrue);
      expect(result.displayName, 'Ana Pérez');
      final provider = auth.lastProvider as GoogleAuthProvider;
      expect(provider.parameters['prompt'], 'select_account');
      expect(
        provider.scopes,
        containsAll(<String>['email', 'profile']),
        reason: 'sin profile, Google no entrega el nombre para precargar',
      );
      expect(auth.signOutCalls, 0, reason: 'la sesión sigue para completar');
    });

    test(
      '[SOC-02] Google con perfil completo: activo y perfil en SQLite',
      () async {
        auth.nextUser = googleUser();
        profiles.stored['u1'] = _profile();

        final result = expectType<SocialAuthActive>(
          await service.signInWithGoogle(),
        );

        expect(result.session.role, RegisteredUserRole.client);
        expect(result.session.idToken, 'id-token');
        expect(cache.saved?.uid, 'u1');
      },
    );

    test('[SOC-03] GitHub nuevo con correo verificado por la API: pide '
        'user:email y usa el token del usuario', () async {
      auth.nextUser = gitHubUser();
      auth.nextAccessToken = 'gho_token';

      final result = expectType<SocialAuthIncompleteProfile>(
        await service.signInWithGitHub(),
      );

      expect(result.provider, AuthProviderKind.github);
      final provider = auth.lastProvider as GithubAuthProvider;
      expect(provider.scopes, contains('user:email'));
      expect(gitHubRequests.single.url.path, '/user/emails');
      expect(
        gitHubRequests.single.headers['Authorization'],
        'Bearer gho_token',
      );
    });

    test('[SOC-04] GitHub con perfil completo: activo', () async {
      auth.nextUser = gitHubUser();
      auth.nextAccessToken = 'gho_token';
      profiles.stored['u1'] = _profile();

      expectType<SocialAuthActive>(await service.signInWithGitHub());
    });
  });

  group('analítica', () {
    late RecordingAnalyticsService analytics;

    List<String> reported(RecordingAnalyticsService analytics) => [
      for (final event in analytics.events)
        '${event.name}:${event.parameters['method']}',
    ];

    setUp(() {
      analytics = RecordingAnalyticsService();
      service = FirebaseSocialAuthService(
        firebaseAuth: auth,
        profileRepository: profiles,
        profileCache: cache,
        administratorsRepository: administrators,
        gitHubEmailVerifier: GitHubEmailVerifier(
          httpClient: MockClient((request) async => gitHubResponse()),
        ),
        clock: () => _now,
        analytics: analytics,
      );
    });

    test('Google y GitHub con perfil completo reportan login con su '
        'método', () async {
      auth.nextUser = googleUser();
      profiles.stored['u1'] = _profile();
      await service.signInWithGoogle();

      auth.nextUser = gitHubUser();
      auth.nextAccessToken = 'gho_token';
      await service.signInWithGitHub();

      expect(reported(analytics), [
        'login:${AnalyticsLoginMethod.google}',
        'login:${AnalyticsLoginMethod.github}',
      ]);
    });

    test('un usuario nuevo no reporta login hasta completar el perfil, y '
        'entonces reporta sign_up', () async {
      auth.nextUser = googleUser();
      await service.signInWithGoogle();
      expect(analytics.events, isEmpty);

      await service.completeProfile(_client());

      expect(reported(analytics), ['sign_up:${AnalyticsLoginMethod.google}']);
    });

    test('una cancelación no reporta nada', () async {
      auth.signInError = FirebaseAuthException(code: 'canceled');

      await service.signInWithGoogle();

      expect(analytics.events, isEmpty);
    });
  });

  group('cancelación, conexión y configuración', () {
    for (final code in ['web-context-canceled', 'canceled', 'user-cancelled']) {
      test(
        '[SOC-05] cancelar ($code) deja al usuario en el login sin error',
        () async {
          auth.signInError = FirebaseAuthException(code: code);

          expectType<SocialAuthCancelled>(await service.signInWithGoogle());
          auth.signInError = FirebaseAuthException(code: code);
          expectType<SocialAuthCancelled>(await service.signInWithGitHub());
          expect(profiles.created, isEmpty);
        },
      );
    }

    for (final code in ['unsupported-platform', 'unsupported-platform-operation']) {
      test('$code explica la limitación de la plataforma', () async {
        auth.signInError = FirebaseAuthException(code: code);
        final result = expectType<SocialAuthError>(
          await service.signInWithGitHub(),
        );
        expect(result.failure.type, AuthFailureType.providerMisconfigured);
        expect(result.failure.message, contains('no está disponible'));
        expect(result.failure.message, contains('versión web o Android'));
        expect(profiles.created, isEmpty);
      });
    }

    test('[SOC-06] sin conexión: error de red', () async {
      auth.signInError = FirebaseAuthException(code: 'network-request-failed');

      final result = expectType<SocialAuthError>(
        await service.signInWithGoogle(),
      );
      expect(result.failure.type, AuthFailureType.network);
    });

    test('[SOC-07] proveedor deshabilitado o SHA sin registrar: '
        'configuración incorrecta', () async {
      auth.signInError = FirebaseAuthException(code: 'operation-not-allowed');
      var result = expectType<SocialAuthError>(
        await service.signInWithGitHub(),
      );
      expect(result.failure.type, AuthFailureType.providerMisconfigured);

      auth.signInError = FirebaseAuthException(
        code: 'internal-error',
        message: 'ApiException: 10: DEVELOPER_ERROR',
      );
      result = expectType<SocialAuthError>(await service.signInWithGoogle());
      expect(result.failure.type, AuthFailureType.providerMisconfigured);
    });
  });

  group('datos del proveedor para precargar', () {
    test(
      '[SOC-35] sin displayName principal usa el nombre de providerData',
      () async {
        auth.nextUser = _FakeUser(
          auth,
          emailValue: 'ana@example.com',
          emailVerifiedValue: true,
          providers: ['google.com'],
          displayNameValue: null,
          providerInfo: {'google.com': (name: 'Ana María Pérez', phone: null)},
        );

        final result = expectType<SocialAuthIncompleteProfile>(
          await service.signInWithGoogle(),
        );
        expect(result.displayName, 'Ana María Pérez');
      },
    );

    test('[SOC-35] sin ningún nombre queda en null (no usa el usuario de '
        'GitHub)', () async {
      auth.nextUser = _FakeUser(
        auth,
        emailValue: 'ana@example.com',
        emailVerifiedValue: true,
        providers: ['google.com'],
        displayNameValue: '  ',
      );

      final result = expectType<SocialAuthIncompleteProfile>(
        await service.signInWithGoogle(),
      );
      expect(result.displayName, isNull);
    });

    test('[SOC-36] entrega el celular si el proveedor lo trae', () async {
      auth.nextUser = _FakeUser(
        auth,
        emailValue: 'ana@example.com',
        emailVerifiedValue: true,
        providers: ['google.com'],
        providerInfo: {'google.com': (name: null, phone: '+573001234567')},
      );

      final result = expectType<SocialAuthIncompleteProfile>(
        await service.signInWithGoogle(),
      );
      expect(result.phoneNumber, '+573001234567');
    });

    test('[SOC-36] prefiere el celular del usuario principal', () async {
      auth.nextUser = _FakeUser(
        auth,
        emailValue: 'ana@example.com',
        emailVerifiedValue: true,
        providers: ['google.com'],
        phoneValue: '+525512345678',
        providerInfo: {'google.com': (name: null, phone: '+573001234567')},
      );

      final result = expectType<SocialAuthIncompleteProfile>(
        await service.signInWithGoogle(),
      );
      expect(result.phoneNumber, '+525512345678');
    });

    test('[SOC-36] sin celular del proveedor queda en null', () async {
      auth.nextUser = googleUser();

      final result = expectType<SocialAuthIncompleteProfile>(
        await service.signInWithGoogle(),
      );
      expect(result.phoneNumber, isNull);
    });
  });

  group('casos propios de GitHub', () {
    test('[SOC-08] el usuario deniega el permiso en GitHub', () async {
      auth.signInError = FirebaseAuthException(
        code: 'internal-error',
        message: 'error=access_denied',
      );

      expectType<SocialAuthCancelled>(await service.signInWithGitHub());
    });

    test(
      '[SOC-09] GitHub sin correo: bloquea, cierra sesión y no crea perfil',
      () async {
        auth.nextUser = gitHubUser(email: null);

        final result = expectType<SocialAuthError>(
          await service.signInWithGitHub(),
        );

        expect(result.failure.type, AuthFailureType.emailUnavailable);
        expect(auth.signOutCalls, 1);
        expect(profiles.created, isEmpty);
      },
    );

    test('[SOC-10] GitHub con correo no verificado (D5): bloquea', () async {
      auth.nextUser = gitHubUser();
      auth.nextAccessToken = 'gho_token';
      gitHubResponse = () => http.Response(
        jsonEncode([
          {'email': 'ana@example.com', 'verified': false, 'primary': true},
        ]),
        200,
      );

      final result = expectType<SocialAuthError>(
        await service.signInWithGitHub(),
      );

      expect(result.failure.type, AuthFailureType.emailNotVerified);
      expect(auth.signOutCalls, 1);
    });

    test(
      '[SOC-10] GitHub sin token o con la API caída no concede acceso',
      () async {
        auth.nextUser = gitHubUser();
        auth.nextAccessToken = null;
        var result = expectType<SocialAuthError>(
          await service.signInWithGitHub(),
        );
        expect(result.failure.type, AuthFailureType.emailNotVerified);

        auth.nextUser = gitHubUser();
        auth.nextAccessToken = 'gho_token';
        gitHubResponse = () => http.Response('Bad credentials', 401);
        result = expectType<SocialAuthError>(await service.signInWithGitHub());
        expect(result.failure.type, AuthFailureType.emailNotVerified);
      },
    );

    test('[SOC-10] GitHub sin conexión al verificar: error de red', () async {
      auth.nextUser = gitHubUser();
      auth.nextAccessToken = 'gho_token';
      gitHubResponse = () => throw http.ClientException('sin red');

      final result = expectType<SocialAuthError>(
        await service.signInWithGitHub(),
      );
      expect(result.failure.type, AuthFailureType.network);
    });

    test('[SOC-11] Google con correo no verificado (D7): bloquea', () async {
      auth.nextUser = googleUser(verified: false);

      final result = expectType<SocialAuthError>(
        await service.signInWithGoogle(),
      );

      expect(result.failure.type, AuthFailureType.emailNotVerified);
      expect(auth.signOutCalls, 1);
    });
  });

  group('mismo correo y vinculación', () {
    test('[SOC-12] conflicto de correo: guarda la credencial y la vincula '
        'tras entrar con el método original', () async {
      final pending = GithubAuthProvider.credential('gho_pending');
      auth.signInError = FirebaseAuthException(
        code: 'account-exists-with-different-credential',
        email: 'ana@example.com',
        credential: pending,
      );

      final result = expectType<SocialAuthError>(
        await service.signInWithGitHub(),
      );
      expect(
        result.failure.type,
        AuthFailureType.accountExistsWithDifferentCredential,
      );
      expect(result.conflictEmail, 'ana@example.com');
      expect(service.pendingLinkProvider, AuthProviderKind.github);

      final original = googleUser();
      auth.currentUser = original;
      await service.linkPendingProvider();

      expect(original.linkedCredentials.single, same(pending));
      expect(service.pendingLinkProvider, isNull);
    });

    test('[SOC-12] sin credencial en el conflicto vincula con el flujo del '
        'proveedor', () async {
      auth.signInError = FirebaseAuthException(
        code: 'account-exists-with-different-credential',
      );
      await service.signInWithGitHub();

      final original = googleUser();
      auth.currentUser = original;
      await service.linkPendingProvider();

      expect(original.linkedProviders.single.providerId, 'github.com');
    });

    test('[SOC-12] vincular una cuenta de otro usuario se informa', () async {
      final user = googleUser();
      user.linkError = FirebaseAuthException(code: 'credential-already-in-use');
      auth.currentUser = user;

      await expectLater(
        service.linkProvider(AuthProviderKind.github),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.type,
            'type',
            AuthFailureType.accountExistsWithDifferentCredential,
          ),
        ),
      );
    });

    test('[SOC-13] no se desvincula el único método de acceso', () async {
      final user = googleUser();
      auth.currentUser = user;

      await expectLater(
        service.unlinkProvider(AuthProviderKind.google),
        throwsA(isA<AuthFailure>()),
      );

      user.providerIds.add('password');
      await service.unlinkProvider(AuthProviderKind.google);
      expect(user.unlinked, ['google.com']);
    });
  });

  group('perfil incompleto', () {
    test('[SOC-14] completar como cliente crea el perfil activo', () async {
      auth.nextUser = googleUser();
      await service.signInWithGoogle();

      final result = expectType<SocialAuthActive>(
        await service.completeProfile(_client()),
      );

      final created = profiles.created.single;
      expect(created.role, RegisteredUserRole.client);
      expect(created.accountStatus, AccountStatus.active);
      expect(created.email, 'ana@example.com');
      expect(created.nit, isNull);
      expect(result.session.userId, 'u1');
      expect(cache.saved?.uid, 'u1');
    });

    test('[SOC-15] completar como propietario queda pendiente', () async {
      auth.nextUser = googleUser();
      await service.signInWithGoogle();

      expectType<SocialAuthPending>(await service.completeProfile(_owner()));

      final created = profiles.created.single;
      expect(created.accountStatus, AccountStatus.pendingApproval);
      expect(created.personType, PersonType.juridica);
      expect(created.nit, '900123456-8');
      expect(created.companyName, 'Inversiones Ejemplo S.A.S.');
      expect(created.birthDate, isNull);
    });

    test('[SOC-16] datos inválidos (menor de edad, NIT con inyección) no se '
        'guardan', () async {
      auth.currentUser = googleUser();

      var result = expectType<SocialAuthError>(
        await service.completeProfile(
          _client(birthDate: DateTime.utc(2015, 1, 1)),
        ),
      );
      expect(result.failure.type, AuthFailureType.invalidInput);

      result = expectType<SocialAuthError>(
        await service.completeProfile(
          SocialProfileData.owner(
            firstNames: 'Luis',
            lastNames: 'Gómez',
            phoneCountryCodeId: 1,
            phoneNumber: '+573001112233',
            personType: PersonType.natural,
            nit: "1' OR '1'='1",
            planId: 1,
          ),
        ),
      );
      expect(result.failure.type, AuthFailureType.invalidInput);
      expect(profiles.created, isEmpty);
    });

    test(
      '[SOC-17] reanudar: Google incompleto vuelve a "Completar perfil"',
      () async {
        auth.currentUser = googleUser();

        expectType<SocialAuthIncompleteProfile>(await service.resumeSession());
      },
    );

    test('[SOC-17] reanudar: GitHub incompleto sin verificación en Firebase '
        'exige volver a ingresar', () async {
      auth.currentUser = gitHubUser();

      expect(await service.resumeSession(), isNull);
      expect(auth.signOutCalls, 1);
    });

    group('[SOC-18] abandonar "Completar perfil" (D10)', () {
      test('borra el usuario social sin perfil y cierra sesión', () async {
        final user = googleUser();
        auth.currentUser = user;

        await service.abandonProfileCompletion();

        expect(user.deleteCalls, 1);
        expect(auth.signOutCalls, 1);
        expect(profiles.deleted, isEmpty);
      });

      test('no borra un usuario que ya tiene perfil', () async {
        final user = googleUser();
        auth.currentUser = user;
        profiles.stored['u1'] = _profile();

        await service.abandonProfileCompletion();

        expect(user.deleteCalls, 0);
        expect(auth.signOutCalls, 1);
        expect(profiles.stored, contains('u1'));
      });

      test('no borra si no se pudo confirmar que no hay perfil', () async {
        final user = googleUser();
        auth.currentUser = user;
        profiles.readError = const UserProfileRepositoryException(
          UserProfileFailureType.network,
          'sin red',
        );

        await service.abandonProfileCompletion();

        expect(user.deleteCalls, 0);
        expect(auth.signOutCalls, 1);
      });

      test('no borra una cuenta que también tiene contraseña', () async {
        final user = _FakeUser(
          auth,
          emailValue: 'ana@example.com',
          emailVerifiedValue: true,
          providers: const ['password', 'google.com'],
        );
        auth.currentUser = user;

        await service.abandonProfileCompletion();

        expect(user.deleteCalls, 0);
        expect(auth.signOutCalls, 1);
      });

      test(
        'si Firebase exige un ingreso reciente, solo cierra sesión',
        () async {
          final user = googleUser()
            ..deleteError = FirebaseAuthException(
              code: 'requires-recent-login',
            );
          auth.currentUser = user;

          await service.abandonProfileCompletion();

          expect(user.deleteCalls, 1);
          expect(auth.signOutCalls, 1);
        },
      );
    });

    test(
      '[SOC-19] completar es idempotente: no sobrescribe un perfil existente',
      () async {
        auth.currentUser = googleUser();
        profiles.stored['u1'] = _profile(
          role: RegisteredUserRole.owner,
          status: AccountStatus.pendingApproval,
        );

        expectType<SocialAuthPending>(await service.completeProfile(_client()));
        expect(profiles.created, isEmpty);
      },
    );

    test(
      '[SOC-19] doble envío: el segundo intento no crea otro perfil',
      () async {
        auth.currentUser = googleUser();

        await service.completeProfile(_client());
        await service.completeProfile(_client());

        expect(profiles.created, hasLength(1));
      },
    );

    test(
      '[SOC-19] carrera: permission-denied con perfil ya creado se resuelve',
      () async {
        auth.currentUser = googleUser();
        profiles.createError = const UserProfileRepositoryException(
          UserProfileFailureType.permissionDenied,
          'sin permiso',
        );
        profiles.onCreateError = () => profiles.stored['u1'] = _profile();

        expectType<SocialAuthActive>(await service.completeProfile(_client()));
      },
    );
  });

  group('estados de cuenta', () {
    test('[SOC-20] propietario pendiente', () async {
      auth.nextUser = googleUser();
      profiles.stored['u1'] = _profile(
        role: RegisteredUserRole.owner,
        status: AccountStatus.pendingApproval,
      );

      final result = expectType<SocialAuthPending>(
        await service.signInWithGoogle(),
      );
      expect(result.session.accountStatus, AccountStatus.pendingApproval);
    });

    test('[SOC-21] propietario rechazado: sin sesión y con motivo', () async {
      auth.nextUser = googleUser();
      profiles.stored['u1'] = _profile(
        role: RegisteredUserRole.owner,
        status: AccountStatus.rejected,
        rejectionReason: 'El NIT no coincide',
      );
      cache.saved = AuthUserProfileEntry.fromProfile(
        _profile(),
        syncedAt: _now,
      );

      final result = expectType<SocialAuthRejected>(
        await service.signInWithGoogle(),
      );
      expect(result.reason, 'El NIT no coincide');
      expect(auth.signOutCalls, 1);
      expect(cache.saved, isNull);
    });

    test('[SOC-22] deshabilitada en Firestore o en Firebase Auth', () async {
      auth.nextUser = googleUser();
      profiles.stored['u1'] = _profile(status: AccountStatus.disabled);
      expectType<SocialAuthDisabled>(await service.signInWithGoogle());

      auth.signInError = FirebaseAuthException(code: 'user-disabled');
      expectType<SocialAuthDisabled>(await service.signInWithGitHub());
    });

    test('[SOC-23] administrador activo entra', () async {
      auth.nextUser = googleUser();
      profiles.stored['u1'] = _profile(role: RegisteredUserRole.admin);

      final result = expectType<SocialAuthActive>(
        await service.signInWithGoogle(),
      );
      expect(result.session.role, RegisteredUserRole.admin);
    });

    test(
      '[SOC-24] administrador sin accountStatus: configuración inválida',
      () async {
        auth.nextUser = googleUser();
        profiles.stored['u1'] = _profile(
          role: RegisteredUserRole.admin,
          status: null,
        );

        final result = expectType<SocialAuthError>(
          await service.signInWithGoogle(),
        );
        expect(result.failure.type, AuthFailureType.invalidConfiguration);
        expect(auth.signOutCalls, 1);
      },
    );
  });

  group('fallas de persistencia', () {
    test(
      '[SOC-25] falla de Firestore al completar conserva el formulario',
      () async {
        auth.currentUser = googleUser();
        profiles.createError = const UserProfileRepositoryException(
          UserProfileFailureType.network,
          'sin red',
        );

        final result = expectType<SocialAuthError>(
          await service.completeProfile(_client()),
        );
        expect(result.failure.type, AuthFailureType.network);
        expect(cache.saved, isNull);
        expect(auth.signOutCalls, 0);
      },
    );

    test(
      '[SOC-25] falla de red al leer el perfil no cierra la sesión',
      () async {
        auth.nextUser = googleUser();
        profiles.readError = const UserProfileRepositoryException(
          UserProfileFailureType.network,
          'sin red',
        );

        final result = expectType<SocialAuthError>(
          await service.signInWithGoogle(),
        );
        expect(result.failure.type, AuthFailureType.network);
        expect(auth.signOutCalls, 0);
      },
    );

    test('[SOC-26] falla de SQLite no bloquea el ingreso', () async {
      auth.nextUser = googleUser();
      profiles.stored['u1'] = _profile();
      cache.saveError = StateError('disco lleno');

      expectType<SocialAuthActive>(await service.signInWithGoogle());
    });
  });

  group('eliminación de cuenta', () {
    test('[SOC-27] con contraseña reautentica con la contraseña', () async {
      final user = _FakeUser(
        auth,
        emailValue: 'ana@example.com',
        emailVerifiedValue: true,
        providers: ['password', 'google.com'],
      );
      auth.currentUser = user;

      await service.deleteAccount(password: 'secreto123');

      expect(user.events, ['reauth:password', 'delete']);
      expect(profiles.deleted, ['u1']);
      expect(auth.signOutCalls, 1);
    });

    for (final provider in ['google.com', 'github.com']) {
      test('[SOC-28] solo $provider reautentica con el proveedor', () async {
        final user = _FakeUser(
          auth,
          emailValue: 'ana@example.com',
          emailVerifiedValue: true,
          providers: [provider],
        );
        auth.currentUser = user;
        cache.saved = AuthUserProfileEntry.fromProfile(
          _profile(),
          syncedAt: _now,
        );

        await service.deleteAccount();

        expect(user.events, ['reauthProvider:$provider', 'delete']);
        expect(profiles.deleted, ['u1']);
        expect(cache.saved, isNull);
      });
    }

    test('[SOC-28] cancelar la reautenticación no borra nada', () async {
      final user = googleUser();
      user.reauthError = FirebaseAuthException(code: 'web-context-canceled');
      auth.currentUser = user;

      await expectLater(
        service.deleteAccount(),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.type,
            'type',
            AuthFailureType.cancelled,
          ),
        ),
      );
      expect(profiles.deleted, isEmpty);
      expect(user.deleteCalls, 0);
    });

    test('un administrador se anonimiza en vez de borrar el perfil', () async {
      final user = googleUser();
      auth.currentUser = user;
      profiles.stored['u1'] = _profile(role: RegisteredUserRole.admin);

      await service.deleteAccount();

      expect(administrators.anonymizeOwnCalls, 1);
      expect(profiles.deleted, isEmpty);
      expect(user.deleteCalls, 1);
      expect(auth.signOutCalls, 1);
    });

    test(
      'el último administrador no se elimina ni pierde el usuario',
      () async {
        final user = googleUser();
        auth.currentUser = user;
        profiles.stored['u1'] = _profile(role: RegisteredUserRole.admin);
        administrators.failure = const AdministratorsRepositoryException(
          AdministratorsFailureType.lastAdmin,
          'Eres el único administrador activo.',
        );

        await expectLater(
          service.deleteAccount(),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.type,
              'type',
              AuthFailureType.lastAdministrator,
            ),
          ),
        );
        expect(user.deleteCalls, 0);
        expect(profiles.deleted, isEmpty);
      },
    );

    test('un cliente sigue borrando su perfil', () async {
      auth.currentUser = googleUser();
      profiles.stored['u1'] = _profile();

      await service.deleteAccount();

      expect(profiles.deleted, ['u1']);
      expect(administrators.anonymizeOwnCalls, 0);
    });
  });

  group('web (ventanas emergentes)', () {
    late FirebaseSocialAuthService web;

    setUp(() {
      web = FirebaseSocialAuthService(
        firebaseAuth: auth,
        profileRepository: profiles,
        profileCache: cache,
        gitHubEmailVerifier: GitHubEmailVerifier(
          httpClient: MockClient((request) async => gitHubResponse()),
        ),
        clock: () => _now,
        useWebPopups: true,
      );
    });

    test(
      '[SOC-31] en web usa signInWithPopup, no signInWithProvider',
      () async {
        auth.nextUser = googleUser();
        profiles.stored['u1'] = _profile();

        expectType<SocialAuthActive>(await web.signInWithGoogle());
        expect(auth.calls, ['popup:google.com']);
      },
    );

    test(
      '[SOC-31] ventana cerrada o reemplazada cuenta como cancelación',
      () async {
        for (final code in [
          'popup-closed-by-user',
          'cancelled-popup-request',
        ]) {
          auth.signInError = FirebaseAuthException(code: code);
          expectType<SocialAuthCancelled>(await web.signInWithGitHub());
        }
      },
    );

    test('[SOC-32] ventana bloqueada por el navegador se explica', () async {
      auth.signInError = FirebaseAuthException(code: 'popup-blocked');

      final result = expectType<SocialAuthError>(await web.signInWithGoogle());
      expect(result.failure.type, AuthFailureType.providerMisconfigured);
      expect(result.failure.message, contains('ventanas emergentes'));
    });

    test(
      '[SOC-33] plataforma sin el flujo: error controlado, no excepción',
      () async {
        auth.providerUnimplemented = true;

        final result = expectType<SocialAuthError>(
          await service.signInWithGoogle(),
        );
        expect(result.failure.type, AuthFailureType.providerMisconfigured);
      },
    );

    test(
      '[SOC-34] en web vincula y reautentica con ventana emergente',
      () async {
        final user = googleUser();
        auth.currentUser = user;

        await web.linkProvider(AuthProviderKind.github);
        await web.deleteAccount();

        expect(user.events, [
          'linkPopup:github.com',
          'reauthPopup:google.com',
          'delete',
        ]);
      },
    );
  });

  group('sesión', () {
    test('[SOC-29] reanudar una sesión activa sin mostrar el login', () async {
      auth.currentUser = googleUser();
      profiles.stored['u1'] = _profile();

      expectType<SocialAuthActive>(await service.resumeSession());
      expect(await _noSession(auth, service), isNull);
    });

    test(
      '[SOC-29] reanudar: cuenta deshabilitada en Firebase o sin red',
      () async {
        final user = googleUser();
        user.reloadError = FirebaseAuthException(code: 'user-disabled');
        auth.currentUser = user;
        expectType<SocialAuthDisabled>(await service.resumeSession());

        final offline = googleUser();
        offline.reloadError = FirebaseAuthException(
          code: 'network-request-failed',
        );
        auth.currentUser = offline;
        final result = expectType<SocialAuthError>(
          await service.resumeSession(),
        );
        expect(result.failure.type, AuthFailureType.network);
      },
    );

    test(
      '[SOC-30] cerrar sesión cierra Firebase y borra el perfil local',
      () async {
        auth.currentUser = googleUser();
        cache.saved = AuthUserProfileEntry.fromProfile(
          _profile(),
          syncedAt: _now,
        );

        await service.signOut();

        expect(auth.signOutCalls, 1);
        expect(cache.saved, isNull);
      },
    );
  });
}

Future<SocialAuthResult?> _noSession(
  _FakeAuth auth,
  FirebaseSocialAuthService service,
) {
  auth.currentUser = null;
  return service.resumeSession();
}

final class _StubAdministrators implements AdministratorsRepository {
  int anonymizeOwnCalls = 0;
  AdministratorsRepositoryException? failure;

  @override
  Future<void> anonymizeOwnAccount() async {
    final error = failure;
    if (error != null) throw error;
    anonymizeOwnCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeProfiles implements UserProfileRepository {
  final stored = <String, UserProfile>{};
  final created = <UserProfile>[];
  final deleted = <String>[];
  UserProfileRepositoryException? createError;
  UserProfileRepositoryException? readError;
  void Function()? onCreateError;

  @override
  Future<void> createProfile(UserProfile profile) async {
    final error = createError;
    if (error != null) {
      onCreateError?.call();
      throw error;
    }
    created.add(profile);
    stored[profile.uid] = profile;
  }

  @override
  Future<UserProfile?> getProfile(String uid) async {
    final error = readError;
    if (error != null) throw error;
    return stored[uid];
  }

  @override
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
  }) async {}

  @override
  Future<void> clearMustChangePassword(String uid) async {}

  @override
  Future<void> deleteProfile(String uid) async {
    deleted.add(uid);
    stored.remove(uid);
  }
}

final class _FakeCache implements AuthUserProfileRepository {
  AuthUserProfileEntry? saved;
  Object? saveError;

  @override
  Future<void> saveCurrent(UserProfile profile) async {
    final error = saveError;
    if (error != null) throw error;
    saved = AuthUserProfileEntry.fromProfile(profile, syncedAt: _now);
  }

  @override
  Future<AuthUserProfileEntry?> loadCurrent() async => saved;

  @override
  Future<void> clear() async => saved = null;
}

final class _FakeAuth implements FirebaseAuth {
  @override
  User? currentUser;
  _FakeUser? nextUser;
  String? nextAccessToken;
  FirebaseAuthException? signInError;
  AuthProvider? lastProvider;
  int signOutCalls = 0;
  final calls = <String>[];
  bool providerUnimplemented = false;

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) {
    calls.add('popup:${provider.providerId}');
    return _complete(provider);
  }

  @override
  Future<UserCredential> signInWithProvider(AuthProvider provider) {
    if (providerUnimplemented) {
      throw UnimplementedError('signInWithProvider() is not implemented');
    }
    calls.add('provider:${provider.providerId}');
    return _complete(provider);
  }

  Future<UserCredential> _complete(AuthProvider provider) async {
    lastProvider = provider;
    final error = signInError;
    if (error != null) {
      signInError = null;
      throw error;
    }
    final user = nextUser!;
    currentUser = user;
    final token = nextAccessToken;
    return _FakeCredential(
      user,
      token == null ? null : GithubAuthProvider.credential(token),
    );
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeCredential implements UserCredential {
  _FakeCredential(this.user, this.credential);

  @override
  final User user;

  @override
  final AuthCredential? credential;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeUser implements User {
  _FakeUser(
    this._auth, {
    required this.emailValue,
    required this.emailVerifiedValue,
    required List<String> providers,
    this.displayNameValue = 'Ana Pérez',
    this.phoneValue,
    this.providerInfo = const {},
  }) : providerIds = [...providers];

  final String? displayNameValue;
  final String? phoneValue;

  /// Nombre y celular que trae cada proveedor en `providerData`.
  final Map<String, ({String? name, String? phone})> providerInfo;

  final _FakeAuth _auth;
  final String? emailValue;
  final bool emailVerifiedValue;
  final List<String> providerIds;
  final events = <String>[];
  final linkedCredentials = <AuthCredential>[];
  final linkedProviders = <AuthProvider>[];
  final unlinked = <String>[];
  FirebaseAuthException? reauthError;
  FirebaseAuthException? reloadError;
  FirebaseAuthException? linkError;
  FirebaseAuthException? deleteError;
  int deleteCalls = 0;

  @override
  String get uid => 'u1';

  @override
  String? get email => emailValue;

  @override
  bool get emailVerified => emailVerifiedValue;

  @override
  String? get displayName => displayNameValue;

  @override
  String? get phoneNumber => phoneValue;

  @override
  List<UserInfo> get providerData => [
    for (final id in providerIds)
      _FakeUserInfo(
        id,
        displayName: providerInfo[id]?.name,
        phoneNumber: providerInfo[id]?.phone,
      ),
  ];

  @override
  Future<void> reload() async {
    final error = reloadError;
    if (error != null) throw error;
  }

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      _FakeToken();

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    final error = linkError;
    if (error != null) throw error;
    linkedCredentials.add(credential);
    return _FakeCredential(this, credential);
  }

  @override
  Future<UserCredential> linkWithProvider(AuthProvider provider) async {
    final error = linkError;
    if (error != null) throw error;
    linkedProviders.add(provider);
    return _FakeCredential(this, null);
  }

  @override
  Future<User> unlink(String providerId) async {
    unlinked.add(providerId);
    providerIds.remove(providerId);
    return this;
  }

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    final error = reauthError;
    if (error != null) throw error;
    events.add('reauth:${credential.providerId}');
    return _FakeCredential(this, credential);
  }

  @override
  Future<UserCredential> linkWithPopup(AuthProvider provider) async {
    events.add('linkPopup:${provider.providerId}');
    linkedProviders.add(provider);
    return _FakeCredential(this, null);
  }

  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider provider) async {
    final error = reauthError;
    if (error != null) throw error;
    events.add('reauthPopup:${provider.providerId}');
    return _FakeCredential(this, null);
  }

  @override
  Future<UserCredential> reauthenticateWithProvider(
    AuthProvider provider,
  ) async {
    final error = reauthError;
    if (error != null) throw error;
    events.add('reauthProvider:${provider.providerId}');
    return _FakeCredential(this, null);
  }

  @override
  Future<void> delete() async {
    deleteCalls++;
    final error = deleteError;
    if (error != null) throw error;
    events.add('delete');
    _auth.currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeUserInfo implements UserInfo {
  _FakeUserInfo(this.providerId, {this.displayName, this.phoneNumber});

  @override
  final String providerId;

  @override
  final String? displayName;

  @override
  final String? phoneNumber;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeToken implements IdTokenResult {
  @override
  String? get token => 'id-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
