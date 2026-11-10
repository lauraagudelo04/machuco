import 'package:floor/floor.dart';
import 'package:machuco/models/booking/reservation_entity.dart';
import 'package:machuco/models/booking/reservation_line_item_entity.dart';

@dao
abstract class ReservationDao {
  @Query('SELECT * FROM reservations')
  Future<List<ReservationEntity>> findAllReservations();

  @Query('SELECT * FROM reservations WHERE id = :id LIMIT 1')
  Future<ReservationEntity?> findReservationById(String id);

  @Query('SELECT * FROM reservations WHERE requestId = :requestId LIMIT 1')
  Future<ReservationEntity?> findReservationByRequestId(String requestId);

  @Query('SELECT COUNT(*) FROM reservations')
  Future<int?> countReservations();

  @Query(
    'SELECT * FROM reservation_line_items ORDER BY reservationId, position',
  )
  Future<List<ReservationLineItemEntity>> findAllLineItems();

  @Query(
    'SELECT * FROM reservation_line_items WHERE reservationId = :reservationId '
    'ORDER BY position',
  )
  Future<List<ReservationLineItemEntity>> findLineItems(String reservationId);

  @Query('DELETE FROM reservation_line_items WHERE reservationId = :id')
  Future<void> deleteLineItems(String id);

  @Insert(onConflict: OnConflictStrategy.abort)
  Future<void> insertReservationRow(ReservationEntity reservation);

  @update
  Future<void> updateReservationRow(ReservationEntity reservation);

  @insert
  Future<void> insertLineItems(List<ReservationLineItemEntity> items);

  /// Inserts [reservation] and its line items atomically.
  @transaction
  Future<void> insertReservation(
    ReservationEntity reservation,
    List<ReservationLineItemEntity> items,
  ) async {
    await insertReservationRow(reservation);
    await deleteLineItems(reservation.id);
    await insertLineItems(items);
  }

  /// Updates [reservation] and replaces its line items atomically.
  @transaction
  Future<void> replaceReservation(
    ReservationEntity reservation,
    List<ReservationLineItemEntity> items,
  ) async {
    await updateReservationRow(reservation);
    await deleteLineItems(reservation.id);
    await insertLineItems(items);
  }

  /// Inserts every reservation with its line items in one transaction, so a
  /// failure leaves the tables untouched.
  @transaction
  Future<void> insertReservations(
    List<ReservationEntity> reservations,
    List<ReservationLineItemEntity> items,
  ) async {
    for (final reservation in reservations) {
      await insertReservationRow(reservation);
    }
    await insertLineItems(items);
  }
}
