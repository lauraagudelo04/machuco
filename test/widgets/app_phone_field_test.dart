import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/widgets/form/app_phone_field.dart';

const _codes = [
  CountryPhoneCode(
    id: 1,
    isoCode: 'CO',
    countryName: 'Colombia',
    dialCode: '+57',
  ),
  CountryPhoneCode(
    id: 3,
    isoCode: 'MX',
    countryName: 'México',
    dialCode: '+52',
  ),
  CountryPhoneCode(
    id: 10,
    isoCode: 'PA',
    countryName: 'Panamá',
    dialCode: '+507',
  ),
];

void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    ValueChanged<CountryPhoneCode>? onSelected,
  }) async {
    final phoneController = TextEditingController();
    addTearDown(phoneController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppPhoneField(
            countryCodes: _codes,
            selectedCountryCode: _codes.first,
            onCountryCodeSelected: onSelected ?? (_) {},
            phoneController: phoneController,
          ),
        ),
      ),
    );
  }

  testWidgets('muestra la bandera y el indicativo seleccionado', (
    tester,
  ) async {
    await pumpField(tester);

    expect(find.byType(CountryFlag), findsOneWidget);
    expect(find.text('+57'), findsOneWidget);
  });

  testWidgets('lista los países con su bandera y permite filtrar', (
    tester,
  ) async {
    CountryPhoneCode? selected;
    await pumpField(tester, onSelected: (code) => selected = code);

    await tester.tap(find.byKey(const ValueKey('phone-country-code-button')));
    await tester.pumpAndSettle();

    expect(find.text('Colombia'), findsOneWidget);
    expect(find.text('México'), findsOneWidget);
    expect(find.text('Panamá'), findsOneWidget);
    // Una bandera en el campo y una por cada país de la lista.
    expect(find.byType(CountryFlag), findsNWidgets(4));

    await tester.enterText(find.byType(TextField).last, "pan'; --");
    await tester.pumpAndSettle();
    expect(find.text('Sin resultados'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'pan');
    await tester.pumpAndSettle();
    expect(find.text('Colombia'), findsNothing);

    await tester.tap(find.text('Panamá'));
    await tester.pumpAndSettle();
    expect(selected?.isoCode, 'PA');
  });
}
