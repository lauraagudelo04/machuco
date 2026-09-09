import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/main.dart';

void main() {
  testWidgets('muestra la pantalla de inicio de sesión', (tester) async {
    await tester.pumpWidget(const MachucoApp());
    await tester.pump();

    expect(find.text('Machuco'), findsOneWidget);
    expect(find.text('Inicia sesión o crea tu cuenta'), findsOneWidget);
  });
}
