import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_entity.dart';
import 'package:machuco/models/booking/reservation_line_item_entity.dart';

/// Converts between the domain [Reservation] and its Floor rows.
class ReservationMapper {
  const ReservationMapper._();

  static ReservationEntity toEntity(Reservation r) => ReservationEntity(
    id: r.id,
    requestId: r.requestId,
    motelId: r.motelId,
    motelName: r.motelName,
    roomId: r.roomId,
    roomName: r.roomName,
    roomNumber: r.roomNumber,
    checkIn: r.checkIn.millisecondsSinceEpoch,
    checkOut: r.checkOut.millisecondsSinceEpoch,
    stayMode: r.stayMode.name,
    guestCount: r.guestCount,
    roomTotal: r.roomTotal,
    total: r.total,
    status: r.status.name,
    createdAt: r.createdAt.millisecondsSinceEpoch,
    guestId: r.guestId,
    guestName: r.guestName,
    categoryId: r.categoryId,
    cancellationReason: r.cancellationReason,
    invoiceAccessStatus: r.invoiceAccessStatus.name,
    paymentMethod: r.paymentMethod,
  );

  /// Line item rows of [r]: services first, then products, each keeping its
  /// list order in `position`.
  static List<ReservationLineItemEntity> toLineItemEntities(Reservation r) => [
    ..._items(r.id, ReservationLineItemEntity.kindService, r.services),
    ..._items(r.id, ReservationLineItemEntity.kindProduct, r.products),
  ];

  static List<ReservationLineItemEntity> _items(
    String reservationId,
    String kind,
    List<ReservationLineItem> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      ReservationLineItemEntity(
        reservationId: reservationId,
        kind: kind,
        itemId: items[i].id,
        name: items[i].name,
        unitPrice: items[i].unitPrice,
        quantity: items[i].quantity,
        position: i,
      ),
  ];

  static Reservation toDomain(
    ReservationEntity e,
    List<ReservationLineItemEntity> items,
  ) {
    List<ReservationLineItem> byKind(String kind) {
      final rows = items.where((i) => i.kind == kind).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      return [
        for (final row in rows)
          ReservationLineItem(
            id: row.itemId,
            name: row.name,
            unitPrice: row.unitPrice,
            quantity: row.quantity,
          ),
      ];
    }

    return Reservation(
      id: e.id,
      requestId: e.requestId,
      motelId: e.motelId,
      motelName: e.motelName,
      roomId: e.roomId,
      roomName: e.roomName,
      roomNumber: e.roomNumber,
      checkIn: DateTime.fromMillisecondsSinceEpoch(e.checkIn),
      checkOut: DateTime.fromMillisecondsSinceEpoch(e.checkOut),
      stayMode: StayMode.values.byName(e.stayMode),
      guestCount: e.guestCount,
      services: byKind(ReservationLineItemEntity.kindService),
      products: byKind(ReservationLineItemEntity.kindProduct),
      roomTotal: e.roomTotal,
      total: e.total,
      status: ReservationStatus.values.byName(e.status),
      createdAt: DateTime.fromMillisecondsSinceEpoch(e.createdAt),
      guestId: e.guestId,
      guestName: e.guestName,
      categoryId: e.categoryId,
      cancellationReason: e.cancellationReason,
      invoiceAccessStatus: InvoiceAccessStatus.values.byName(
        e.invoiceAccessStatus,
      ),
      paymentMethod: e.paymentMethod,
    );
  }
}
