import 'package:floor/floor.dart';
import 'package:machuco/models/pqrs/pqrs_type_info.dart';

/// Cache of a row of the Supabase catalog `pqrs_types`.
///
/// Named `PqrsTypeEntry` so it does not clash with the `PqrsType` enum; the
/// [code] is the stable key that links a row with a value of that enum.
@Entity(tableName: 'pqrs_types')
class PqrsTypeEntry {
  const PqrsTypeEntry({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.responseDays,
    required this.allowsPhotos,
    required this.sortOrder,
    required this.isActive,
  });

  /// Reads a Supabase row; missing or mistyped fields keep a safe default.
  factory PqrsTypeEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final days = json['response_days'];
    final order = json['sort_order'];
    return PqrsTypeEntry(
      id: id is int ? id : 0,
      code: (json['code'] as String? ?? '').trim().toLowerCase(),
      name: (json['name'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      responseDays: days is int && days > 0 ? days : pqrsDefaultResponseDays,
      allowsPhotos: json['allows_photos'] == false ? 0 : 1,
      sortOrder: order is int ? order : 0,
      isActive: json['is_active'] == false ? 0 : 1,
    );
  }

  @PrimaryKey()
  final int id;
  final String code;
  final String name;
  final String description;
  final int responseDays;

  /// 1 = the form shows the photo picker, 0 = it does not.
  final int allowsPhotos;
  final int sortOrder;

  /// 1 = available, 0 = withdrawn.
  final int isActive;
}
