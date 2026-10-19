import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/service/subscription/subscription_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sin correo devuelve el dummy sin escribir preferencias', () async {
    SharedPreferences.setMockInitialValues({});
    expect(
      await SubscriptionPreferencesService().getUserEmail(),
      'propietario.test@machuco.com',
    );
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('lee y normaliza el correo guardado en preferencias', () async {
    SharedPreferences.setMockInitialValues({
      'subscription.userEmail': ' OTRO@MACHUCO.COM ',
    });
    expect(
      await SubscriptionPreferencesService().getUserEmail(),
      'otro@machuco.com',
    );
  });

  test('un correo vacío devuelve el dummy', () async {
    SharedPreferences.setMockInitialValues({'subscription.userEmail': '  '});
    expect(
      await SubscriptionPreferencesService().getUserEmail(),
      'propietario.test@machuco.com',
    );
  });
}
