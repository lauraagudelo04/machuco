import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/validators/auth_input_normalizer.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/models/auth/person_type.dart';

const _sqlInjections = <String>[
  "' OR '1'='1' --",
  "admin'; DROP TABLE users; --",
  '1; DELETE FROM auth_user_profile',
  "\" OR \"\"=\"",
  "x' UNION SELECT * FROM users --",
];

void main() {
  group('AuthValidators.email', () {
    test('acepta correos válidos y normaliza mayúsculas y espacios', () {
      expect(AuthValidators.email('ana@example.com'), isNull);
      expect(AuthValidators.email('  Ana.Perez+tag@Example.CO  '), isNull);
      expect(AuthValidators.email('a-b_c%d@sub.dominio.com.co'), isNull);
    });

    test('rechaza vacío, sin arroba, sin dominio y mal formados', () {
      for (final value in [
        null,
        '',
        '   ',
        'ana',
        'ana@',
        '@example.com',
        'ana@example',
        'ana@@example.com',
        'ana@exa mple.com',
        'ana..perez@example.com',
        '.ana@example.com',
        'ana.@example.com',
        'ana@-example.com',
        'ana@example..com',
      ]) {
        expect(AuthValidators.email(value), isNotNull, reason: '$value');
      }
    });

    test('rechaza más de 254 caracteres y local de más de 64', () {
      final long = '${'a' * 250}@b.co';
      expect(AuthValidators.email(long), isNotNull);
      expect(AuthValidators.email('${'a' * 65}@example.com'), isNotNull);
      expect(AuthValidators.email('${'a' * 64}@example.com'), isNull);
    });

    test('rechaza caracteres de control, emojis e invisibles', () {
      expect(AuthValidators.email('ana\n@example.com'), isNotNull);
      expect(AuthValidators.email('ana\u0000@example.com'), isNotNull);
      expect(AuthValidators.email('ana😀@example.com'), isNotNull);
      expect(AuthValidators.email('ana​@example.com'), isNotNull);
    });

    test('rechaza cadenas de inyección SQL como texto inválido', () {
      for (final attack in _sqlInjections) {
        expect(AuthValidators.email(attack), isNotNull, reason: attack);
        expect(AuthValidators.email('$attack@example.com'), isNotNull);
      }
    });
  });

  group('AuthValidators nombres', () {
    test('acepta tildes, ñ, guion, apóstrofo y espacios simples', () {
      for (final value in [
        'Ana',
        'José Ángel',
        'Núñez',
        "O'Brien",
        'María-José',
        '  Luz  ',
        'Zoë',
        'Li',
      ]) {
        expect(AuthValidators.firstNames(value), isNull, reason: value);
        expect(AuthValidators.lastNames(value), isNull, reason: value);
      }
    });

    test('rechaza vacío, 1 carácter y más de 50', () {
      expect(AuthValidators.firstNames(null), isNotNull);
      expect(AuthValidators.firstNames(''), isNotNull);
      expect(AuthValidators.firstNames('A'), isNotNull);
      expect(AuthValidators.firstNames('A' * 51), isNotNull);
      expect(AuthValidators.firstNames('A' * 50), isNull);
    });

    test('rechaza espacios dobles y separadores mal puestos', () {
      expect(AuthValidators.firstNames('Ana  María'), contains('espacios'));
      for (final value in ['-Ana', 'Ana-', "Ana''Mar", 'Ana--Mar', "'Ana"]) {
        expect(AuthValidators.firstNames(value), isNotNull, reason: value);
      }
    });

    test('rechaza dígitos, símbolos, emojis y control', () {
      for (final value in [
        'Ana1',
        'Ana_',
        'Ana@',
        'Ana😀',
        'Ana\tPérez',
        'Ana\u0000',
        'Ana​Pérez',
        '<script>',
      ]) {
        expect(AuthValidators.lastNames(value), isNotNull, reason: value);
      }
    });

    test('rechaza cadenas de inyección SQL', () {
      for (final attack in _sqlInjections) {
        expect(AuthValidators.firstNames(attack), isNotNull, reason: attack);
        expect(AuthValidators.companyName(attack), isNotNull, reason: attack);
      }
    });
  });

  group('AuthValidators.phone', () {
    final colombia = AuthValidators.phone(10, 10);
    final range = AuthValidators.phone(10, 11);

    test('acepta solo dígitos dentro del rango del país', () {
      expect(colombia('3001234567'), isNull);
      expect(range('3001234567'), isNull);
      expect(range('30012345678'), isNull);
    });

    test('rechaza longitud fuera de rango', () {
      expect(colombia('300123456'), isNotNull);
      expect(colombia('30012345678'), isNotNull);
      expect(range('300123456'), isNotNull);
      expect(range('300123456789'), isNotNull);
    });

    test('rechaza vacío, letras, símbolos, espacios internos y emojis', () {
      for (final value in [
        null,
        '',
        'abcdefghij',
        '300-123-4567',
        '300 123 4567',
        '+573001234567',
        '30012345٣7',
        '3001234567😀',
        '300123456\u0000',
      ]) {
        expect(colombia(value), isNotNull, reason: '$value');
      }
    });

    test('rechaza cadenas de inyección SQL', () {
      for (final attack in _sqlInjections) {
        expect(colombia(attack), isNotNull, reason: attack);
      }
    });
  });

  group('AuthValidators.nit', () {
    test('calcula el dígito de verificación DIAN', () {
      expect(AuthValidators.nitCheckDigit('860002964'), 4);
      expect(AuthValidators.nitCheckDigit('900123456'), 8);
      expect(AuthValidators.nitCheckDigit('1020304050'), 8);
      expect(AuthValidators.nitCheckDigit('800197268'), 4);
      // Resto 0 y 1 devuelven el propio resto.
      expect(AuthValidators.nitCheckDigit('0'), 0);
    });

    test('jurídica: 9 dígitos + DV, con o sin guion', () {
      final validator = AuthValidators.nit(PersonType.juridica);
      expect(validator('900123456-8'), isNull);
      expect(validator('9001234568'), isNull);
      expect(validator('  860002964-4 '), isNull);
      expect(validator('900123456-7'), contains('verificación'));
      expect(validator('90012345-6'), isNotNull); // 8 dígitos
      expect(validator('1020304050-8'), isNotNull); // 10 dígitos
    });

    test('natural: base de 6 a 10 dígitos + DV', () {
      final validator = AuthValidators.nit(PersonType.natural);
      expect(validator('1020304050-8'), isNull);
      expect(validator('10203040508'), isNull);
      expect(validator('900123456-8'), isNull);
      expect(validator('1020304050-3'), isNotNull);
      expect(
        validator('${AuthValidators.nitCheckDigit('12345')}'.padLeft(2, '1')),
        isNotNull,
      ); // base demasiado corta
      final sixDigits = '123456-${AuthValidators.nitCheckDigit('123456')}';
      expect(validator(sixDigits), isNull);
      final elevenDigits =
          '12345678901-${AuthValidators.nitCheckDigit('12345678901')}';
      expect(validator(elevenDigits), isNotNull);
    });

    test('rechaza vacío, letras, símbolos, puntos y múltiples guiones', () {
      final validator = AuthValidators.nit(PersonType.juridica);
      for (final value in [
        null,
        '',
        ' ',
        'abcdefghi-1',
        '900.123.456-8',
        '900123456--8',
        '900123456-88',
        '900-123-456-8',
        '900123456-',
        '-9001234568',
        '9',
        '900123456-8😀',
        '900123456\u0000-8',
      ]) {
        expect(validator(value), isNotNull, reason: '$value');
      }
    });

    test('rechaza cadenas de inyección SQL', () {
      for (final type in PersonType.values) {
        for (final attack in _sqlInjections) {
          expect(AuthValidators.nit(type)(attack), isNotNull, reason: attack);
        }
      }
    });
  });

  group('AuthValidators.companyName', () {
    test('acepta letras, números, espacios y . , & -', () {
      for (final value in [
        'Moteles del Sur S.A.S.',
        'Ana & Hijos, Ltda.',
        'Hotel 24-7',
        'Ñandú Café',
        'AB',
      ]) {
        expect(AuthValidators.companyName(value), isNull, reason: value);
      }
    });

    test('rechaza largo inválido y caracteres no permitidos', () {
      expect(AuthValidators.companyName(null), isNotNull);
      expect(AuthValidators.companyName('A'), isNotNull);
      expect(AuthValidators.companyName('A' * 121), isNotNull);
      expect(AuthValidators.companyName('A' * 120), isNull);
      for (final value in [
        'Moteles@Sur',
        "O'Brien SAS",
        'Moteles <b>',
        'Sur 😀',
        'Sur\nNorte',
        '.,&-',
      ]) {
        expect(AuthValidators.companyName(value), isNotNull, reason: value);
      }
    });
  });

  group('AuthValidators.birthDate', () {
    final today = DateTime(2026, 11, 4);
    DateTime clock() => today;

    test('acepta mayores de edad, incluso el día exacto de los 18', () {
      expect(
        AuthValidators.birthDate(DateTime(1990, 5, 20), clock: clock),
        isNull,
      );
      expect(
        AuthValidators.birthDate(DateTime(2008, 11, 4), clock: clock),
        isNull,
      );
    });

    test('rechaza menores, fechas futuras, nulas y anteriores a 1900', () {
      expect(AuthValidators.birthDate(null, clock: clock), isNotNull);
      expect(
        AuthValidators.birthDate(DateTime(2008, 11, 5), clock: clock),
        contains('18'),
      );
      expect(
        AuthValidators.birthDate(DateTime(2027, 1, 1), clock: clock),
        contains('futura'),
      );
      expect(
        AuthValidators.birthDate(DateTime(1899, 12, 31), clock: clock),
        isNotNull,
      );
    });

    test('texto: dd/mm/aaaa y aaaa-mm-dd; rechaza fechas inexistentes', () {
      final validator = AuthValidators.birthDateText(clock: clock);
      expect(validator('20/05/1990'), isNull);
      expect(validator('1990-05-20'), isNull);
      for (final value in [
        null,
        '',
        '31/02/2000',
        '29/02/2001',
        '00/01/2000',
        '32/01/2000',
        '01/13/2000',
        '20-05-1990',
        'ayer',
        '20/05/1990😀',
        "' OR '1'='1' --",
      ]) {
        expect(validator(value), isNotNull, reason: '$value');
      }
      expect(validator('29/02/2000'), isNull); // bisiesto real
    });
  });

  group('AuthValidators contraseña', () {
    test('mínimo 8 caracteres, sin reglas de complejidad', () {
      expect(AuthValidators.password('12345678'), isNull);
      expect(AuthValidators.password('contraseña con espacios'), isNull);
      expect(AuthValidators.password('1234567'), isNotNull);
      expect(AuthValidators.password(''), isNotNull);
      expect(AuthValidators.password(null), isNotNull);
    });

    test('no recorta espacios y rechaza control y emojis', () {
      expect(AuthValidators.password('       a'), isNull);
      expect(AuthValidators.password('        '), isNull);
      expect(AuthValidators.password('abcdefg\n'), isNotNull);
      expect(AuthValidators.password('abcdefg😀'), isNotNull);
      expect(AuthValidators.password('abc\u0000defgh'), isNotNull);
    });

    test('una cadena SQL se trata como texto literal (no se interpreta)', () {
      expect(AuthValidators.password("' OR '1'='1' --"), isNull);
      expect(AuthValidators.password("admin'; DROP TABLE users; --"), isNull);
    });

    test('confirmPassword compara con la contraseña original', () {
      var original = 'secreto123';
      final validator = AuthValidators.confirmPassword(() => original);
      expect(validator('secreto123'), isNull);
      expect(validator('secreto124'), contains('coinciden'));
      expect(validator(''), isNotNull);
      expect(validator(null), isNotNull);
      original = 'otra-clave';
      expect(validator('secreto123'), isNotNull);
      expect(validator('otra-clave'), isNull);
    });
  });

  group('AuthValidators.rejectionReason', () {
    test('exige entre 10 y 300 caracteres', () {
      expect(AuthValidators.rejectionReason('muy corto'), isNotNull);
      expect(AuthValidators.rejectionReason('NIT no coincide con RUT'), isNull);
      expect(AuthValidators.rejectionReason('a' * 300), isNull);
      expect(AuthValidators.rejectionReason('a' * 301), isNotNull);
      expect(AuthValidators.rejectionReason(null), isNotNull);
      expect(AuthValidators.rejectionReason('   '), isNotNull);
    });

    test('rechaza control y emojis, permite saltos de línea', () {
      expect(AuthValidators.rejectionReason('Documento\nilegible'), isNull);
      expect(
        AuthValidators.rejectionReason('Documento ilegible\u0000'),
        isNotNull,
      );
      expect(
        AuthValidators.rejectionReason('Documento ilegible 😀'),
        isNotNull,
      );
    });
  });

  group('AuthInputNormalizer', () {
    test('normaliza correo, texto, dígitos y NIT', () {
      expect(
        AuthInputNormalizer.email('  Ana@Example.COM '),
        'ana@example.com',
      );
      expect(AuthInputNormalizer.email(null), '');
      expect(AuthInputNormalizer.text('  Ana  '), 'Ana');
      expect(AuthInputNormalizer.digits('300 123-4567'), '3001234567');
      expect(AuthInputNormalizer.nit('9001234568'), '900123456-8');
      expect(AuthInputNormalizer.nit(' 900123456-8 '), '900123456-8');
      expect(AuthInputNormalizer.nit('abc'), isNull);
      expect(AuthInputNormalizer.nit('9'), isNull);
      expect(AuthInputNormalizer.nit(null), isNull);
    });
  });
}
