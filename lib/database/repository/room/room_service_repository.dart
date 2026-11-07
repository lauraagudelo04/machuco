import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:machuco/models/room/room_service.dart';
import 'package:machuco/database/repository/room/room_dao.dart';

class RoomServiceRepositoryException implements Exception {
  const RoomServiceRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Consulta el maestro de servicios incluidos expuesto por Supabase.
class RoomServiceRepository {
  RoomServiceRepository({
    required this.baseUrl,
    required this.apiKey,
    required this.roomDao,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final RoomDao roomDao;
  final http.Client _httpClient;

  Future<List<RoomService>> getIncludedServices({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await roomDao.getIncludedServices();
      if (cached.isNotEmpty) return cached;
    }

    if (baseUrl.trim().isEmpty || apiKey.trim().isEmpty) {
      return _cachedOrThrow('Supabase no está configurado');
    }

    try {
      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/rest/v1/room_included_services',
      ).replace(queryParameters: {'select': 'id,name', 'order': 'id.asc'});
      final response = await _httpClient.get(
        uri,
        headers: {'apikey': apiKey, 'Accept': 'application/json'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _cachedOrThrow(
          'Supabase respondió con estado ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      final services = decoded
          .map(
            (item) =>
                RoomService.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
      await roomDao.saveIncludedServices(services);
      return services;
    } on RoomServiceRepositoryException {
      rethrow;
    } catch (_) {
      return _cachedOrThrow('No fue posible consultar Supabase');
    }
  }

  Future<List<RoomService>> _cachedOrThrow(String message) async {
    final cached = await roomDao.getIncludedServices();
    if (cached.isNotEmpty) return cached;
    throw RoomServiceRepositoryException(message);
  }
}
