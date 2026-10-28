import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/motel/phone_country_code_dao.dart';
import 'package:machuco/models/phone_country_code/phone_country_code.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late PhoneCountryCodeDao dao;
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_country_code_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}country_codes.db',
    );
    dao = database.phoneCountryCodeDao;
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('persiste y recupera códigos telefónicos de país', () async {
    const countryCode = PhoneCountryCode(
      id: 1,
      countryCode: 'CO',
      countryName: 'Colombia',
      callingCode: '+57',
      active: true,
    );

    await dao.saveCountryCodes([countryCode]);
    final countryCodes = await dao.getCountryCodes();

    expect(countryCodes, hasLength(1));
    expect(countryCodes.single.id, 1);
    expect(countryCodes.single.countryName, 'Colombia');
    expect(countryCodes.single.callingCode, '+57');
  });

  test('reemplaza la caché en cada guardado', () async {
    await dao.saveCountryCodes(const [
      PhoneCountryCode(
        id: 1,
        countryCode: 'CO',
        countryName: 'Colombia',
        callingCode: '+57',
        active: true,
      ),
      PhoneCountryCode(
        id: 2,
        countryCode: 'MX',
        countryName: 'México',
        callingCode: '+52',
        active: true,
      ),
    ]);
    await dao.saveCountryCodes(const [
      PhoneCountryCode(
        id: 3,
        countryCode: 'PE',
        countryName: 'Perú',
        callingCode: '+51',
        active: true,
      ),
    ]);

    final countryCodes = await dao.getCountryCodes();

    expect(countryCodes, hasLength(1));
    expect(countryCodes.single.countryName, 'Perú');
  });

  test('ordena la lista por país', () async {
    await dao.saveCountryCodes(const [
      PhoneCountryCode(
        id: 2,
        countryCode: 'MX',
        countryName: 'México',
        callingCode: '+52',
        active: true,
      ),
      PhoneCountryCode(
        id: 1,
        countryCode: 'AR',
        countryName: 'Argentina',
        callingCode: '+54',
        active: true,
      ),
      PhoneCountryCode(
        id: 3,
        countryCode: 'BO',
        countryName: 'Bolivia',
        callingCode: '+591',
        active: true,
      ),
    ]);

    final countryCodes = await dao.getCountryCodes();

    expect(
      countryCodes.map((countryCode) => countryCode.countryName),
      ['Argentina', 'Bolivia', 'México'],
    );
  });

  test('clear vacía la tabla', () async {
    await dao.saveCountryCodes(const [
      PhoneCountryCode(
        id: 1,
        countryCode: 'CO',
        countryName: 'Colombia',
        callingCode: '+57',
        active: true,
      ),
    ]);

    await dao.clear();

    expect(await dao.getCountryCodes(), isEmpty);
  });
}
