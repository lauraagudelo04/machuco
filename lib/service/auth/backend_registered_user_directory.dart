import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/service/auth/auth0_auth_service.dart';
import 'package:machuco/service/auth/registered_user_directory.dart';

final class BackendRegisteredUserDirectory implements RegisteredUserDirectory {
  BackendRegisteredUserDirectory({
    required String baseUrl,
    String usersPath = '/users',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client(),
       _usersUri = Uri.parse(_normalizeUrl(baseUrl, usersPath));

  final http.Client _httpClient;
  final Uri _usersUri;

  static String _normalizeUrl(String baseUrl, String usersPath) {
    final trimmedBase = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final normalizedPath = usersPath.startsWith('/') ? usersPath : '/$usersPath';
    return '$trimmedBase$normalizedPath';
  }

  @override
  Future<List<RegisteredUser>> listUsers({String? accessToken}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = accessToken?.trim() ?? '';
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;
    try {
      response = await _httpClient.get(_usersUri, headers: headers);
    } on Exception {
      throw const AuthFailure(
        AuthFailureType.network,
        'No fue posible conectar con el backend de usuarios.',
      );
    }
    if (response.statusCode != 200) {
      throw AuthFailure(
        AuthFailureType.network,
        'No fue posible consultar usuarios en backend. '
        'Código ${response.statusCode}.',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    final List<dynamic> payload = switch (decoded) {
      List<dynamic> list => list,
      Map<String, dynamic> map when map['users'] is List<dynamic> =>
        map['users']! as List<dynamic>,
      _ => const <dynamic>[],
    };

    return List<RegisteredUser>.unmodifiable(
      payload
          .whereType<Map<String, dynamic>>()
          .map(RegisteredUser.fromJson)
          .toList(),
    );
  }

  @override
  Future<void> upsertUser(RegisteredUser user) async {
    // El backend/Auth0 es la fuente de verdad. Este paso no se persiste desde app.
  }
}
