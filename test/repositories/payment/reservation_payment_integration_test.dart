import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_catalog_entry.dart';
import 'package:machuco/repositories/booking/reservation_mapper.dart';
import 'package:machuco/repositories/payment/payment_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 10, 12);
  late Directory directory;
  late String path;
  late AppDatabase database;
  late PaymentRepository repository;
  final reservation = Reservation(
    id: 'real-reservation',
    requestId: 'real-request',
    motelId: 'motel-1',
    motelName: 'Motel Uno',
    roomId: 'room-1',
    roomName: 'Suite',
    roomNumber: '101',
    checkIn: DateTime(2026, 11, 10, 18),
    checkOut: DateTime(2026, 11, 10, 22),
    stayMode: StayMode.dateTimeRange,
    guestCount: 2,
    services: const [],
    products: const [],
    roomTotal: 120000,
    total: 120000,
    status: ReservationStatus.pending,
    createdAt: DateTime(2026, 11, 10, 11, 58),
    guestId: 'client-1',
    guestName: 'Cliente Uno',
  );
  PaymentRecord payment({int amount = 120000}) => PaymentRecord(
    id: 'pay-real-reservation',
    bookingId: reservation.id,
    bookingReference: reservation.requestId,
    clientId: reservation.guestId,
    client: reservation.guestName,
    motelId: reservation.motelId,
    motel: reservation.motelName,
    roomId: reservation.roomId,
    room: reservation.roomName,
    reservationDate: reservation.checkIn,
    amount: amount,
    status: PaymentStatus.pending,
  );
  Future<Reservation> storedReservation() async => ReservationMapper.toDomain(
    (await database.reservationDao.findReservationById(reservation.id))!,
    const [],
  );
  Future<PaymentRecord> receive() => repository.registerLocalPayment(
    paymentId: payment().id,
    motelId: reservation.motelId,
    paymentMethodId: 1,
  );
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_payment_link_');
    path = '${directory.path}${Platform.pathSeparator}machuco.db';
    database = await AppDatabaseProvider.open(name: path);
    repository = PaymentRepository(database: database, now: () => now);
    await database.reservationDao.insertReservation(
      ReservationMapper.toEntity(reservation),
      const [],
    );
    await database.paymentDao.saveCatalogEntries([
      const PaymentCatalogEntry(id: 1, name: 'Efectivo'),
    ]);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('selection is atomic and is not a receipt', () async {
    final saved = await repository.createPendingReservationPayment(payment());
    final booking = await storedReservation();
    expect(saved.status, PaymentStatus.pending);
    expect(saved.paymentMethodId, isNull);
    expect(saved.receiptNumber, isNull);
    expect(booking.status, ReservationStatus.pending);
    expect(booking.isPayAtProperty, isTrue);
  });

  test(
    'two independent SQLite stores share the pending payment and its receipt',
    () async {
      final pending = await repository.createPendingReservationPayment(
        payment(),
      );
      final ownerDatabase = await AppDatabaseProvider.open(
        name: '${directory.path}${Platform.pathSeparator}owner.db',
      );
      try {
        final ownerRepository = PaymentRepository(
          database: ownerDatabase,
          now: () => now,
        );
        await ownerDatabase.reservationDao.insertReservation(
          ReservationMapper.toEntity(
            reservation.copyWith(paymentMethod: 'En el Local'),
          ),
          const [],
        );
        await ownerDatabase.paymentDao.saveCatalogEntries([
          const PaymentCatalogEntry(id: 1, name: 'Efectivo'),
        ]);
        await ownerRepository.mergeRemotePayments(
          motelId: reservation.motelId,
          payments: [pending],
        );
        final receipt = await ownerRepository.registerLocalPayment(
          paymentId: pending.id,
          motelId: reservation.motelId,
          paymentMethodId: 1,
        );
        await repository.mergeRemotePayments(
          motelId: reservation.motelId,
          payments: [receipt],
        );
        expect(
          (await repository.findPayment(pending.id))!.status,
          PaymentStatus.paid,
        );
        expect((await storedReservation()).paymentMethod, 'Efectivo');
        expect((await storedReservation()).status, ReservationStatus.upcoming);
      } finally {
        await ownerDatabase.close();
      }
    },
  );

  test(
    'selection rolls back the payment if the reservation cannot be updated',
    () async {
      await database.database.execute(
        "CREATE TRIGGER reject_place BEFORE UPDATE OF paymentMethod ON reservations BEGIN SELECT RAISE(ABORT, 'fixture'); END",
      );
      await expectLater(
        repository.createPendingReservationPayment(payment()),
        throwsA(isA<PaymentRepositoryException>()),
      );
      expect(await repository.findAllPayments(), isEmpty);
      expect((await storedReservation()).paymentMethod, isNull);
    },
  );

  test(
    'receipt commits payment, method and reservation together and survives restart',
    () async {
      await repository.createPendingReservationPayment(payment());
      final paid = await receive();
      expect(paid.status, PaymentStatus.paid);
      expect(paid.receiptNumber, 'LOCAL-pay-real-reservation');
      await database.close();
      database = await AppDatabaseProvider.open(name: path);
      repository = PaymentRepository(database: database, now: () => now);
      expect((await repository.findPayment(payment().id))!.paidAt, now);
      final booking = await storedReservation();
      expect(booking.status, ReservationStatus.upcoming);
      expect(booking.paymentMethod, 'Efectivo');
      expect(booking.invoiceAccessStatus, InvoiceAccessStatus.pending);
      await expectLater(receive(), throwsA(isA<PaymentRepositoryException>()));
    },
  );

  test('receipt rolls back if its reservation update fails', () async {
    await repository.createPendingReservationPayment(payment());
    await database.database.execute(
      "CREATE TRIGGER reject_receipt BEFORE UPDATE OF status ON reservations BEGIN SELECT RAISE(ABORT, 'fixture'); END",
    );
    await expectLater(receive(), throwsA(isA<PaymentRepositoryException>()));
    expect(
      (await repository.findPayment(payment().id))!.status,
      PaymentStatus.pending,
    );
    expect((await storedReservation()).status, ReservationStatus.pending);
  });

  test(
    'does not accept mismatched amounts or an expired first selection',
    () async {
      await expectLater(
        repository.createPendingReservationPayment(payment(amount: 1)),
        throwsA(isA<PaymentRepositoryException>()),
      );
      repository = PaymentRepository(
        database: database,
        now: () => now.add(const Duration(hours: 1)),
      );
      await expectLater(
        repository.createPendingReservationPayment(payment()),
        throwsA(isA<PaymentRepositoryException>()),
      );
      expect(await repository.findAllPayments(), isEmpty);
    },
  );

  test('a selected pending payment is retryable after 15 minutes', () async {
    await repository.createPendingReservationPayment(payment());
    repository = PaymentRepository(
      database: database,
      now: () => now.add(const Duration(days: 1)),
    );
    await repository.createPendingReservationPayment(payment());
    expect(await repository.findAllPayments(), hasLength(1));
  });

  test(
    'reconciles an old remote pending copy without losing a durable receipt',
    () async {
      await repository.createPendingReservationPayment(payment());
      expect(
        (await repository.reconcileReservation(reservation)).isPayAtProperty,
        isTrue,
      );
      await receive();
      final reconciled = await repository.reconcileReservation(reservation);
      expect(reconciled.status, ReservationStatus.upcoming);
      expect(reconciled.paymentMethod, 'Efectivo');
    },
  );

  test(
    'cancelled reservations cannot receive money or be resurrected',
    () async {
      await repository.createPendingReservationPayment(payment());
      final cancelled = reservation.copyWith(
        status: ReservationStatus.cancelled,
        cancellationReason: 'No llegó',
      );
      await database.reservationDao.replaceReservation(
        ReservationMapper.toEntity(cancelled),
        const [],
      );
      await expectLater(receive(), throwsA(isA<PaymentRepositoryException>()));
      expect(
        (await repository.reconcileReservation(cancelled)).status,
        ReservationStatus.cancelled,
      );
      expect(
        (await repository.findPayment(payment().id))!.status,
        PaymentStatus.cancelled,
      );
    },
  );
}
