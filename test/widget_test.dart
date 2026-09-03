import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/main.dart';

void main() {
  testWidgets('shows login screen', (tester) async {
    await tester.pumpWidget(const MachucoApp());
    await tester.pumpAndSettle();

    expect(find.text('Machuco'), findsOneWidget);
    expect(find.text('Inicia sesión o crea tu cuenta'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Registrarse'), findsOneWidget);
  });
}
