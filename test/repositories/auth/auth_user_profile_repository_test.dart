import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/auth/auth_user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

UserProfile _profile(String uid, {String email = 'ana@example.com'}) =>
    UserProfile(
      uid: uid,
      fullName: 'Ana Pérez',
      email: email,
      phoneNumber: '+573001234567',
      role: RegisteredUserRole.owner,
      accountStatus: AccountStatus.pendingApproval,
      firstNames: 'Ana',
      lastNames: 'Pérez',
      phoneCountryCodeId: 1,
      personType: PersonType.juridica,
      nit: '900123456-8',
      companyName: 'Moteles SAS',
      birthDate: DateTime.utc(1990, 5, 20),
    );

void main() {
  late Directory directory;
  late String path;
  late AppDatabase database;
  final now = DateTime.utc(2026, 11, 4, 12);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_auth_profile_');
    path = '${directory.path}${Platform.pathSeparator}profile.db';
    database = await AppDatabaseProvider.open(name: path);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  FloorAuthUserProfileRepository buildRepository() =>
      FloorAuthUserProfileRepository(database: database, clock: () => now);

  test('loadCurrent devuelve null cuando no hay perfil', () async {
    expect(await buildRepository().loadCurrent(), isNull);
  });

  test(
    'saveCurrent guarda el perfil básico sin NIT ni fecha de nacimiento',
    () async {
      final repository = buildRepository();

      await repository.saveCurrent(_profile('u1', email: ' Ana@Example.COM '));

      final entry = await repository.loadCurrent();
      expect(entry?.uid, 'u1');
      expect(entry?.email, 'ana@example.com');
      expect(entry?.firstNames, 'Ana');
      expect(entry?.lastNames, 'Pérez');
      expect(entry?.role, 'owner');
      expect(entry?.accountStatus, 'pending_approval');
      expect(entry?.phoneCountryCodeId, 1);
      expect(entry?.phoneNumber, '+573001234567');
      expect(entry?.companyName, 'Moteles SAS');
      expect(entry?.syncedAt, '2026-11-04T12:00:00.000Z');

      final raw = database.database as sqflite.Database;
      final columns = (await raw.rawQuery(
        'PRAGMA table_info(auth_user_profile)',
      )).map((c) => c['name']).toList();
      expect(columns, [
        'uid',
        'email',
        'first_names',
        'last_names',
        'role',
        'account_status',
        'phone_country_code_id',
        'phone_number',
        'company_name',
        'synced_at',
      ]);
      final stored = (await raw.query(
        'auth_user_profile',
      )).single.values.join('|');
      expect(stored, isNot(contains('900123456')));
      expect(stored, isNot(contains('1990')));
    },
  );

  test('mantiene una sola fila: otro usuario reemplaza al anterior', () async {
    final repository = buildRepository();
    await repository.saveCurrent(_profile('u1'));
    await repository.saveCurrent(_profile('u2', email: 'luz@example.com'));

    final raw = database.database as sqflite.Database;
    expect(await raw.query('auth_user_profile'), hasLength(1));
    expect((await repository.loadCurrent())?.uid, 'u2');

    await repository.saveCurrent(_profile('u2', email: 'luz@example.com'));
    expect(await raw.query('auth_user_profile'), hasLength(1));
  });

  test('clear elimina la fila y es idempotente', () async {
    final repository = buildRepository();
    await repository.saveCurrent(_profile('u1'));
    await repository.clear();
    await repository.clear();
    expect(await repository.loadCurrent(), isNull);
  });

  test('un perfil sin nombres separados usa fullName como nombres', () async {
    final repository = buildRepository();
    await repository.saveCurrent(
      const UserProfile(
        uid: 'u3',
        fullName: 'Pedro Gil',
        email: 'pedro@example.com',
        phoneNumber: '',
        role: RegisteredUserRole.client,
        accountStatus: AccountStatus.active,
      ),
    );
    final entry = await repository.loadCurrent();
    expect(entry?.firstNames, 'Pedro Gil');
    expect(entry?.lastNames, '');
    expect(entry?.phoneNumber, isNull);
  });

  test('migra de v12 a la versión actual creando la tabla y conservando los '
      'datos', () async {
    var raw = database.database as sqflite.Database;
    await raw.execute('DROP TABLE auth_user_profile');
    await raw.insert('phone_country_codes', {
      'id': 77,
      'country_code': 'CO',
      'country_name': 'Colombia',
      'calling_code': '+57',
      'active': 1,
    });
    await raw.setVersion(12);
    final previousCodes = await raw.query('phone_country_codes');
    await database.close();

    database = await AppDatabaseProvider.open(name: path);
    raw = database.database as sqflite.Database;

    expect(await raw.getVersion(), 17);
    expect(await raw.query('phone_country_codes'), previousCodes);
    final repository = buildRepository();
    expect(await repository.loadCurrent(), isNull);
    await repository.saveCurrent(_profile('u1'));
    expect((await repository.loadCurrent())?.uid, 'u1');
    expect(
      (await raw.rawQuery('PRAGMA table_info(auth_user_profile)')).length,
      10,
    );
  });

  test('InMemoryAuthUserProfileRepository cumple el mismo contrato', () async {
    final repository = InMemoryAuthUserProfileRepository(clock: () => now);
    expect(await repository.loadCurrent(), isNull);
    await repository.saveCurrent(_profile('u1'));
    await repository.saveCurrent(_profile('u2'));
    expect((await repository.loadCurrent())?.uid, 'u2');
    await repository.clear();
    expect(await repository.loadCurrent(), isNull);
  });
}
