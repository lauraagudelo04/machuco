import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/database/repository/auth/auth_catalog_dao.dart';
import 'package:machuco/database/repository/auth/auth_catalog_repository.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _colombia = CountryPhoneCode(
  id: 1,
  isoCode: 'CO',
  countryName: 'Colombia',
  dialCode: '+57',
  phoneMinLength: 10,
  phoneMaxLength: 10,
  sortOrder: 1,
);

const _argentina = CountryPhoneCode(
  id: 7,
  isoCode: 'AR',
  countryName: 'Argentina',
  dialCode: '+54',
  phoneMinLength: 10,
  phoneMaxLength: 11,
  sortOrder: 3,
);

void main() {
  late AuthPreferences preferences;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    preferences = AuthPreferences(
      preferences: SharedPreferencesLocalService(namespace: 'auth'),
    );
  });

  group('correo compartido', () {
    test('guarda el correo normalizado al iniciar sesión', () async {
      final controller = LoginController(
        authService: _FakeAuthService(sessionEmail: '  Ana@Example.COM '),
        preferences: preferences,
      );

      await controller.login(email: 'ana@example.com', password: 'secret');

      expect(controller.currentUserEmail, 'ana@example.com');
      expect(await preferences.loadCurrentUserEmail(), 'ana@example.com');
    });

    test('otra funcionalidad lee el correo sin conocer las claves', () async {
      final controller = LoginController(
        authService: _FakeAuthService(sessionEmail: 'ana@example.com'),
        preferences: preferences,
      );
      await controller.login(email: 'ana@example.com', password: 'secret');

      final otherFeatureReader = AuthPreferences(
        preferences: SharedPreferencesLocalService(namespace: 'auth'),
      );

      expect(
        await otherFeatureReader.loadCurrentUserEmail(),
        'ana@example.com',
      );
    });

    test('devuelve null cuando no hay correo guardado', () async {
      expect(await preferences.loadCurrentUserEmail(), isNull);
      final controller = LoginController(preferences: preferences);
      expect(await controller.loadCurrentUserEmail(), isNull);
    });

    test('cerrar sesión borra el correo de sesión', () async {
      final controller = LoginController(
        authService: _FakeAuthService(sessionEmail: 'ana@example.com'),
        preferences: preferences,
      );
      await controller.login(email: 'ana@example.com', password: 'secret');

      await controller.logout();

      expect(controller.currentUserEmail, isNull);
      expect(await preferences.loadCurrentUserEmail(), isNull);
    });

    test('si la sesión no se restaura, borra el correo guardado', () async {
      await preferences.saveCurrentUserEmail('viejo@example.com');
      final controller = LoginController(
        authService: _FakeAuthService(sessionEmail: 'x@example.com'),
        preferences: preferences,
      );

      await controller.restoreSession();

      expect(await preferences.loadCurrentUserEmail(), isNull);
    });

    test('un fallo del almacenamiento no impide iniciar sesión', () async {
      final controller = LoginController(
        authService: _FakeAuthService(sessionEmail: 'ana@example.com'),
        preferences: _ThrowingAuthPreferences(),
      );

      final session = await controller.login(
        email: 'ana@example.com',
        password: 'secret',
      );

      expect(session.email, 'ana@example.com');
    });
  });

  group('indicativos', () {
    test('sin repositorio usa la semilla de Colombia (+57)', () async {
      final controller = LoginController(preferences: preferences);

      await controller.loadCountryPhoneCodes();

      expect(controller.selectedCountryPhoneCode?.dialCode, '+57');
      expect(controller.selectedCountryPhoneCode?.isDevelopmentSeed, isTrue);
    });

    test('preselecciona el último indicativo guardado', () async {
      await preferences.saveLastCountryCodeId(_argentina.id);
      final controller = LoginController(
        preferences: preferences,
        catalogRepository: _FakeCatalogRepository(preferences, const [
          _colombia,
          _argentina,
        ]),
      );

      await controller.loadCountryPhoneCodes();

      expect(controller.selectedCountryPhoneCode?.isoCode, 'AR');
    });

    test('sin último indicativo preselecciona Colombia', () async {
      final controller = LoginController(
        preferences: preferences,
        catalogRepository: _FakeCatalogRepository(preferences, const [
          _argentina,
          _colombia,
        ]),
      );

      await controller.loadCountryPhoneCodes();

      expect(controller.selectedCountryPhoneCode?.isoCode, 'CO');
    });

    test('seleccionar un indicativo lo recuerda', () async {
      final controller = LoginController(
        preferences: preferences,
        catalogRepository: _FakeCatalogRepository(preferences, const [
          _colombia,
          _argentina,
        ]),
      );
      await controller.loadCountryPhoneCodes();

      await controller.selectCountryPhoneCode(_argentina);

      expect(await preferences.loadLastCountryCodeId(), _argentina.id);
    });

    test('expone el error si el maestro no se puede cargar', () async {
      final controller = LoginController(
        preferences: preferences,
        catalogRepository: _FakeCatalogRepository(
          preferences,
          const [],
          shouldFail: true,
        ),
      );

      await controller.loadCountryPhoneCodes();

      expect(controller.countryPhoneCodesError, isNotNull);
      expect(controller.selectedCountryPhoneCode, isNull);
      expect(
        controller.validatePhoneNumber('3001234567'),
        'Selecciona el indicativo de tu país.',
      );
    });

    test('valida la longitud del celular según el país', () async {
      final controller = LoginController(
        preferences: preferences,
        catalogRepository: _FakeCatalogRepository(preferences, const [
          _colombia,
          _argentina,
        ]),
      );
      await controller.loadCountryPhoneCodes();

      expect(controller.validatePhoneNumber('300 123 4567'), isNull);
      expect(controller.validatePhoneNumber('300123'), isNotNull);
      expect(controller.validatePhoneNumber("' OR '1'='1' --"), isNotNull);

      await controller.selectCountryPhoneCode(_argentina);
      expect(controller.validatePhoneNumber('11234567890'), isNull);
    });

    test('registra el celular con el indicativo seleccionado', () async {
      final auth = _FakeAuthService(sessionEmail: 'ana@example.com');
      final controller = LoginController(
        authService: auth,
        preferences: preferences,
        catalogRepository: _FakeCatalogRepository(preferences, const [
          _colombia,
        ]),
      );
      await controller.loadCountryPhoneCodes();

      await controller.register(
        fullName: 'Ana Pérez',
        email: ' Ana@Example.com ',
        phoneNumber: '300 123 4567',
        password: 'SecurePassword12345',
        role: RegisteredUserRole.client,
      );

      expect(auth.registeredPhoneNumber, '+573001234567');
      expect(auth.registeredEmail, 'ana@example.com');
      expect(await preferences.loadLastCountryCodeId(), _colombia.id);
    });
  });
}

final class _FakeCatalogRepository extends AuthCatalogRepository {
  _FakeCatalogRepository(
    AuthPreferences preferences,
    this._codes, {
    this.shouldFail = false,
  }) : super(
         baseUrl: '',
         apiKey: '',
         catalogDao: AuthCatalogDao(() => throw UnimplementedError()),
         preferences: preferences,
       );

  final List<CountryPhoneCode> _codes;
  final bool shouldFail;

  @override
  Future<List<CountryPhoneCode>> getCountryPhoneCodes({
    bool forceRefresh = false,
  }) async {
    if (shouldFail) {
      throw const AuthCatalogRepositoryException('sin conexión');
    }
    return _codes;
  }
}

final class _ThrowingAuthPreferences extends AuthPreferences {
  _ThrowingAuthPreferences()
    : super(preferences: SharedPreferencesLocalService(namespace: 'auth'));

  @override
  Future<void> saveCurrentUserEmail(String email) =>
      Future.error(StateError('almacenamiento no disponible'));
}

final class _FakeAuthService implements AuthService {
  _FakeAuthService({required this.sessionEmail});

  final String sessionEmail;
  String? registeredPhoneNumber;
  String? registeredEmail;

  AuthSession get _session => AuthSession(
    userId: 'user-1',
    name: 'Ana',
    email: sessionEmail,
    role: RegisteredUserRole.client,
    accessToken: 'access',
    idToken: 'header.payload.signature',
  );

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => _session;

  @override
  Future<AuthSession> loginWithGoogle({bool preferSignup = false}) async =>
      _session;

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required RegisteredUserRole role,
  }) async {
    registeredEmail = email;
    registeredPhoneNumber = phoneNumber;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> logout() async {}
}
