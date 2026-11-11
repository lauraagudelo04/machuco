import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:machuco/models/review/review.dart';

class ReviewTypeRepositoryException implements Exception {
  const ReviewTypeRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Consulta el maestro de tipos de reseña expuesto por Supabase.
class ReviewTypeRepository {
  ReviewTypeRepository({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _httpClient;

  /// Devuelve los tipos de la tabla `review_types` ordenados por id.
  ///
  /// Las filas cuyo id no tiene un [ReviewType] en la app se omiten.
  Future<List<ReviewTypeOption>> getReviewTypes() async {
    if (baseUrl.trim().isEmpty || apiKey.trim().isEmpty) {
      throw const ReviewTypeRepositoryException('Supabase no está configurado');
    }

    final http.Response response;
    try {
      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/rest/v1/review_types',
      ).replace(queryParameters: {'select': 'id,name', 'order': 'id.asc'});
      response = await _httpClient.get(
        uri,
        headers: {'apikey': apiKey, 'Accept': 'application/json'},
      );
    } catch (_) {
      throw const ReviewTypeRepositoryException(
        'No fue posible consultar Supabase',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReviewTypeRepositoryException(
        'Supabase respondió con estado ${response.statusCode}',
      );
    }

    final List<ReviewTypeOption> options;
    try {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      options = [
        for (final item in decoded.cast<Map<String, dynamic>>())
          if (ReviewType.fromId((item['id'] as num).toInt()) case final type?)
            (type: type, name: item['name'] as String),
      ];
    } catch (_) {
      throw const ReviewTypeRepositoryException(
        'Supabase devolvió tipos de reseña con un formato inesperado',
      );
    }

    if (options.isEmpty) {
      throw const ReviewTypeRepositoryException(
        'No hay tipos de reseña registrados',
      );
    }
    return options;
  }
}
