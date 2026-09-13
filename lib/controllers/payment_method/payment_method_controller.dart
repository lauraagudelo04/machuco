import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';

class ExpiryDateInputFormatter extends TextInputFormatter {
  const ExpiryDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);

    final formatted = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PaymentMethodController extends ChangeNotifier {
  PaymentMethodController({required int amount, required String concept})
    : _model = PaymentMethodModel(amount: amount, concept: concept);

  final PaymentMethodModel _model;
  bool _isCvvHidden = true;
  bool _isDisposed = false;

  int get amount => _model.amount;
  String get concept => _model.concept;
  String get cardHolder => _model.cardHolder;
  String get cardNumber => _model.cardNumber;
  String get expiry => _model.expiry;
  int get installments => _model.installments;
  PaymentProcessStatus get status => _model.status;
  String? get message => _model.message;
  String? get cardHolderError => _model.cardHolderError;
  String? get cardNumberError => _model.cardNumberError;
  String? get expiryError => _model.expiryError;
  String? get cvvError => _model.cvvError;
  bool get isCvvHidden => _isCvvHidden;
  bool get isProcessing => status == PaymentProcessStatus.processing;
  bool get isApproved => status == PaymentProcessStatus.approved;
  TextInputFormatter get expiryDateFormatter =>
      const ExpiryDateInputFormatter();

  String get formattedAmount {
    final value = amount.toString();
    final formatted = value.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '\$$formatted COP';
  }

  String get cardPreviewNumber {
    final digits = _digitsOnly(cardNumber);
    if (digits.isEmpty) return '**** **** **** ****';

    final visibleDigits = digits.length > 4 ? 4 : digits.length;
    final hiddenDigits = digits.length - visibleDigits;
    final masked =
        '${List.filled(hiddenDigits, '*').join()}'
        '${digits.substring(hiddenDigits)}';
    return masked.replaceAllMapped(RegExp(r'.{1,4}'), (match) {
      final suffix = match.end < masked.length ? ' ' : '';
      return '${match.group(0)}$suffix';
    });
  }

  String get cardPreviewHolder => cardHolder.trim().isEmpty
      ? 'NOMBRE DEL TITULAR'
      : cardHolder.trim().toUpperCase();

  String get cardPreviewExpiry => expiry.trim().isEmpty ? 'MM/YY' : expiry;

  void updateCardHolder(String value) {
    _model.cardHolder = value;
    _model.cardHolderError = null;
    _resetResult();
    notifyListeners();
  }

  void updateCardNumber(String value) {
    _model.cardNumber = value;
    _model.cardNumberError = null;
    _resetResult();
    notifyListeners();
  }

  void updateExpiry(String value) {
    _model.expiry = value;
    _model.expiryError = null;
    _resetResult();
    notifyListeners();
  }

  void updateCvv(String value) {
    _model.cvv = value;
    _model.cvvError = null;
    _resetResult();
    notifyListeners();
  }

  void changeInstallments(int? value) {
    if (value == null || value == installments) return;
    _model.installments = value;
    _resetResult();
    notifyListeners();
  }

  void toggleCvvVisibility() {
    _isCvvHidden = !_isCvvHidden;
    notifyListeners();
  }

  Future<void> processPayment() async {
    if (isProcessing || !_validate()) return;

    _model.status = PaymentProcessStatus.processing;
    _model.message = null;
    notifyListeners();

    await Future<void>.delayed(const Duration(seconds: 2));
    if (_isDisposed) return;

    // Sandbox local: no se envían ni almacenan datos bancarios.
    _model.status = PaymentProcessStatus.approved;
    _model.message = 'Pago de $formattedAmount APROBADO correctamente.';
    notifyListeners();
  }

  bool _validate() {
    final digits = _digitsOnly(cardNumber);
    _model.cardHolderError = cardHolder.trim().isEmpty
        ? 'Ingresa el nombre del titular.'
        : null;
    _model.cardNumberError = !_isValidCardNumber(digits)
        ? 'Ingresa un número de tarjeta válido.'
        : null;
    _model.expiryError = !_isValidExpiry(expiry.trim())
        ? 'Ingresa una fecha vigente en formato MM/YY.'
        : null;
    _model.cvvError = !RegExp(r'^\d{3,4}$').hasMatch(_model.cvv.trim())
        ? 'El CVV debe tener 3 o 4 dígitos.'
        : null;

    final isValid =
        _model.cardHolderError == null &&
        _model.cardNumberError == null &&
        _model.expiryError == null &&
        _model.cvvError == null;
    if (!isValid) {
      _model.status = PaymentProcessStatus.rejected;
      _model.message = 'Revisa los datos indicados antes de continuar.';
      notifyListeners();
    }
    return isValid;
  }

  bool _isValidCardNumber(String digits) {
    if (digits.length < 13 || digits.length > 19) return false;

    var sum = 0;
    var shouldDouble = false;
    for (var index = digits.length - 1; index >= 0; index--) {
      var digit = int.parse(digits[index]);
      if (shouldDouble) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      shouldDouble = !shouldDouble;
    }
    return sum % 10 == 0;
  }

  bool _isValidExpiry(String value) {
    final match = RegExp(r'^(0[1-9]|1[0-2])\/(\d{2})$').firstMatch(value);
    if (match == null) return false;

    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    final now = DateTime.now();
    return year > now.year || (year == now.year && month >= now.month);
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  void _resetResult() {
    if (_model.status == PaymentProcessStatus.processing) return;
    _model.status = PaymentProcessStatus.initial;
    _model.message = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
