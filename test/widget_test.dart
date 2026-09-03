import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/main.dart';

void main() {
  testWidgets('Shows login screen by default', (WidgetTester tester) async {
    await tester.pumpWidget(const MachucoApp());

    expect(find.text('Machuco'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('Registrarse'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
