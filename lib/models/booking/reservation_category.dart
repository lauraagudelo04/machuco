import 'package:floor/floor.dart';

/// Catalog entry used to categorize a reservation before booking (for
/// example "Suite" or "Jacuzzi"). Persisted in the local SQLite table
/// `reservation_categories`, owned by the booking module.
@Entity(tableName: 'reservation_categories')
class ReservationCategory {
  const ReservationCategory({required this.id, required this.name});

  @PrimaryKey()
  final int id;

  final String name;
}
