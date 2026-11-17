import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Why a Supabase read failed. It lets callers tell a connection problem
/// from a permission or a server problem and show a fitting message.
enum SupabaseReadFailure {
  notConfigured,
  connection,
  permission,
  server,
  invalidResponse,
}

class SupabaseReadException implements Exception {
  const SupabaseReadException(this.failure, this.message);

  final SupabaseReadFailure failure;

  /// Technical description, safe to log (never carries keys or row data).
  final String message;

  @override
  String toString() => 'SupabaseReadException(${failure.name}): $message';
}

/// Minimal read-only client for the Supabase REST API (`GET /rest/v1/<table>`)
/// built on `http`, shared by the masters that are consulted network first.
class SupabaseJsonReader {
  SupabaseJsonReader({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final Duration timeout;
  final http.Client _httpClient;

  /// Returns the rows of [table] filtered by [query] (PostgREST syntax).
  /// Throws [SupabaseReadException] on any failure.
  Future<List<Map<String, dynamic>>> getRows(
    String table,
    Map<String, String> query,
  ) async {
    if (baseUrl.trim().isEmpty || apiKey.trim().isEmpty) {
      throw const SupabaseReadException(
        SupabaseReadFailure.notConfigured,
        'Supabase is not configured',
      );
    }

    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/rest/v1/$table',
    ).replace(queryParameters: query);

    final http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: {'apikey': apiKey, 'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw SupabaseReadException(
        SupabaseReadFailure.connection,
        'Timeout reading $table',
      );
    } on SocketException {
      throw SupabaseReadException(
        SupabaseReadFailure.connection,
        'No connection reading $table',
      );
    } on http.ClientException {
      throw SupabaseReadException(
        SupabaseReadFailure.connection,
        'Client error reading $table',
      );
    }

    final status = response.statusCode;
    if (status == 401 || status == 403) {
      throw SupabaseReadException(
        SupabaseReadFailure.permission,
        'Supabase denied reading $table (status $status)',
      );
    }
    if (status < 200 || status >= 300) {
      throw SupabaseReadException(
        SupabaseReadFailure.server,
        'Supabase answered status $status reading $table',
      );
    }

    final Object? decoded;
    try {
      // UTF-8 explicitly so accents in names and help texts survive.
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw SupabaseReadException(
        SupabaseReadFailure.invalidResponse,
        'Response of $table is not valid JSON',
      );
    }
    if (decoded is! List) {
      throw SupabaseReadException(
        SupabaseReadFailure.invalidResponse,
        'Response of $table is not a list',
      );
    }
    return [
      for (final item in decoded)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
}
