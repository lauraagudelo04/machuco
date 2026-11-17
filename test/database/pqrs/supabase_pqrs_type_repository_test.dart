import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/model/pqrs_type/pqrs_type_entry.dart';
import 'package:machuco/database/repository/pqrs_type/pqrs_type_dao.dart';
import 'package:machuco/database/repository/pqrs_type/supabase_pqrs_type_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/models/pqrs/pqrs_config_result.dart';

class _FakeTypeDao implements PqrsTypeDao {
  List<PqrsTypeEntry> rows = [];

  @override
  Future<List<PqrsTypeEntry>> findAll() async => List.of(rows);

  @override
  Future<void> insertAll(List<PqrsTypeEntry> types) async => rows.addAll(types);

  @override
  Future<void> deleteAll() async => rows.clear();

  @override
  Future<void> replaceAll(List<PqrsTypeEntry> types) async =>
      rows = List.of(types);
}

Map<String, dynamic> _type(
  int id,
  String code,
  int order, {
  String name = 'Nombre',
  String description = 'Ayuda',
  int days = 10,
  bool photos = true,
  bool active = true,
}) => {
  'id': id,
  'code': code,
  'name': name,
  'description': description,
  'response_days': days,
  'allows_photos': photos,
  'sort_order': order,
  'is_active': active,
};

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late _FakeTypeDao dao;
  late List<Uri> requests;

  SupabasePqrsTypeRepository build(
    Future<http.Response> Function(http.Request) handler,
  ) => SupabasePqrsTypeRepository(
    daoProvider: () async => dao,
    baseUrl: 'https://example.supabase.co',
    apiKey: 'public-key',
    httpClient: MockClient((request) {
      requests.add(request.url);
      return handler(request);
    }),
  );

  setUp(() {
    dao = _FakeTypeDao();
    requests = [];
  });

  test(
    'exito: ordena por sort_order, conserva acentos y llena la cache',
    () async {
      final repository = build(
        (_) async => _json([
          _type(2, 'queja', 2, name: 'Queja ñ', days: 5, photos: false),
          _type(1, 'peticion', 1, name: 'Petición'),
        ]),
      );

      final result = await repository.loadTypes();

      expect(result.source, PqrsConfigSource.remote);
      expect(result.value.map((t) => t.type), [
        PqrsType.peticion,
        PqrsType.queja,
      ]);
      expect(result.value.first.name, 'Petición');
      expect(result.value.last.responseDays, 5);
      expect(result.value.last.allowsPhotos, isFalse);
      expect(dao.rows.length, 2);
      expect(requests.single.queryParameters['order'], 'sort_order.asc');
      expect(requests.single.queryParameters['is_active'], 'eq.true');
    },
  );

  test('un tipo inactivo desaparece al reemplazar la cache', () async {
    var phase = 1;
    final repository = build(
      (_) async => _json([
        _type(1, 'peticion', 1),
        if (phase == 1) _type(2, 'queja', 2),
        if (phase == 2) _type(2, 'queja', 2, active: false),
      ]),
    );
    await repository.loadTypes();
    expect(dao.rows.length, 2);

    phase = 2;
    final result = await repository.loadTypes();

    expect(result.value.map((t) => t.type), [PqrsType.peticion]);
    expect(dao.rows.map((e) => e.code), ['peticion']);
  });

  test('un code desconocido se ignora y no entra en la cache', () async {
    final repository = build(
      (_) async => _json([
        _type(1, 'peticion', 1),
        _type(9, 'denuncia', 2),
        _type(3, 'sugerencia', 3),
      ]),
    );

    final result = await repository.loadTypes();

    expect(result.value.map((t) => t.type), [
      PqrsType.peticion,
      PqrsType.sugerencia,
    ]);
    expect(dao.rows.map((e) => e.code), ['peticion', 'sugerencia']);
  });

  test('nombre vacio usa la etiqueta por defecto del tipo', () async {
    final repository = build(
      (_) async => _json([_type(1, 'reclamo', 1, name: '', description: '')]),
    );

    final result = await repository.loadTypes();

    expect(result.value.single.name, 'Reclamo');
    expect(result.value.single.description, contains('cobro'));
  });

  test('Supabase caido con cache: usa la cache ordenada y avisa', () async {
    await build(
      (_) async => _json([_type(2, 'queja', 2), _type(1, 'peticion', 1)]),
    ).loadTypes();

    final result = await build(
      (_) async => throw http.ClientException('offline'),
    ).loadTypes();

    expect(result.source, PqrsConfigSource.cache);
    expect(result.value.map((t) => t.type), [
      PqrsType.peticion,
      PqrsType.queja,
    ]);
    expect(result.message, contains('conexión'));
  });

  test('sin cache usa los 4 tipos por defecto con 15 dias y fotos', () async {
    final result = await build((_) async => _json({}, 500)).loadTypes();

    expect(result.source, PqrsConfigSource.defaults);
    expect(result.value.map((t) => t.name), [
      'Petición',
      'Queja',
      'Reclamo',
      'Sugerencia',
    ]);
    expect(result.value.every((t) => t.responseDays == 15), isTrue);
    expect(result.value.every((t) => t.allowsPhotos), isTrue);
    expect(result.value.first.description, contains('motel'));
    expect(result.message, isNotNull);
  });

  test('una respuesta sin tipos utilizables no vacia la cache', () async {
    await build((_) async => _json([_type(1, 'queja', 1)])).loadTypes();

    final result = await build(
      (_) async => _json([_type(9, 'denuncia', 1)]),
    ).loadTypes();

    expect(result.source, PqrsConfigSource.cache);
    expect(result.value.single.type, PqrsType.queja);
    expect(dao.rows.single.code, 'queja');
  });
}
