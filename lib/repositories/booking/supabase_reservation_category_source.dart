import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:machuco/models/booking/reservation_category.dart';

/// Thrown when the reservation category master cannot be read from Supabase.
class ReservationCategorySourceException implements Exception {
  const ReservationCategorySourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads the `reservation_categories` master from Supabase (REST API).
class SupabaseReservationCategorySource {
  SupabaseReservationCategorySource({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _httpClient;

  Future<List<ReservationCategory>> fetchAll() async {
    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/rest/v1/reservation_categories',
    ).replace(queryParameters: {'select': 'id,name', 'order': 'id.asc'});
    final response = await _httpClient
        .get(uri, headers: {'apikey': apiKey, 'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw ReservationCategorySourceException(
        'Supabase respondió ${response.statusCode} al leer las categorías',
      );
    }
    final rows = jsonDecode(utf8.decode(response.bodyBytes));
    if (rows is! List) {
      throw const ReservationCategorySourceException(
        'Respuesta inesperada al leer las categorías',
      );
    }
    return rows
        .map(
          (row) => ReservationCategory.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }
}
