import 'package:flutter/material.dart';
import 'package:machuco/models/booking/booking_checkout_data.dart';

extension BookingPaymentMethodPresentation on BookingPaymentMethod {
  String get label => switch (this) {
    BookingPaymentMethod.pse => 'PSE',
    BookingPaymentMethod.card => 'Tarjeta crédito o débito',
    BookingPaymentMethod.nequi => 'Nequi',
    BookingPaymentMethod.daviplata => 'Daviplata',
    BookingPaymentMethod.cash => 'Efectivo en el establecimiento',
  };

  String get description => switch (this) {
    BookingPaymentMethod.pse => 'Débito seguro desde tu banco',
    BookingPaymentMethod.card => 'Visa, Mastercard y American Express',
    BookingPaymentMethod.nequi => 'Aprueba el pago desde tu celular',
    BookingPaymentMethod.daviplata => 'Paga con tu saldo Daviplata',
    BookingPaymentMethod.cash => 'Paga al momento de ingresar',
  };

  IconData get icon => switch (this) {
    BookingPaymentMethod.pse => Icons.account_balance_outlined,
    BookingPaymentMethod.card => Icons.credit_card_outlined,
    BookingPaymentMethod.nequi => Icons.phone_android_outlined,
    BookingPaymentMethod.daviplata => Icons.wallet_outlined,
    BookingPaymentMethod.cash => Icons.payments_outlined,
  };
}
