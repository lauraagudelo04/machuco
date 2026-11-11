import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../views/auth/auth_test_support.dart';

RegistrationData _client({
  String phone = '3001234567',
  String email = 'ana@example.com',
}) => RegistrationData.client(
  firstNames: 'Ana',
  lastNames: 'Pérez',
  phoneCountryCodeId: testColombia.id,
  phoneNumber: phone,
  email: email,
  password: 'secreto123',
  birthDate: DateTime(1990, 5, 20),
);

void main() {
  late FakeAuthService auth;
  late LoginController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthService();
    controller = buildTestController(
      auth,
      phoneVerification: FakePhoneVerificationService(),
    );
    await controller.loadCountryPhoneCodes();
  });

  tearDown(() => controller.dispose());

  test('phoneNumberToVerify devuelve el celular con indicativo', () {
    expect(controller.phoneNumberToVerify(_client()), '+573001234567');
    expect(
      controller.phoneNumberToVerify(_client(phone: '300 123 4567')),
      '+573001234567',
    );
  });

  test('phoneNumberToVerify valida el formulario antes de enviar un SMS', () {
    for (final data in [
      _client(phone: '123'),
      _client(phone: '30012345ab'),
      _client(email: 'sin-arroba'),
    ]) {
      expect(
        () => controller.phoneNumberToVerify(data),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.type,
            'type',
            AuthFailureType.invalidInput,
          ),
        ),
      );
    }
  });

  test('registerAccount entrega la prueba del celular al servicio', () async {
    const proof = FakePhoneProof('+573001234567', '123456');

    await controller.registerAccount(_client().copyWith(phoneProof: proof));

    expect(auth.registered?.phoneProof, same(proof));
    expect(auth.registered?.phoneNumber, '+573001234567');
  });

  test('expone el servicio de verificación inyectado', () {
    expect(
      controller.phoneVerificationService,
      isA<FakePhoneVerificationService>(),
    );
  });
}
