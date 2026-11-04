// ignore_for_file: experimental_member_use

import 'dart:convert';

import 'package:floor/floor.dart';
import 'package:machuco/core/design_system/components/status_badge.dart';

@Entity(tableName: 'subscriptions')
class SubscriptionDetails {
  const SubscriptionDetails({
    this.id,
    this.userEmail,
    this.planId,
    required this.planName,
    required this.motelName,
    required this.amount,
    required this.billingPeriod,
    required this.nextBillingDate,
    required this.status,
    required this.features,
  });

  @PrimaryKey(autoGenerate: true)
  final int? id;
  final String? userEmail;
  final int? planId;
  final String planName;
  final String motelName;
  final int amount;
  final String billingPeriod;
  final DateTime nextBillingDate;
  final AppStatus status;
  final List<String> features;
}

@Entity(
  tableName: 'subscription_payments',
  foreignKeys: [
    ForeignKey(
      childColumns: ['subscriptionId'],
      parentColumns: ['id'],
      entity: SubscriptionDetails,
    ),
  ],
  indices: [
    Index(value: ['subscriptionId']),
  ],
)
class SubscriptionPayment {
  const SubscriptionPayment({
    this.id,
    required this.subscriptionId,
    required this.date,
    required this.amount,
    required this.paymentMethod,
    required this.reference,
    required this.status,
  });

  @PrimaryKey(autoGenerate: true)
  final int? id;
  final int subscriptionId;
  final DateTime date;
  final int amount;
  final String paymentMethod;
  final String reference;
  final AppStatus status;
}

/// El catálogo remoto contiene únicamente ID y nombre.
class SubscriptionPlan {
  const SubscriptionPlan({required this.id, required this.name});

  final int id;
  final String name;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! int ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty) {
      throw const FormatException('Plan inválido en el catálogo');
    }
    return SubscriptionPlan(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

// Floor necesita convertir estos tipos a INTEGER y TEXT para guardarlos.
class SubscriptionPaymentMethod {
  const SubscriptionPaymentMethod({required this.id, required this.name});

  final int id;
  final String name;

  factory SubscriptionPaymentMethod.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! int ||
        json['nombre'] is! String ||
        (json['nombre'] as String).trim().isEmpty) {
      throw const FormatException('Método de pago inválido en el catálogo');
    }
    return SubscriptionPaymentMethod(
      id: json['id'] as int,
      name: json['nombre'] as String,
    );
  }
}

class SubscriptionDateConverter extends TypeConverter<DateTime, int> {
  @override
  DateTime decode(int value) => DateTime.fromMicrosecondsSinceEpoch(value);
  @override
  int encode(DateTime value) => value.microsecondsSinceEpoch;
}

class SubscriptionStatusConverter extends TypeConverter<AppStatus, String> {
  @override
  AppStatus decode(String value) => AppStatus.values.byName(value);
  @override
  String encode(AppStatus value) => value.name;
}

class SubscriptionFeaturesConverter
    extends TypeConverter<List<String>, String> {
  @override
  List<String> decode(String value) =>
      (jsonDecode(value) as List<dynamic>).cast<String>();
  @override
  String encode(List<String> value) => jsonEncode(value);
}
