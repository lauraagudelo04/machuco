import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/pqrs/pqrs_settings.dart';

void main() {
  test('max_photos de Supabase se respeta hasta el tope de las reglas', () {
    expect(PqrsSettings.fromJson({'max_photos': 5}).maxPhotos, 5);
    expect(PqrsSettings.fromJson({'max_photos': 10}).maxPhotos, 10);
    expect(PqrsSettings.fromJson({'max_photos': 99}).maxPhotos, 10);
  });

  test(
    'max_photos ausente, inválido o no positivo usa el valor por defecto',
    () {
      expect(PqrsSettings.fromJson({}).maxPhotos, 3);
      expect(PqrsSettings.fromJson({'max_photos': 'x'}).maxPhotos, 3);
      expect(PqrsSettings.fromJson({'max_photos': 0}).maxPhotos, 3);
    },
  );
}
