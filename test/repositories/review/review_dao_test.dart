import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/review/review_dao.dart';
import 'package:machuco/models/review/review.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Review _review(
  String id, {
  required DateTime date,
  String? roomId,
  String? ownerReply,
  ReviewModerationStatus status = ReviewModerationStatus.visible,
  String? reportReason,
}) => Review(
  id: id,
  authorId: 'uid-$id',
  authorName: 'Autor $id',
  title: 'Título $id',
  body: 'Cuerpo $id',
  rating: 4,
  date: date,
  motelId: 'motel-1',
  roomId: roomId,
  type: roomId == null ? ReviewType.motel : ReviewType.room,
  status: status,
  reportReason: reportReason,
  ownerReply: ownerReply,
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database database;
  late ReviewDao dao;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = ReviewDao(() async => database);
  });

  tearDown(() => database.close());

  test('sin copia guardada devuelve una lista vacía', () async {
    expect(await dao.findAll(), isEmpty);
  });

  test('guarda las reseñas y las devuelve de la más reciente a la más antigua '
      'con todos sus campos', () async {
    final older = _review('a', date: DateTime.utc(2026, 11, 1, 10));
    final newer = _review(
      'b',
      date: DateTime.utc(2026, 11, 15, 18, 30),
      roomId: 'room-3',
      ownerReply: 'Gracias',
      status: ReviewModerationStatus.reported,
      reportReason: 'Spam',
    );

    await dao.replaceAll([older, newer]);
    final saved = await dao.findAll();

    expect(saved.map((r) => r.id), ['b', 'a']);
    final b = saved.first;
    expect(b.authorId, 'uid-b');
    expect(b.authorName, 'Autor b');
    expect(b.title, 'Título b');
    expect(b.body, 'Cuerpo b');
    expect(b.rating, 4);
    expect(b.date, DateTime.utc(2026, 11, 15, 18, 30));
    expect(b.motelId, 'motel-1');
    expect(b.roomId, 'room-3');
    expect(b.type, ReviewType.room);
    expect(b.status, ReviewModerationStatus.reported);
    expect(b.reportReason, 'Spam');
    expect(b.ownerReply, 'Gracias');
    expect(b.adminReply, isNull);
    expect(saved.last.roomId, isNull);
  });

  test('replaceAll reemplaza la copia anterior completa', () async {
    await dao.replaceAll([
      _review('a', date: DateTime.utc(2026, 11, 1)),
      _review('b', date: DateTime.utc(2026, 11, 2)),
    ]);

    await dao.replaceAll([_review('c', date: DateTime.utc(2026, 11, 3))]);

    expect((await dao.findAll()).map((r) => r.id), ['c']);
  });

  test('convive con la base de la app sin cambiar su versión', () async {
    final directory = await Directory.systemTemp.createTemp('machuco_review_');
    addTearDown(() => directory.delete(recursive: true));
    final appDatabase = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}app.db',
    );
    addTearDown(appDatabase.close);
    final raw = appDatabase.database as Database;
    final versionBefore = await raw.getVersion();
    final appDao = ReviewDao(() async => raw);

    await appDao.replaceAll([_review('a', date: DateTime.utc(2026, 11, 1))]);

    expect((await appDao.findAll()).single.id, 'a');
    expect(await raw.getVersion(), versionBefore);
  });
}
