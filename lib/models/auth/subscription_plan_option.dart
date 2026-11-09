/// Plan de suscripción ofrecido al propietario durante el registro
/// (Supabase `subscription_plans`: solo `id` y `name`).
class SubscriptionPlanOption {
  const SubscriptionPlanOption({required this.id, required this.name});

  final int id;
  final String name;

  /// `null` si la fila no trae un id numérico o un nombre usable.
  static SubscriptionPlanOption? tryFromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int
        ? rawId
        : rawId is num
        ? rawId.toInt()
        : int.tryParse(rawId?.toString() ?? '');
    final name = json['name']?.toString().trim() ?? '';
    if (id == null || name.isEmpty) return null;
    return SubscriptionPlanOption(id: id, name: name);
  }

  @override
  bool operator ==(Object other) =>
      other is SubscriptionPlanOption && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
