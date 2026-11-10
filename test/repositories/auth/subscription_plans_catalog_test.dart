import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/repository/auth/auth_catalog_repository.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  var now = DateTime.utc(2026, 11, 4, 12);
  late AuthPreferences preferences;

  setUp(() {
    now = DateTime.utc(2026, 11, 4, 12);
    SharedPreferences.setMockInitialValues({});
    preferences = AuthPreferences(
      preferences: SharedPreferencesLocalService(namespace: 'auth'),
    );
  });

  AuthCatalogRepository build(
    http.Client client, {
    String url = 'https://example.supabase.co',
  }) => AuthCatalogRepository(
    httpClient: client,
    supabaseUrl: url,
    publishableKey: 'public-key',
    preferences: preferences,
    clock: () => now,
  );

  test(
    'consulta subscription_plans solo con id y name, ordenados por id',
    () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        expect(request.headers['apikey'], 'public-key');
        return http.Response.bytes(
          utf8.encode(
            '[{"id":1,"name":"Básico"},{"id":2,"name":"Premium"},'
            '{"id":3,"name":""},{"name":"sin id"}]',
          ),
          200,
        );
      });

      final plans = await build(client).getSubscriptionPlans();

      expect(requested.path, '/rest/v1/subscription_plans');
      expect(requested.queryParameters, {
        'select': 'id,name',
        'order': 'id.asc',
      });
      expect(plans, const [
        SubscriptionPlanOption(id: 1, name: 'Básico'),
        SubscriptionPlanOption(id: 2, name: 'Premium'),
      ]);
    },
  );

  test('usa la caché en memoria hasta que vence el TTL', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return _json('[{"id":1,"name":"Básico"}]');
    });
    final repository = build(client);

    await repository.getSubscriptionPlans();
    await repository.getSubscriptionPlans();
    expect(calls, 1);

    await repository.getSubscriptionPlans(forceRefresh: true);
    expect(calls, 2);

    now = now.add(const Duration(hours: 25));
    await repository.getSubscriptionPlans();
    expect(calls, 3);
  });

  test(
    'sin conexión devuelve la caché; sin caché lanza una excepción',
    () async {
      var online = true;
      final client = MockClient((request) async {
        if (!online) throw http.ClientException('sin red');
        return _json('[{"id":1,"name":"Básico"}]');
      });
      final repository = build(client);

      await expectLater(
        build(
          MockClient((_) async => throw http.ClientException('sin red')),
        ).getSubscriptionPlans(),
        throwsA(isA<AuthCatalogRepositoryException>()),
      );

      await repository.getSubscriptionPlans();
      online = false;
      final plans = await repository.getSubscriptionPlans(forceRefresh: true);
      expect(plans, hasLength(1));
    },
  );

  test(
    'errores HTTP, JSON malformado y URL no https lanzan excepción',
    () async {
      for (final client in [
        MockClient((_) async => http.Response('boom', 500)),
        MockClient((_) async => http.Response('{no es json', 200)),
        MockClient((_) async => http.Response('{"id":1}', 200)),
        MockClient((_) async => http.Response('[]', 200)),
      ]) {
        await expectLater(
          build(client).getSubscriptionPlans(),
          throwsA(isA<AuthCatalogRepositoryException>()),
        );
      }
      await expectLater(
        build(
          MockClient((_) async => http.Response('[]', 200)),
          url: 'http://inseguro.example.com',
        ).getSubscriptionPlans(),
        throwsA(isA<AuthCatalogRepositoryException>()),
      );
    },
  );
}

http.Response _json(String body) => http.Response.bytes(utf8.encode(body), 200);
