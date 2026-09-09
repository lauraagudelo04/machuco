import 'package:machuco/core/design_system/components/status_badge.dart';

class SubscriptionDetails {
  const SubscriptionDetails({
    required this.id,
    required this.planName,
    required this.motelName,
    required this.amount,
    required this.billingPeriod,
    required this.nextBillingDate,
    required this.status,
    required this.features,
  });

  final String id;
  final String planName;
  final String motelName;
  final int amount;
  final String billingPeriod;
  final DateTime nextBillingDate;
  final AppStatus status;
  final List<String> features;
}

class SubscriptionPayment {
  const SubscriptionPayment({
    required this.id,
    required this.date,
    required this.amount,
    required this.paymentMethod,
    required this.reference,
    required this.status,
  });

  final String id;
  final DateTime date;
  final int amount;
  final String paymentMethod;
  final String reference;
  final AppStatus status;
}
