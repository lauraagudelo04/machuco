import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/repositories/booking/supabase_reservation_category_source.dart';

void main() {
  test('reads the categories from the REST endpoint', () async {
    late http.Request sent;
    final source = SupabaseReservationCategorySource(
      baseUrl: 'https://example.supabase.co/',
      apiKey: 'publishable',
      httpClient: MockClient((request) async {
        sent = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {'id': 1, 'name': 'Sencilla'},
              {'id': 5, 'name': 'Temática'},
            ]),
          ),
          200,
        );
      }),
    );

    final categories = await source.fetchAll();

    expect(sent.url.path, '/rest/v1/reservation_categories');
    expect(sent.url.queryParameters, {'select': 'id,name', 'order': 'id.asc'});
    expect(sent.headers['apikey'], 'publishable');
    expect(categories.map((c) => c.id), [1, 5]);
    expect(categories.map((c) => c.name), ['Sencilla', 'Temática']);
  });

  test('throws when Supabase does not answer 200', () async {
    final source = SupabaseReservationCategorySource(
      baseUrl: 'https://example.supabase.co',
      apiKey: 'publishable',
      httpClient: MockClient((_) async => http.Response('{}', 404)),
    );

    expect(
      source.fetchAll(),
      throwsA(isA<ReservationCategorySourceException>()),
    );
  });
}
