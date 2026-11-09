// Migraciones SQLite del módulo de autenticación (versión 14,
// `auth_user_profile`). Complementa la prueba 13 -> 14 de
// test/repositories/auth/auth_user_profile_repository_test.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _profileColumns = {
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
};

Future<Set<String>> _columns(sqflite.Database db, String table) async => {
  for (final row in await db.rawQuery('PRAGMA table_info($table)'))
    row['name']! as String,
};

Future<bool> _tableExists(sqflite.Database db, String table) async =>
    (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    )).isNotEmpty;

void main() {
  late Directory directory;
  late String path;
  late AppDatabase database;

  sqflite.Database raw() => database.database as sqflite.Database;

  Future<void> reopen() async {
    await database.close();
    database = await AppDatabaseProvider.open(name: path);
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_auth_mig_');
    path = '${directory.path}${Platform.pathSeparator}auth.db';
    database = await AppDatabaseProvider.open(name: path);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('[MIG-01] instalación nueva: versión 14 con auth_user_profile sin '
      'NIT ni fecha de nacimiento', () async {
    expect(await raw().getVersion(), 14);
    final columns = await _columns(raw(), 'auth_user_profile');
    expect(columns, _profileColumns);
    expect(
      columns.any((c) => c.contains('nit') || c.contains('birth')),
      isFalse,
    );
    expect(await _tableExists(raw(), 'phone_country_codes'), isTrue);
    // Tabla obsoleta que se conserva hasta una migración acordada.
    expect(await _tableExists(raw(), 'country_phone_codes'), isTrue);
  });

  test(
    '[MIG-02] de v11 a v14 aplica todas las migraciones sin perder datos',
    () async {
      final db = raw();
      await db.execute('DROP TABLE auth_user_profile');
      await db.execute('ALTER TABLE clients ADD COLUMN password TEXT');
      await db.insert('clients', {
        'name': 'Ana',
        'phone': '3001234567',
        'email': 'ana@example.com',
        'country_code': '+57',
        'password': 'no-debe-quedar',
      });
      await db.insert('phone_country_codes', {
        'id': 1,
        'country_code': 'CO',
        'country_name': 'Colombia',
        'calling_code': '+57',
        'active': 1,
      });
      await db.setVersion(11);

      await reopen();

      expect(await raw().getVersion(), 14);
      expect(await _columns(raw(), 'auth_user_profile'), _profileColumns);
      expect(await _columns(raw(), 'clients'), isNot(contains('password')));
      final clients = await raw().query('clients');
      expect(clients.single['email'], 'ana@example.com');
      expect((await raw().query('phone_country_codes')).single['id'], 1);
    },
  );

  test('[MIG-05] una v13 sin auth_user_profile (develop) recibe la tabla y '
      'conserva sus datos', () async {
    final db = raw();
    await db.execute('DROP TABLE auth_user_profile');
    await db.insert('clients', {
      'name': 'Ana',
      'phone': '3001234567',
      'email': 'ana@example.com',
      'country_code': '+57',
    });
    await db.setVersion(13);

    await reopen();

    expect(await raw().getVersion(), 14);
    expect(await _columns(raw(), 'auth_user_profile'), _profileColumns);
    final clients = await raw().query('clients');
    expect(clients.single['email'], 'ana@example.com');
  });

  test('[MIG-03] 13 -> 14 es idempotente: una v13 de la rama de autenticación '
      'conserva su fila', () async {
    await raw().insert('auth_user_profile', {
      'uid': 'u1',
      'email': 'ana@example.com',
      'first_names': 'Ana',
      'last_names': 'Pérez',
      'role': 'client',
      'account_status': 'active',
      'synced_at': '2026-11-05T00:00:00.000Z',
    });
    await raw().setVersion(13);

    await reopen();

    expect(await raw().getVersion(), 14);
    expect((await raw().query('auth_user_profile')).single['uid'], 'u1');
  });

  test(
    '[MIG-04] la clave primaria impide dos filas con el mismo uid',
    () async {
      final row = {
        'uid': 'u1',
        'email': 'ana@example.com',
        'first_names': 'Ana',
        'last_names': 'Pérez',
        'role': 'client',
        'account_status': 'active',
        'synced_at': '2026-11-05T00:00:00.000Z',
      };
      await raw().insert('auth_user_profile', row);

      await expectLater(
        raw().insert('auth_user_profile', row),
        throwsA(isA<sqflite.DatabaseException>()),
      );
    },
  );

  test('[MIG-05] los valores con comillas se guardan literales (consultas '
      'parametrizadas)', () async {
    const injection = "x'); DROP TABLE auth_user_profile; --";
    await raw().insert('auth_user_profile', {
      'uid': 'u1',
      'email': 'ana@example.com',
      'first_names': injection,
      'last_names': 'Pérez',
      'role': 'client',
      'account_status': 'active',
      'synced_at': '2026-11-05T00:00:00.000Z',
    });

    expect(await _tableExists(raw(), 'auth_user_profile'), isTrue);
    expect(
      (await raw().query(
        'auth_user_profile',
        where: 'first_names = ?',
        whereArgs: [injection],
      )).single['uid'],
      'u1',
    );
  });
}
