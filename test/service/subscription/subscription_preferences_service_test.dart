import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/service/subscription/subscription_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sin correo devuelve null sin escribir preferencias', () async {
    SharedPreferences.setMockInitialValues({});
    expect(
      await SubscriptionPreferencesService().getUserEmail(),
      isNull,
    );
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('lee y normaliza el correo guardado en preferencias', () async {
    SharedPreferences.setMockInitialValues({
      'auth.currentUserEmail': ' OTRO@MACHUCO.COM ',
    });
    expect(
      await SubscriptionPreferencesService().getUserEmail(),
      'otro@machuco.com',
    );
  });

  test('un correo vacío devuelve null', () async {
    SharedPreferences.setMockInitialValues({'auth.currentUserEmail': '  '});
    expect(
      await SubscriptionPreferencesService().getUserEmail(),
      isNull,
    );
  });
}
