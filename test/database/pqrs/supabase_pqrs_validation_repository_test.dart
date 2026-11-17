import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/model/image_format/allowed_image_format_entry.dart';
import 'package:machuco/database/repository/image_format/allowed_image_format_dao.dart';
import 'package:machuco/database/repository/image_format/supabase_pqrs_validation_repository.dart';
import 'package:machuco/models/pqrs/pqrs_config_result.dart';
import 'package:machuco/models/pqrs/pqrs_image_format.dart';

import '../../fakes/in_memory_local_preferences.dart';

class _FakeFormatDao implements AllowedImageFormatDao {
  List<AllowedImageFormatEntry> rows = [];
  int replaceCalls = 0;

  @override
  Future<List<AllowedImageFormatEntry>> findAll() async => List.of(rows);

  @override
  Future<void> insertAll(List<AllowedImageFormatEntry> formats) async =>
      rows.addAll(formats);

  @override
  Future<void> deleteAll() async => rows.clear();

  @override
  Future<void> replaceAll(List<AllowedImageFormatEntry> formats) async {
    replaceCalls++;
    rows = List.of(formats);
  }
}

Map<String, dynamic> _format(
  int id,
  String mime,
  List<String> extensions, {
  bool active = true,
  int maxSize = 500000,
}) => {
  'id': id,
  'mime_type': mime,
  'extensions': extensions,
  'signatures': [
    {'offset': 0, 'hex': 'FFD8FF'},
  ],
  'max_size_bytes': maxSize,
  'is_active': active,
};

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late _FakeFormatDao dao;
  late InMemoryLocalPreferences preferences;
  late List<Uri> requests;

  SupabasePqrsValidationRepository build(
    Future<http.Response> Function(http.Request) handler, {
    String baseUrl = 'https://example.supabase.co',
    String apiKey = 'public-key',
  }) => SupabasePqrsValidationRepository(
    daoProvider: () async => dao,
    preferences: preferences,
    baseUrl: baseUrl,
    apiKey: apiKey,
    httpClient: MockClient((request) {
      requests.add(request.url);
      return handler(request);
    }),
  );

  setUp(() {
    dao = _FakeFormatDao();
    preferences = InMemoryLocalPreferences();
    requests = [];
  });

  group('formatos', () {
    test('exito: devuelve los formatos y reemplaza la cache', () async {
      dao.rows = [
        AllowedImageFormatEntry.fromFormat(
          99,
          const PqrsImageFormat(
            mimeType: 'image/gif',
            extensions: ['gif'],
            signatures: [],
          ),
        ),
      ];
      final repository = build(
        (_) async => _json([
          _format(1, 'image/jpeg', ['jpg', 'jpeg']),
          _format(2, 'image/png', ['png']),
        ]),
      );

      final result = await repository.loadImageFormats();

      expect(result.source, PqrsConfigSource.remote);
      expect(result.message, isNull);
      expect(result.value.map((f) => f.mimeType), ['image/jpeg', 'image/png']);
      expect(result.value.first.maxSizeBytes, 500000);
      expect(result.value.first.signatures.single.hex, 'FFD8FF');
      expect(dao.rows.map((e) => e.id), [1, 2]);
      expect(requests.single.path, '/rest/v1/allowed_image_formats');
      expect(requests.single.queryParameters['is_active'], 'eq.true');
    });

    test('un formato inactivo desaparece de la cache', () async {
      var phase = 1;
      final repository = build(
        (_) async => _json([
          _format(1, 'image/jpeg', ['jpg']),
          if (phase == 1) _format(2, 'image/png', ['png']),
          if (phase == 2) _format(2, 'image/png', ['png'], active: false),
        ]),
      );
      await repository.loadImageFormats();
      expect(dao.rows.length, 2);

      phase = 2;
      final result = await repository.loadImageFormats();

      expect(result.value.map((f) => f.mimeType), ['image/jpeg']);
      expect(dao.rows.map((e) => e.mimeType), ['image/jpeg']);
    });

    test('Supabase caido con cache: usa la cache y avisa', () async {
      final ok = build(
        (_) async => _json([
          _format(1, 'image/png', ['png']),
        ]),
      );
      await ok.loadImageFormats();

      final down = build((_) async => throw http.ClientException('offline'));
      final result = await down.loadImageFormats();

      expect(result.source, PqrsConfigSource.cache);
      expect(result.value.single.mimeType, 'image/png');
      expect(result.message, contains('conexión'));
    });

    test('la cache nunca devuelve un formato inactivo', () async {
      dao.rows = [
        AllowedImageFormatEntry.fromFormat(
          1,
          const PqrsImageFormat(
            mimeType: 'image/png',
            extensions: ['png'],
            signatures: [],
            isActive: false,
          ),
        ),
      ];
      final repository = build((_) async => _json('x', 500));

      final result = await repository.loadImageFormats();

      expect(result.source, PqrsConfigSource.defaults);
    });

    test('sin cache ni red usa los valores por defecto', () async {
      final repository = build((_) async => _json({}, 503));

      final result = await repository.loadImageFormats();

      expect(result.source, PqrsConfigSource.defaults);
      expect(result.value.map((f) => f.mimeType), [
        'image/jpeg',
        'image/png',
        'image/webp',
      ]);
      expect(result.message, isNotNull);
      expect(dao.replaceCalls, 0);
    });

    test(
      '401 se informa como permiso y respuesta no JSON usa defaults',
      () async {
        final denied = await build(
          (_) async => _json({}, 401),
        ).loadImageFormats();
        expect(denied.message, contains('permiso'));

        final broken = await build(
          (_) async => http.Response('<html>', 200),
        ).loadImageFormats();
        expect(broken.source, PqrsConfigSource.defaults);
      },
    );

    test('Supabase sin configurar usa cache o defaults sin llamar', () async {
      final repository = build((_) async => _json([]), baseUrl: '', apiKey: '');

      final result = await repository.loadImageFormats();

      expect(result.source, PqrsConfigSource.defaults);
      expect(requests, isEmpty);
    });
  });

  group('configuracion', () {
    test('exito: guarda un JSON bajo la clave pqrsSettings', () async {
      final repository = build(
        (_) async => _json([
          {
            'max_photos': 2,
            'image_quality': 70,
            'max_width_px': 1000,
            'max_height_px': 900,
          },
        ]),
      );

      final result = await repository.loadSettings();

      expect(result.source, PqrsConfigSource.remote);
      expect(result.value.maxPhotos, 2);
      expect(result.value.maxHeightPx, 900);
      final saved =
          jsonDecode(preferences.values['pqrsSettings']! as String) as Map;
      expect(saved['image_quality'], 70);
      expect(requests.single.queryParameters['id'], 'eq.1');
    });

    test('Supabase caido con cache: usa la configuracion guardada', () async {
      await build(
        (_) async => _json([
          {
            'max_photos': 1,
            'image_quality': 50,
            'max_width_px': 800,
            'max_height_px': 800,
          },
        ]),
      ).loadSettings();

      final result = await build(
        (_) async => throw http.ClientException('offline'),
      ).loadSettings();

      expect(result.source, PqrsConfigSource.cache);
      expect(result.value.maxPhotos, 1);
      expect(result.value.maxWidthPx, 800);
    });

    test('sin cache usa 3 fotos, calidad 60 y 1280 px', () async {
      final result = await build((_) async => _json([])).loadSettings();

      expect(result.source, PqrsConfigSource.defaults);
      expect(result.value.maxPhotos, 3);
      expect(result.value.imageQuality, 60);
      expect(result.value.maxWidthPx, 1280);
      expect(result.value.maxHeightPx, 1280);
    });

    test('una cache corrupta se ignora y usa defaults', () async {
      preferences.values['pqrsSettings'] = 'no es json';

      final result = await build((_) async => _json({}, 500)).loadSettings();

      expect(result.source, PqrsConfigSource.defaults);
    });

    test('si falla guardar la cache igual devuelve el dato remoto', () async {
      preferences.failWrites = true;

      final result = await build(
        (_) async => _json([
          {'max_photos': 2},
        ]),
      ).loadSettings();

      expect(result.source, PqrsConfigSource.remote);
      expect(result.value.maxPhotos, 2);
    });
  });
}
