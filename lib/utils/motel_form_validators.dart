/// Validaciones compartidas por los formularios de administración de moteles
/// (propietario y administrador).
class MotelFormValidators {
  const MotelFormValidators._();

  static const int minimumNameLength = 3;
  static const int maximumNameLength = 100;
  static const int maximumDescriptionLength = 500;
  static const int minimumAddressLength = 5;
  static const int maximumAddressLength = 150;
  static const int maximumGeneralLocationLength = 100;
  static const int minimumPhoneDigits = 7;
  static const int maximumPhoneDigits = 15;
  static const int maximumRoomCount = 10000;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _nitPattern = RegExp(r'^\d{6,15}(-\d{1,2})?$');
  static final RegExp _phoneCharactersPattern = RegExp(r'^\+?[\d\s()-]+$');

  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Ingresa el nombre del establecimiento.';
    }
    if (name.length < minimumNameLength) {
      return 'El nombre debe tener al menos $minimumNameLength caracteres.';
    }
    if (name.length > maximumNameLength) {
      return 'El nombre no puede superar $maximumNameLength caracteres.';
    }
    return null;
  }

  static String? validateDescription(String? value) {
    final description = value?.trim() ?? '';
    if (description.length > maximumDescriptionLength) {
      return 'La descripción no puede superar $maximumDescriptionLength caracteres.';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Ingresa el correo electrónico.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Ingresa un correo válido, por ejemplo nombre@dominio.com.';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) {
      return 'Ingresa el teléfono.';
    }
    if (!_phoneCharactersPattern.hasMatch(phone)) {
      return 'Ingresa un teléfono válido, por ejemplo 300 123 4567.';
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < minimumPhoneDigits ||
        digits.length > maximumPhoneDigits) {
      return 'El teléfono debe tener entre $minimumPhoneDigits y '
          '$maximumPhoneDigits dígitos.';
    }
    return null;
  }

  static String? validateRoomCount(String? value) {
    final rawRoomCount = value?.trim() ?? '';
    if (rawRoomCount.isEmpty) {
      return 'Ingresa el número de habitaciones.';
    }
    final roomCount = int.tryParse(rawRoomCount);
    if (roomCount == null) {
      return 'Ingresa un número de habitaciones válido.';
    }
    if (roomCount <= 0) {
      return 'El número de habitaciones debe ser mayor que cero.';
    }
    if (roomCount > maximumRoomCount) {
      return 'El número de habitaciones no puede superar $maximumRoomCount.';
    }
    return null;
  }

  static String? validateNit(String? value) {
    final nit = value?.trim() ?? '';
    if (nit.isEmpty) {
      return 'Ingresa el NIT.';
    }
    if (!_nitPattern.hasMatch(nit)) {
      return 'Ingresa un NIT válido, por ejemplo 900123456-1.';
    }
    return null;
  }

  static String? validateAddress(String? value) {
    final address = value?.trim() ?? '';
    if (address.isEmpty) {
      return 'Ingresa la dirección.';
    }
    if (address.length < minimumAddressLength) {
      return 'La dirección debe tener al menos $minimumAddressLength caracteres.';
    }
    if (address.length > maximumAddressLength) {
      return 'La dirección no puede superar $maximumAddressLength caracteres.';
    }
    return null;
  }

  static String? validateGeneralLocation(String? value) {
    final generalLocation = value?.trim() ?? '';
    if (generalLocation.length > maximumGeneralLocationLength) {
      return 'La ubicación general no puede superar '
          '$maximumGeneralLocationLength caracteres.';
    }
    return null;
  }

  static String? validatePaymentMethods(List<String> paymentMethods) {
    if (paymentMethods.isEmpty) {
      return 'Selecciona al menos un método de pago.';
    }
    return null;
  }
}
