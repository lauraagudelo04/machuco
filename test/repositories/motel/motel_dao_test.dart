import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/motel/motel_entity.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_motel_dao_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}motels.db',
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('guarda y recupera moteles convirtiendo listas y booleano', () async {
    const motel = Motel(
      id: '1',
      ownerId: 'owner-1',
      name: 'Motel Test',
      email: 'test@test.com',
      roomCount: 5,
      nit: '900123456-1',
      address: 'Calle 1',
      phone: '+573001234567',
      description: 'Desc',
      generalLocation: 'Centro',
      paymentMethods: ['Efectivo', 'Nequi'],
      imageUrls: ['a.jpg', 'b.jpg'],
      isAvailable: true,
    );

    await database.motelDao.upsert(MotelEntity.fromModel(motel));
    final entities = await database.motelDao.findAll();

    expect(entities, hasLength(1));
    final model = entities.first.toModel();
    expect(model.paymentMethods, ['Efectivo', 'Nequi']);
    expect(model.imageUrls, ['a.jpg', 'b.jpg']);
    expect(model.isAvailable, true);
    expect(model.generalLocation, 'Centro');
  });

  test('replaceAll reemplaza toda la tabla', () async {
    const motel1 = Motel(
      id: '1',
      ownerId: 'owner-1',
      name: 'Motel A',
      email: 'a@test.com',
      roomCount: 1,
      nit: '900123456-1',
      address: 'Calle 1',
      phone: '+573001234567',
      paymentMethods: ['Efectivo'],
      imageUrls: [],
      isAvailable: true,
    );
    const motel2 = Motel(
      id: '2',
      ownerId: 'owner-1',
      name: 'Motel B',
      email: 'b@test.com',
      roomCount: 2,
      nit: '900123456-2',
      address: 'Calle 2',
      phone: '+573001234568',
      paymentMethods: ['Efectivo'],
      imageUrls: [],
      isAvailable: false,
    );

    await database.motelDao.replaceAll([
      MotelEntity.fromModel(motel1),
      MotelEntity.fromModel(motel2),
    ]);
    await database.motelDao.replaceAll([MotelEntity.fromModel(motel2)]);

    final entities = await database.motelDao.findAll();
    expect(entities, hasLength(1));
    expect(entities.first.toModel().name, 'Motel B');
    expect(entities.first.toModel().isAvailable, false);
  });

  test('findAll ordena por nombre', () async {
    const motelB = Motel(
      id: '2',
      ownerId: 'owner-1',
      name: 'Zaragoza',
      email: 'b@test.com',
      roomCount: 2,
      nit: '900123456-2',
      address: 'Calle 2',
      phone: '+573001234568',
      paymentMethods: ['Efectivo'],
      imageUrls: [],
      isAvailable: true,
    );
    const motelA = Motel(
      id: '1',
      ownerId: 'owner-1',
      name: 'Alamo',
      email: 'a@test.com',
      roomCount: 1,
      nit: '900123456-1',
      address: 'Calle 1',
      phone: '+573001234567',
      paymentMethods: ['Efectivo'],
      imageUrls: [],
      isAvailable: true,
    );

    await database.motelDao.replaceAll([
      MotelEntity.fromModel(motelB),
      MotelEntity.fromModel(motelA),
    ]);

    final entities = await database.motelDao.findAll();
    expect(entities.map((e) => e.name), ['Alamo', 'Zaragoza']);
  });
}
