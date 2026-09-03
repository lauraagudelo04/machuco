import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/main.dart';

void main() {
  testWidgets('shows booking role demo home', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Demostración por perfil'), findsOneWidget);
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Propietario'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
  });
}
