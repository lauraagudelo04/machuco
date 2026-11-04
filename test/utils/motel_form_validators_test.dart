import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/utils/motel_form_validators.dart';

void main() {
  group('MotelFormValidators.validateName', () {
    test('rechaza nombre vacío', () {
      expect(MotelFormValidators.validateName('  '), isNotNull);
    });

    test('rechaza nombre demasiado corto', () {
      expect(MotelFormValidators.validateName('ab'), isNotNull);
    });

    test('acepta nombre válido', () {
      expect(MotelFormValidators.validateName('Motel Paraíso'), isNull);
    });
  });

  group('MotelFormValidators.validateDescription', () {
    test('permite descripción vacía', () {
      expect(MotelFormValidators.validateDescription(''), isNull);
    });

    test('rechaza descripción demasiado larga', () {
      expect(MotelFormValidators.validateDescription('a' * 501), isNotNull);
    });
  });

  group('MotelFormValidators.validateEmail', () {
    test('rechaza correo vacío', () {
      expect(MotelFormValidators.validateEmail(''), isNotNull);
    });

    test('rechaza correo sin formato', () {
      expect(MotelFormValidators.validateEmail('correo'), isNotNull);
      expect(MotelFormValidators.validateEmail('correo@dominio'), isNotNull);
    });

    test('acepta correo válido', () {
      expect(MotelFormValidators.validateEmail('reservas@motel.com'), isNull);
    });
  });

  group('MotelFormValidators.validatePhone', () {
    test('rechaza teléfono vacío', () {
      expect(MotelFormValidators.validatePhone(''), isNotNull);
    });

    test('rechaza letras', () {
      expect(MotelFormValidators.validatePhone('300ABC1234'), isNotNull);
    });

    test('rechaza pocos dígitos', () {
      expect(MotelFormValidators.validatePhone('12345'), isNotNull);
    });

    test('acepta teléfono con espacios e indicativo', () {
      expect(MotelFormValidators.validatePhone('+57 300 123 4567'), isNull);
    });
  });

  group('MotelFormValidators.validateRoomCount', () {
    test('rechaza vacío', () {
      expect(MotelFormValidators.validateRoomCount(''), isNotNull);
    });

    test('rechaza cero y negativos', () {
      expect(MotelFormValidators.validateRoomCount('0'), isNotNull);
      expect(MotelFormValidators.validateRoomCount('-3'), isNotNull);
    });

    test('rechaza texto', () {
      expect(MotelFormValidators.validateRoomCount('diez'), isNotNull);
    });

    test('acepta cantidad válida', () {
      expect(MotelFormValidators.validateRoomCount('15'), isNull);
    });
  });

  group('MotelFormValidators.validateNit', () {
    test('rechaza NIT vacío', () {
      expect(MotelFormValidators.validateNit(''), isNotNull);
    });

    test('rechaza NIT con formato inválido', () {
      expect(MotelFormValidators.validateNit('900ABC'), isNotNull);
      expect(MotelFormValidators.validateNit('123'), isNotNull);
    });

    test('acepta NIT con y sin dígito de verificación', () {
      expect(MotelFormValidators.validateNit('900123456-1'), isNull);
      expect(MotelFormValidators.validateNit('900123456'), isNull);
    });
  });

  group('MotelFormValidators.validateAddress', () {
    test('rechaza dirección vacía o muy corta', () {
      expect(MotelFormValidators.validateAddress(''), isNotNull);
      expect(MotelFormValidators.validateAddress('Cll'), isNotNull);
    });

    test('acepta dirección válida', () {
      expect(MotelFormValidators.validateAddress('Calle 123 # 45-67'), isNull);
    });
  });

  group('MotelFormValidators.validateGeneralLocation', () {
    test('permite ubicación vacía', () {
      expect(MotelFormValidators.validateGeneralLocation(''), isNull);
    });

    test('rechaza ubicación demasiado larga', () {
      expect(MotelFormValidators.validateGeneralLocation('a' * 101), isNotNull);
    });
  });

  group('MotelFormValidators.validatePaymentMethods', () {
    test('rechaza lista vacía', () {
      expect(MotelFormValidators.validatePaymentMethods([]), isNotNull);
    });

    test('acepta al menos un método', () {
      expect(MotelFormValidators.validatePaymentMethods(['Efectivo']), isNull);
    });
  });
}
