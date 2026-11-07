import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:machuco/database/model/motel/motel_entity.dart';
import 'package:machuco/database/repository/motel/motel_dao.dart';
import 'package:machuco/models/motel/motel_model.dart';

class MotelRepositoryException implements Exception {
  const MotelRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MotelRepository {
  MotelRepository({
    required this.baseUrl,
    required this.apiKey,
    required Future<MotelDao> Function() daoProvider,
    http.Client? httpClient,
  })  : _daoProvider = daoProvider,
        _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final Future<MotelDao> Function() _daoProvider;
  final http.Client _httpClient;

  Future<List<Motel>> getMotels() async {
    final dao = await _daoProvider();

    if (baseUrl.trim().isEmpty || apiKey.trim().isEmpty) {
      return _cachedOrThrow(dao, 'Supabase no está configurado');
    }

    try {
      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/rest/v1/motels',
      ).replace(
        queryParameters: {
          'select': '*',
          'order': 'name.asc',
        },
      );
      final response = await _httpClient.get(
        uri,
        headers: {'apikey': apiKey, 'Accept': 'application/json'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _cachedOrThrow(
          dao,
          'Supabase respondió con estado ${response.statusCode}',
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      final motels = decoded
          .map((item) => _fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      await dao.replaceAll(motels.map(MotelEntity.fromModel).toList());
      return motels;
    } on MotelRepositoryException {
      rethrow;
    } catch (_) {
      return _cachedOrThrow(dao, 'No fue posible consultar Supabase');
    }
  }

  Future<Motel> addMotel(Motel newMotel) async {
    final dao = await _daoProvider();

    if (baseUrl.trim().isEmpty || apiKey.trim().isEmpty) {
      throw const MotelRepositoryException('Supabase no está configurado');
    }

    try {
      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/rest/v1/motels',
      );
      final response = await _httpClient.post(
        uri,
        headers: {
          'apikey': apiKey,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode(_toJson(newMotel)),
      );

      if (response.statusCode == 409) {
        throw const MotelRepositoryException('Ya existe un motel con ese NIT');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MotelRepositoryException(
          'Supabase respondió con estado ${response.statusCode}',
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      if (decoded.isEmpty) {
        throw const MotelRepositoryException(
          'No fue posible crear el motel',
        );
      }
      final motel = _fromJson(Map<String, dynamic>.from(decoded.first as Map));
      await dao.upsert(MotelEntity.fromModel(motel));
      return motel;
    } on MotelRepositoryException {
      rethrow;
    } catch (e) {
      if (e is MotelRepositoryException) rethrow;
      throw const MotelRepositoryException('No fue posible crear el motel');
    }
  }

  Future<Motel> updateMotel(Motel updatedMotel) async {
    final dao = await _daoProvider();

    if (baseUrl.trim().isEmpty || apiKey.trim().isEmpty) {
      throw const MotelRepositoryException('Supabase no está configurado');
    }

    try {
      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/rest/v1/motels',
      ).replace(queryParameters: {'id': 'eq.${updatedMotel.id}'});
      final response = await _httpClient.patch(
        uri,
        headers: {
          'apikey': apiKey,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode(_toJson(updatedMotel)),
      );

      if (response.statusCode == 409) {
        throw const MotelRepositoryException('Ya existe un motel con ese NIT');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MotelRepositoryException(
          'Supabase respondió con estado ${response.statusCode}',
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      if (decoded.isEmpty) {
        throw const MotelRepositoryException(
          'No fue posible actualizar el motel',
        );
      }
      final motel = _fromJson(Map<String, dynamic>.from(decoded.first as Map));
      await dao.upsert(MotelEntity.fromModel(motel));
      return motel;
    } on MotelRepositoryException {
      rethrow;
    } catch (e) {
      if (e is MotelRepositoryException) rethrow;
      throw const MotelRepositoryException('No fue posible actualizar el motel');
    }
  }

  Future<void> setAvailability(String id, bool isAvailable) async {
    final dao = await _daoProvider();

    if (baseUrl.trim().isEmpty || apiKey.trim().isEmpty) {
      throw const MotelRepositoryException('Supabase no está configurado');
    }

    try {
      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/rest/v1/motels',
      ).replace(queryParameters: {'id': 'eq.$id'});
      final response = await _httpClient.patch(
        uri,
        headers: {
          'apikey': apiKey,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({'is_available': isAvailable}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MotelRepositoryException(
          'Supabase respondió con estado ${response.statusCode}',
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      if (decoded.isEmpty) {
        throw const MotelRepositoryException(
          'No fue posible actualizar el motel',
        );
      }
      final motel = _fromJson(Map<String, dynamic>.from(decoded.first as Map));
      await dao.upsert(MotelEntity.fromModel(motel));
    } on MotelRepositoryException {
      rethrow;
    } catch (e) {
      if (e is MotelRepositoryException) rethrow;
      throw const MotelRepositoryException('No fue posible actualizar el motel');
    }
  }

  Future<List<Motel>> _cachedOrThrow(MotelDao dao, String message) async {
    final cached = await dao.findAll();
    if (cached.isNotEmpty) {
      return cached.map((e) => e.toModel()).toList();
    }
    throw MotelRepositoryException(message);
  }

  Motel _fromJson(Map<String, dynamic> json) {
    return Motel(
      id: json['id'].toString(),
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      roomCount: (json['room_count'] as num).toInt(),
      nit: json['nit'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String,
      description: json['description'] as String?,
      generalLocation: json['general_location'] as String?,
      paymentMethods: _parseStringList(json['payment_methods']),
      imageUrls: _parseStringList(json['image_urls']),
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _toJson(Motel motel) {
    return {
      'id': motel.id,
      'owner_id': motel.ownerId,
      'name': motel.name,
      'email': motel.email,
      'room_count': motel.roomCount,
      'nit': motel.nit,
      'address': motel.address,
      'phone': motel.phone,
      'description': motel.description,
      'general_location': motel.generalLocation,
      'payment_methods': motel.paymentMethods,
      'image_urls': motel.imageUrls,
      'is_available': motel.isAvailable,
    };
  }

  List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
