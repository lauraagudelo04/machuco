import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/validators/document_number_validator.dart';
import 'package:machuco/models/auth/document_type.dart';

void main() {
  const cc = DocumentTypeOption(
    id: 1,
    code: 'CC',
    name: 'Cédula de ciudadanía',
    pattern: r'^\d{6,10}$',
    example: '1020304050',
  );
  const brokenRegex = DocumentTypeOption(
    id: 9,
    code: 'CE',
    name: 'Cédula de extranjería',
    pattern: r'^([0-9{6,$',
    example: '345678',
  );

  group('DocumentNumberValidator', () {
    test('acepta un número que cumple el pattern, recortando espacios', () {
      expect(DocumentNumberValidator.validate('1020304050', cc), isNull);
      expect(DocumentNumberValidator.validate('  1020304050  ', cc), isNull);
      expect(DocumentNumberValidator.validate('1.020.304.050', cc), isNull);
    });

    test('rechaza lo que no cumple y muestra el ejemplo', () {
      final error = DocumentNumberValidator.validate('ABC123', cc);
      expect(error, contains('1020304050'));
      expect(DocumentNumberValidator.validate('123', cc), isNotNull);
      expect(
        DocumentNumberValidator.validate('   ', cc),
        DocumentNumberValidator.emptyMessage,
      );
      expect(DocumentNumberValidator.validate(null, cc), isNotNull);
    });

    test('con un regex roto usa la validación básica y no falla', () {
      expect(DocumentNumberValidator.validate('AB12345', brokenRegex), isNull);
      expect(DocumentNumberValidator.validate('12', brokenRegex), isNotNull);
      expect(
        DocumentNumberValidator.validate('A' * 21, brokenRegex),
        isNotNull,
      );
      expect(DocumentNumberValidator.validate('123456', null), isNull);
    });

    test("rechaza ' OR '1'='1' -- con cualquier tipo", () {
      const injection = "' OR '1'='1' --";
      expect(DocumentNumberValidator.validate(injection, cc), isNotNull);
      expect(
        DocumentNumberValidator.validate(injection, brokenRegex),
        isNotNull,
      );
      expect(DocumentNumberValidator.validate(injection, null), isNotNull);
    });

    test('forType devuelve un validador de campo', () {
      final validator = DocumentNumberValidator.forType(cc);
      expect(validator('1020304050'), isNull);
      expect(validator(''), isNotNull);
    });
  });

  group('DocumentTypeOption', () {
    test('lee la fila de Supabase y descarta las incompletas', () {
      final option = DocumentTypeOption.tryFromJson({
        'id': 1,
        'code': ' CC ',
        'name': 'Cédula de ciudadanía',
        'pattern': r'^\d{6,10}$',
        'example': '1020304050',
        'sort_order': 1,
      })!;
      expect(option.code, 'CC');
      expect(option.isOfferedInRegistration, isTrue);
      expect(option.domainType?.name, 'citizenshipCard');
      expect(DocumentTypeOption.tryFromJson({'id': 1, 'code': 'CC'}), isNull);
      expect(
        DocumentTypeOption.tryFromJson({
          'id': 2,
          'code': 'NIT',
          'name': 'NIT',
          'pattern': r'^x$',
          'example': '1',
        })!.isOfferedInRegistration,
        isFalse,
      );
    });
  });
}
