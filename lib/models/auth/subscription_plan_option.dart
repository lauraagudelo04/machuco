import 'package:flutter/foundation.dart';

/// Plan de suscripción ofrecido al propietario durante el registro
/// (Supabase `subscription_plans`).
///
/// Solo `id` es obligatorio en la tabla: el resto puede llegar `null` y el
/// parseo lo tolera. La interfaz oculta lo que falte.
@immutable
class SubscriptionPlanOption {
  const SubscriptionPlanOption({
    required this.id,
    this.name,
    this.description,
    this.price,
    this.currency,
    this.billingPeriod,
    this.features = const [],
    this.maxMotels,
    this.sortOrder,
  });

  final int id;
  final String? name;
  final String? description;

  /// Precio en pesos colombianos (entero, sin decimales).
  final int? price;
  final String? currency;

  /// `monthly` o `yearly` (ver [billingPeriodLabel]).
  final String? billingPeriod;
  final List<String> features;
  final int? maxMotels;
  final int? sortOrder;

  /// `mensual` o `anual`; `null` si no hay periodicidad o es desconocida.
  String? get billingPeriodLabel => switch (billingPeriod?.toLowerCase()) {
    'monthly' => 'mensual',
    'yearly' => 'anual',
    _ => null,
  };

  /// `null` solo si la fila no trae un id numérico.
  static SubscriptionPlanOption? tryFromJson(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id == null) return null;
    return SubscriptionPlanOption(
      id: id,
      name: _text(json['name']),
      description: _text(json['description']),
      price: _int(json['price']),
      currency: _text(json['currency']),
      billingPeriod: _text(json['billing_period']),
      features: _features(json['features']),
      maxMotels: _int(json['max_motels']),
      sortOrder: _int(json['sort_order']),
    );
  }

  static int? _int(Object? raw) => switch (raw) {
    int value => value,
    num value => value.toInt(),
    null => null,
    _ => int.tryParse(raw.toString().trim()),
  };

  static String? _text(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  static List<String> _features(Object? raw) {
    if (raw is! List) return const [];
    return List.unmodifiable([for (final item in raw) ?_text(item)]);
  }

  @override
  bool operator ==(Object other) =>
      other is SubscriptionPlanOption &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.price == price &&
      other.currency == currency &&
      other.billingPeriod == billingPeriod &&
      listEquals(other.features, features) &&
      other.maxMotels == maxMotels &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    price,
    currency,
    billingPeriod,
    Object.hashAll(features),
    maxMotels,
    sortOrder,
  );
}
