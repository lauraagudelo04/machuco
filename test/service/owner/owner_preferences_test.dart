import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/service/owner/owner_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('guarda el último indicativo bajo el namespace owners', () async {
    final preferences = OwnerPreferences();

    expect(await preferences.loadLastCountryCodeId(), isNull);

    await preferences.saveLastCountryCodeId(2);

    expect(await preferences.loadLastCountryCodeId(), 2);
    final raw = await SharedPreferences.getInstance();
    expect(raw.getInt('owners.lastCountryCodeId'), 2);
  });
}
