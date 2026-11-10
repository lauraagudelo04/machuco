import 'package:floor/floor.dart';

/// Maestro de categorías de servicios adicionales expuesto por Supabase.
@Entity(
  tableName: 'additional_service_categories',
  indices: [
    Index(value: ['name'], unique: true),
  ],
)
class AdditionalServiceCategory {
  const AdditionalServiceCategory({
    this.id,
    required this.name,
    required this.createdAt,
  });

  @PrimaryKey(autoGenerate: true)
  final int? id;
  final String name;
  final DateTime createdAt;

  factory AdditionalServiceCategory.fromJson(Map<String, dynamic> json) {
    return AdditionalServiceCategory(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
