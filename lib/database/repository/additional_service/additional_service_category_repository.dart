import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/additional_service/additional_service_category_dao.dart';
import 'package:machuco/models/additional_service/additional_service_category.dart';

class AdditionalServiceCategoryRepositoryException implements Exception {
  const AdditionalServiceCategoryRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AdditionalServiceCategoryRepository {
  AdditionalServiceCategoryRepository({
    AppDatabase? database,
    http.Client? client,
    String? supabaseUrl,
    String? publishableKey,
  }) : _database = database == null
           ? AppDatabaseProvider.database
           : Future.value(database),
       _get = client?.get ?? http.get,
       _supabaseUrl =
           supabaseUrl ??
           const String.fromEnvironment(
             'SUPABASE_URL',
             defaultValue: 'https://ogrbbuwtsyezegkpwtsl.supabase.co',
           ),
       _publishableKey =
           publishableKey ??
           const String.fromEnvironment(
             'SUPABASE_ANON_KEY',
             defaultValue: 'sb_publishable_Wv16MVxsTzA89lBeocarLQ_YL33Ya_E',
           );

  final Future<AppDatabase> _database;
  final Future<http.Response> Function(Uri, {Map<String, String>? headers})
  _get;
  final String _supabaseUrl;
  final String _publishableKey;

  /// Consulta el maestro `categories` en Supabase y lo guarda en SQLite.
  /// Si no hay red o la consulta falla, devuelve la copia local.
  Future<List<AdditionalServiceCategory>> getCategories() async {
    final db = await _database;
    final dao = db.additionalServiceCategoryDao;

    final base = Uri.tryParse(_supabaseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        _publishableKey.isEmpty) {
      final cached = await _cachedOrThrow(dao);
      if (cached != null) return cached;
      throw const AdditionalServiceCategoryRepositoryException(
        'El catálogo de categorías no está configurado.',
      );
    }

    final uri = base.replace(
      path: '/rest/v1/categories',
      queryParameters: {'select': 'id,name,created_at', 'order': 'name.asc'},
    );

    try {
      final response = await _get(
        uri,
        headers: {'apikey': _publishableKey, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        final cached = await _cachedOrThrow(dao);
        if (cached != null) return cached;
        throw const AdditionalServiceCategoryRepositoryException(
          'No se pudieron consultar las categorías.',
        );
      }

      final rows = jsonDecode(utf8.decode(response.bodyBytes));
      if (rows is! List) {
        final cached = await _cachedOrThrow(dao);
        if (cached != null) return cached;
        throw const AdditionalServiceCategoryRepositoryException(
          'Las categorías devolvieron datos inválidos.',
        );
      }

      final categories = rows
          .map(
            (row) =>
                AdditionalServiceCategory.fromJson(row as Map<String, dynamic>),
          )
          .toList(growable: false);

      await dao.deleteAll();
      if (categories.isNotEmpty) {
        await dao.insertAll(categories);
      }
      return categories;
    } catch (error) {
      if (error is AdditionalServiceCategoryRepositoryException) rethrow;
      final cached = await _cachedOrThrow(dao);
      if (cached != null) return cached;
      throw const AdditionalServiceCategoryRepositoryException(
        'No se pudo conectar con el catálogo de categorías.',
      );
    }
  }

  Future<List<AdditionalServiceCategory>?> _cachedOrThrow(
    AdditionalServiceCategoryDao dao,
  ) async {
    final cached = await dao.findAll();
    return cached.isNotEmpty ? cached : null;
  }
}
