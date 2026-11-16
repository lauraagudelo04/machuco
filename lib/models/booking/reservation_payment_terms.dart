/// Shared contract between Booking, Payment_Method and Payment.
abstract final class ReservationPaymentTerms {
  /// Place of payment, NOT a method from the Supabase catalog.
  static const payAtProperty = 'En el Local';
  static const checkoutTimeout = Duration(minutes: 15);

  static String paymentId(String reservationId) => 'pay-$reservationId';
}
