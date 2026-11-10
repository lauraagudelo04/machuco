import 'package:machuco/controllers/auth/validators/auth_input_normalizer.dart';
import 'package:machuco/models/auth/person_type.dart';

/// Validadores de formato de los formularios de autenticación y registro.
///
/// Son funciones puras (`String? Function(String?)`) que devuelven el mensaje
/// de error en español o `null` si el valor es válido. Se usan tal cual como
/// `validator` de un `TextFormField`.
///
/// IMPORTANTE: la validación del cliente solo mejora la experiencia. Nunca
/// sustituye la del backend (Firebase Auth y `firestore.rules`), que es la
/// autoridad. Aquí se simula el subconjunto de reglas de formato que el
/// backend no puede expresar con un mensaje comprensible.
///
/// Ningún valor se interpola jamás en SQL: la protección contra inyección
/// SQL se logra con consultas parametrizadas (Floor) y porque estos
/// validadores rechazan los caracteres que no pertenecen al formato.
abstract final class AuthValidators {
  static const emailMaxLength = 254;
  static const nameMinLength = 2;
  static const nameMaxLength = 50;
  static const companyNameMinLength = 2;
  static const companyNameMaxLength = 120;
  static const passwordMinLength = 8;
  static const minimumAge = 18;
  static const rejectionReasonMinLength = 10;
  static const rejectionReasonMaxLength = 300;

  /// Pesos oficiales de la DIAN, del dígito menos significativo al más.
  static const _nitWeights = <int>[
    3,
    7,
    13,
    17,
    19,
    23,
    29,
    37,
    41,
    43,
    47,
    53,
    59,
    67,
    71,
  ];

  // Letras latinas con tildes, ñ y diéresis (más marcas combinantes).
  static const _letters = r'A-Za-zÀ-ÖØ-öø-ÿĀ-ſ̀-ͯ';

  static final _emailPattern = RegExp(
    r'^[a-z0-9]+(?:[._%+-][a-z0-9]+)*@'
    r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
    r'(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$',
  );
  static final _namePattern = RegExp('^[$_letters]+(?:[ \'’-][$_letters]+)*\$');
  static final _companyPattern = RegExp('^[${_letters}0-9 .,&-]+\$');
  static final _alphanumeric = RegExp('[${_letters}0-9]');

  // ---------------------------------------------------------------- correo

  /// Correo `usuario@dominio.ext`, máx. 254 caracteres. Recorta espacios y
  /// compara en minúsculas, por lo que no marca error por ello.
  static String? email(String? value) {
    final normalized = AuthInputNormalizer.email(value);
    if (normalized.isEmpty) return 'Ingresa tu correo electrónico.';
    if (_hasForbiddenCharacters(normalized)) {
      return 'El correo contiene caracteres no permitidos.';
    }
    if (normalized.length > emailMaxLength) {
      return 'El correo no puede superar $emailMaxLength caracteres.';
    }
    if (!_emailPattern.hasMatch(normalized)) {
      return 'Ingresa un correo válido, por ejemplo usuario@dominio.com.';
    }
    final localPart = normalized.split('@').first;
    if (localPart.length > 64) {
      return 'La parte anterior a @ no puede superar 64 caracteres.';
    }
    return null;
  }

  // ---------------------------------------------------------------- nombres

  /// Nombres (campo "Nombres").
  static String? firstNames(String? value) => _names(value, 'tus nombres');

  /// Apellidos (campo "Apellidos").
  static String? lastNames(String? value) => _names(value, 'tus apellidos');

  /// Nombre genérico (mismas reglas que [firstNames]).
  static String? names(String? value) => _names(value, 'tu nombre');

  static String? _names(String? value, String label) {
    final text = AuthInputNormalizer.text(value);
    if (text.isEmpty) return 'Ingresa $label.';
    if (_hasForbiddenCharacters(text)) {
      return 'Solo se admiten letras, espacios, guion y apóstrofo.';
    }
    if (text.contains('  ')) {
      return 'No uses espacios dobles.';
    }
    if (_length(text) < nameMinLength || _length(text) > nameMaxLength) {
      return 'Debe tener entre $nameMinLength y $nameMaxLength caracteres.';
    }
    if (!_namePattern.hasMatch(text)) {
      return 'Solo se admiten letras, espacios, guion y apóstrofo.';
    }
    return null;
  }

  // ---------------------------------------------------------------- celular

  /// Celular: solo dígitos y longitud entre [minLength] y [maxLength] (los
  /// del país seleccionado). Quita únicamente espacios en los extremos; el
  /// formulario debe filtrar el resto con su formateador de entrada.
  static String? Function(String?) phone(int minLength, int maxLength) {
    return (value) {
      final text = AuthInputNormalizer.text(value);
      if (text.isEmpty) return 'Ingresa tu número de celular.';
      if (!RegExp(r'^[0-9]+$').hasMatch(text)) {
        return 'El celular solo admite dígitos.';
      }
      if (text.length < minLength || text.length > maxLength) {
        final range = minLength == maxLength
            ? '$minLength'
            : '$minLength a $maxLength';
        return 'Ingresa un número de $range dígitos.';
      }
      return null;
    };
  }

  // -------------------------------------------------------------------- NIT

  /// Dígito de verificación DIAN (módulo 11, pesos 3,7,13,...) para la
  /// [base] numérica (hasta 15 dígitos).
  static int nitCheckDigit(String base) {
    var sum = 0;
    for (var i = 0; i < base.length; i++) {
      final digit = base.codeUnitAt(base.length - 1 - i) - 0x30;
      sum += digit * _nitWeights[i];
    }
    final remainder = sum % 11;
    return remainder > 1 ? 11 - remainder : remainder;
  }

  /// NIT del propietario. Jurídica: 9 dígitos + DV. Natural: 6 a 10 dígitos
  /// + DV. El guion antes del DV es opcional (`900123456-8` o `9001234568`).
  static String? Function(String?) nit(PersonType personType) {
    return (value) {
      final text = AuthInputNormalizer.text(value);
      if (text.isEmpty) return 'Ingresa el NIT.';
      final match = RegExp(r'^(\d+)(?:-(\d))?$').firstMatch(text);
      if (match == null) {
        return 'El NIT solo admite dígitos y un guion antes del dígito de '
            'verificación.';
      }
      final first = match.group(1) ?? '';
      final explicitCheck = match.group(2);
      final String base;
      final String check;
      if (explicitCheck != null) {
        base = first;
        check = explicitCheck;
      } else {
        if (first.length < 2) return 'El NIT está incompleto.';
        base = first.substring(0, first.length - 1);
        check = first.substring(first.length - 1);
      }
      switch (personType) {
        case PersonType.juridica:
          if (base.length != 9) {
            return 'El NIT de persona jurídica tiene 9 dígitos más el dígito '
                'de verificación.';
          }
        case PersonType.natural:
          if (base.length < 6 || base.length > 10) {
            return 'El NIT de persona natural tiene de 6 a 10 dígitos más el '
                'dígito de verificación.';
          }
      }
      if (nitCheckDigit(base) != int.parse(check)) {
        return 'El dígito de verificación del NIT no es válido.';
      }
      return null;
    };
  }

  // ----------------------------------------------------------- razón social

  /// Razón social: 2 a 120 caracteres; letras, números, espacios y `. , & -`.
  static String? companyName(String? value) {
    final text = AuthInputNormalizer.text(value);
    if (text.isEmpty) return 'Ingresa la razón social.';
    if (_hasForbiddenCharacters(text) || !_companyPattern.hasMatch(text)) {
      return 'Solo se admiten letras, números, espacios y . , & -';
    }
    if (_length(text) < companyNameMinLength ||
        _length(text) > companyNameMaxLength) {
      return 'Debe tener entre $companyNameMinLength y '
          '$companyNameMaxLength caracteres.';
    }
    if (!_alphanumeric.hasMatch(text)) {
      return 'Debe incluir al menos una letra o un número.';
    }
    return null;
  }

  // ------------------------------------------------------ fecha de nacimiento

  /// Fecha real, no futura y con edad >= 18 años. [clock] es inyectable.
  static String? birthDate(DateTime? value, {DateTime Function()? clock}) {
    if (value == null) return 'Ingresa tu fecha de nacimiento.';
    final today = (clock ?? DateTime.now)();
    final birth = DateTime(value.year, value.month, value.day);
    final now = DateTime(today.year, today.month, today.day);
    if (birth.year < 1900) return 'Ingresa una fecha de nacimiento válida.';
    if (birth.isAfter(now)) {
      return 'La fecha de nacimiento no puede ser futura.';
    }
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    if (age < minimumAge) {
      return 'Debes ser mayor de $minimumAge años para registrarte.';
    }
    return null;
  }

  /// Variante para texto `dd/mm/aaaa` o `aaaa-mm-dd`; rechaza fechas que no
  /// existen (p. ej. 31/02/2000).
  static String? Function(String?) birthDateText({DateTime Function()? clock}) {
    return (value) {
      final text = AuthInputNormalizer.text(value);
      if (text.isEmpty) return 'Ingresa tu fecha de nacimiento.';
      final parsed = _hasForbiddenCharacters(text)
          ? null
          : parseBirthDate(text);
      if (parsed == null) {
        return 'Ingresa una fecha válida con el formato dd/mm/aaaa.';
      }
      return birthDate(parsed, clock: clock);
    };
  }

  /// Interpreta `dd/mm/aaaa` o `aaaa-mm-dd`; `null` si no es una fecha real.
  static DateTime? parseBirthDate(String text) {
    final trimmed = text.trim();
    final latin = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(trimmed);
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(trimmed);
    final int day;
    final int month;
    final int year;
    if (latin != null) {
      day = int.parse(latin.group(1) ?? '0');
      month = int.parse(latin.group(2) ?? '0');
      year = int.parse(latin.group(3) ?? '0');
    } else if (iso != null) {
      year = int.parse(iso.group(1) ?? '0');
      month = int.parse(iso.group(2) ?? '0');
      day = int.parse(iso.group(3) ?? '0');
    } else {
      return null;
    }
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  // ------------------------------------------------------------- contraseña

  /// Mínimo 8 caracteres, sin reglas de complejidad (desarrollo). No se
  /// recorta: los espacios forman parte de la contraseña.
  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Ingresa tu contraseña.';
    if (_hasForbiddenCharacters(text)) {
      return 'La contraseña contiene caracteres no permitidos.';
    }
    if (text.length < passwordMinLength) {
      return 'La contraseña debe tener al menos $passwordMinLength caracteres.';
    }
    return null;
  }

  /// Confirmación: debe coincidir con la contraseña que devuelve [original].
  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      final text = value ?? '';
      if (text.isEmpty) return 'Confirma tu contraseña.';
      if (text != original()) return 'Las contraseñas no coinciden.';
      return null;
    };
  }

  // --------------------------------------------------- motivo de rechazo

  /// Motivo con el que un administrador rechaza una solicitud (10 a 300).
  static String? rejectionReason(String? value) {
    final text = AuthInputNormalizer.text(value);
    if (text.isEmpty) return 'Escribe el motivo del rechazo.';
    if (_hasForbiddenCharacters(text, allowNewLines: true)) {
      return 'El motivo contiene caracteres no permitidos.';
    }
    if (_length(text) < rejectionReasonMinLength ||
        _length(text) > rejectionReasonMaxLength) {
      return 'El motivo debe tener entre $rejectionReasonMinLength y '
          '$rejectionReasonMaxLength caracteres.';
    }
    return null;
  }

  // ---------------------------------------------------------------- helpers

  static int _length(String text) => text.runes.length;

  /// `true` si [text] contiene caracteres de control, invisibles o emojis.
  static bool _hasForbiddenCharacters(
    String text, {
    bool allowNewLines = false,
  }) {
    for (final rune in text.runes) {
      if (allowNewLines && (rune == 0x0A || rune == 0x0D)) continue;
      if (rune < 0x20 || (rune >= 0x7F && rune <= 0x9F)) return true;
      if (rune > 0xFFFF) return true; // emojis y símbolos suplementarios
      if ((rune >= 0x200B && rune <= 0x200F) ||
          (rune >= 0x2028 && rune <= 0x202F) ||
          (rune >= 0x2060 && rune <= 0x206F) ||
          (rune >= 0x2190 && rune <= 0x2BFF) ||
          (rune >= 0xFE00 && rune <= 0xFE0F) ||
          rune == 0xFEFF ||
          rune == 0x20E3) {
        return true;
      }
    }
    return false;
  }
}
