import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/auth/auth_catalog_repository.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/auth/auth_service.dart';

const testColombia = CountryPhoneCode(
  id: 1,
  isoCode: 'CO',
  countryName: 'Colombia',
  dialCode: '+57',
  phoneMinLength: 10,
  phoneMaxLength: 10,
);

/// Catálogo falso: sin red ni SQLite.
final class FakeCatalogRepository extends AuthCatalogRepository {
  FakeCatalogRepository({
    this.plans = const [
      SubscriptionPlanOption(id: 1, name: 'Básico'),
      SubscriptionPlanOption(id: 2, name: 'Premium'),
    ],
    this.failPlans = false,
  }) : super(
         supabaseUrl: '',
         publishableKey: '',
         preferences: AuthPreferences(),
       );

  List<SubscriptionPlanOption> plans;
  bool failPlans;

  @override
  Future<List<CountryPhoneCode>> getCountryPhoneCodes({
    bool forceRefresh = false,
  }) async => const [testColombia];

  @override
  Future<List<SubscriptionPlanOption>> getSubscriptionPlans({
    bool forceRefresh = false,
  }) async {
    if (failPlans) {
      throw const AuthCatalogRepositoryException('Sin conexión');
    }
    return plans;
  }
}

/// Servicio de autenticación falso con registro de llamadas.
final class FakeAuthService implements AuthService {
  AuthFailure? loginFailure;
  AuthFailure? resetFailure;
  AuthFailure? deleteFailure;
  AuthSession? loginResult;
  RegistrationData? registered;
  final List<String> resetEmails = [];
  final List<String> deletedWithPasswords = [];
  bool logoutCalled = false;

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final failure = loginFailure;
    if (failure != null) throw failure;
    return loginResult ??
        AuthSession(
          userId: 'u1',
          name: 'Ana Pérez',
          email: email,
          role: RegisteredUserRole.client,
          accessToken: 'a',
          idToken: 'i',
        );
  }

  @override
  Future<AuthSession> loginWithGoogle({bool preferSignup = false}) =>
      throw UnimplementedError();

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
    registered = data;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    final failure = resetFailure;
    if (failure != null) throw failure;
    resetEmails.add(email);
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final failure = deleteFailure;
    if (failure != null) throw failure;
    deletedWithPasswords.add(password);
  }
}

LoginController buildTestController(
  FakeAuthService auth, {
  FakeCatalogRepository? catalog,
}) => LoginController(
  authService: auth,
  catalogRepository: catalog ?? FakeCatalogRepository(),
);

Widget testApp(Widget home, {RouteFactory? onGenerateRoute}) => MaterialApp(
  theme: AppTheme.light,
  home: home,
  onGenerateRoute: onGenerateRoute,
);

/// Textos visibles que mencionan un documento de identidad.
Iterable<String> identityDocumentTexts(Iterable<Text> texts) => texts
    .map((text) => text.data ?? '')
    .where(
      (data) => RegExp(
        'documento|cédula|cedula',
        caseSensitive: false,
      ).hasMatch(data),
    );
