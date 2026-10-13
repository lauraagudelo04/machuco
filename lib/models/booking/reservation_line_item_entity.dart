import 'package:floor/floor.dart';
import 'package:machuco/models/booking/reservation_entity.dart';

/// Floor row for the `reservation_line_items` table: one service or product
/// of a reservation. Deleted automatically with its reservation.
@Entity(
  tableName: 'reservation_line_items',
  foreignKeys: [
    ForeignKey(
      childColumns: ['reservationId'],
      parentColumns: ['id'],
      entity: ReservationEntity,
      onDelete: ForeignKeyAction.cascade,
    ),
  ],
  indices: [
    Index(value: ['reservationId']),
  ],
)
class ReservationLineItemEntity {
  const ReservationLineItemEntity({
    this.rowId,
    required this.reservationId,
    required this.kind,
    required this.itemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.position,
  });

  static const String kindService = 'service';
  static const String kindProduct = 'product';

  @PrimaryKey(autoGenerate: true)
  final int? rowId;
  final String reservationId;

  /// [kindService] or [kindProduct].
  final String kind;
  final String itemId;
  final String name;
  final int unitPrice;
  final int quantity;

  /// Order of the item inside its list.
  final int position;
}
