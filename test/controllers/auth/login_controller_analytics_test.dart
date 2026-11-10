import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/service/analytics/analytics_service.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../service/analytics/recording_analytics_service.dart';
import '../../views/auth/auth_test_support.dart';

void main() {
  late FakeAuthService auth;
  late RecordingAnalyticsService analytics;
  late LoginController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthService();
    analytics = RecordingAnalyticsService();
    controller = LoginController(
      authService: auth,
      catalogRepository: FakeCatalogRepository(),
      analytics: analytics,
    );
  });

  tearDown(() => controller.dispose());

  test('an email login reports login(password) and the user role', () async {
    await controller.login(email: 'ana@example.com', password: 'secreto123');

    expect(analytics.events.single.name, 'login');
    expect(analytics.events.single.parameters, {
      'method': AnalyticsLoginMethod.password,
    });
    expect(analytics.users.single, (id: 'u1', role: 'client'));
  });

  test('a failed login reports nothing', () async {
    auth.loginFailure = const AuthFailure(
      AuthFailureType.invalidCredentials,
      'Credenciales inválidas',
    );

    await expectLater(
      controller.login(email: 'ana@example.com', password: 'secreto123'),
      throwsA(isA<AuthFailure>()),
    );

    expect(analytics.events, isEmpty);
    expect(analytics.users, isEmpty);
  });

  test('a registration reports sign_up(password)', () async {
    await controller.loadCountryPhoneCodes();

    await controller.registerAccount(
      RegistrationData.client(
        firstNames: 'Ana',
        lastNames: 'Pérez',
        phoneCountryCodeId: testColombia.id,
        phoneNumber: '3001234567',
        email: 'ana@example.com',
        password: 'secreto123',
        birthDate: DateTime(1990, 5, 20),
      ),
    );

    expect(analytics.events.single.name, 'sign_up');
    expect(analytics.events.single.parameters, {
      'method': AnalyticsLoginMethod.password,
    });
  });

  test('logout clears the analytics user', () async {
    await controller.login(email: 'ana@example.com', password: 'secreto123');
    await controller.logout();

    expect(analytics.users.last, (id: null, role: null));
  });
}
