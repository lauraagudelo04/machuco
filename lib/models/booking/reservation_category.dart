import 'package:floor/floor.dart';

/// Catalog entry used to categorize a reservation before booking (for
/// example "Suite" or "Jacuzzi"). Master data read from Supabase and cached
/// in the local SQLite table `reservation_categories`.
@Entity(tableName: 'reservation_categories')
class ReservationCategory {
  const ReservationCategory({required this.id, required this.name});

  factory ReservationCategory.fromJson(Map<String, dynamic> json) =>
      ReservationCategory(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
      );

  @PrimaryKey()
  final int id;

  final String name;
}
