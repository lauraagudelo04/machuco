enum PaymentProcessStatus { initial, processing, approved, rejected }

enum CardNetwork { unknown, visa, mastercard, amex, discover }

enum CardPaymentKind { credit, debit }

class PaymentMethodModel {
  PaymentMethodModel({required this.amount, required this.concept});

  final int amount;
  final String concept;

  String cardHolder = '';
  String cardNumber = '';
  String expiry = '';
  String cvv = '';
  int installments = 1;
  CardPaymentKind cardKind = CardPaymentKind.credit;
  PaymentProcessStatus status = PaymentProcessStatus.initial;
  String? message;

  String? cardHolderError;
  String? cardNumberError;
  String? expiryError;
  String? cvvError;
}
