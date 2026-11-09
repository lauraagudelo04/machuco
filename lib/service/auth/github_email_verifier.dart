import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Comprueba con la API de GitHub que un correo esté verificado (decisión
/// D5 de `docs/auth/plan-auth-social.md`).
///
/// Firebase no marca como verificados los correos que entrega GitHub, así
/// que se consulta `GET /user/emails` con el token OAuth **del usuario**
/// (alcance `user:email`), que Firebase devuelve tras `signInWithProvider`.
/// La app nunca conoce el Client Secret de la OAuth App: vive solo en la
/// configuración del proveedor en Firebase.
class GitHubEmailVerifier {
  GitHubEmailVerifier({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static final Uri _emailsUri = Uri.https('api.github.com', '/user/emails');

  final http.Client _httpClient;

  /// `true` solo si GitHub confirma que [email] pertenece al usuario y está
  /// verificado. Cualquier respuesta inesperada devuelve `false` (no se
  /// concede acceso por omisión). Lanza [GitHubEmailVerificationNetworkException]
  /// si no hay conexión, para distinguirlo de un correo no verificado.
  Future<bool> isVerified({
    required String accessToken,
    required String email,
  }) async {
    final http.Response response;
    try {
      response = await _httpClient
          .get(
            _emailsUri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      debugPrint('No fue posible consultar los correos de GitHub: $error');
      throw const GitHubEmailVerificationNetworkException();
    }

    if (response.statusCode != 200) {
      debugPrint('GitHub respondió ${response.statusCode} a /user/emails.');
      return false;
    }

    try {
      final rows = jsonDecode(utf8.decode(response.bodyBytes));
      if (rows is! List) return false;
      final normalized = email.trim().toLowerCase();
      return rows.any(
        (row) =>
            row is Map &&
            row['verified'] == true &&
            row['email']?.toString().trim().toLowerCase() == normalized,
      );
    } on FormatException {
      return false;
    }
  }
}

/// Sin conexión al consultar GitHub.
class GitHubEmailVerificationNetworkException implements Exception {
  const GitHubEmailVerificationNetworkException();
}
