import 'dart:convert';

import 'package:floor/floor.dart';
import 'package:http/http.dart' as http;
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/document_type/document_type_entry.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/service/room/supabase_room_config.dart';

@dao
abstract class DocumentTypeDao {
  @Query(
    'SELECT * FROM document_types WHERE isActive = 1 ORDER BY sortOrder ASC',
  )
  Future<List<DocumentTypeEntry>> findActive();

  @Query('SELECT * FROM document_types ORDER BY sortOrder ASC')
  Future<List<DocumentTypeEntry>> findAll();

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertDocumentTypes(List<DocumentTypeEntry> types);

  @Query('DELETE FROM document_types')
  Future<void> deleteAll();
}

class DocumentTypeRepositoryException implements Exception {
  const DocumentTypeRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Acceso al maestro de tipos de documento.
///
/// La tabla local `document_types` es la fuente de verdad para la interfaz: se
/// puede leer sin conexión. Cuando [getActiveDocumentTypes] recibe
/// `forceRefresh: true` consulta Supabase por REST y reemplaza la caché; si la
/// red falla y hay filas guardadas, devuelve la caché sin interrumpir el
/// formulario.
///
/// Los datos de dominio de propietarios van a Firestore; este catálogo es un
/// maestro y por eso vive en Supabase, igual que los indicativos.
class DocumentTypeRepository {
  DocumentTypeRepository({
    AppDatabase? database,
    http.Client? httpClient,
    String? supabaseUrl,
    String? apiKey,
    this.timeout = const Duration(seconds: 10),
  }) : _database = database == null
           ? AppDatabaseProvider.database
           : Future.value(database),
       _httpClient = httpClient ?? http.Client(),
       _supabaseUrl = supabaseUrl ?? SupabaseRoomConfig.baseUrl,
       _apiKey = apiKey ?? SupabaseRoomConfig.apiKey;

  static const _columns = 'id,code,name,pattern,example,is_active,sort_order';

  final Future<AppDatabase> _database;
  final http.Client _httpClient;
  final String _supabaseUrl;
  final String _apiKey;
  final Duration timeout;

  bool get isConfigured =>
      _supabaseUrl.trim().isNotEmpty && _apiKey.trim().isNotEmpty;

  /// Lee solo la caché local, sin tocar la red.
  ///
  /// Traduce las filas de `document_types` a los valores de [DocumentType]. Las
  /// filas cuyo [DocumentTypeEntry.code] ya no existe en el enum se ignoran
  /// para no romper el selector tras un despliegue parcial.
  Future<List<DocumentType>> findActive() async {
    final database = await _database;
    return _toDomain(await database.documentTypeDao.findActive());
  }

  /// Devuelve los tipos activos, refrescando el maestro desde Supabase si se
  /// pide explícitamente.
  ///
  /// Por defecto responde con la caché local, que ya viene sembrada con los
  /// cinco códigos base: la consulta remota solo se hace con
  /// [forceRefresh] para no penalizar la apertura del formulario.
  Future<List<DocumentType>> getActiveDocumentTypes({
    bool forceRefresh = false,
  }) async {
    final cached = await findActive();
    if (!forceRefresh) return cached;

    if (!isConfigured) {
      return _cachedOrThrow(
        cached,
        'Supabase no está configurado para cargar los tipos de documento.',
      );
    }

    try {
      final uri =
          Uri.parse(
            '${_supabaseUrl.replaceFirst(RegExp(r'/$'), '')}'
            '/rest/v1/document_types',
          ).replace(
            queryParameters: {
              'select': _columns,
              'is_active': 'eq.true',
              'order': 'sort_order.asc',
            },
          );
      final response = await _httpClient
          .get(uri, headers: {'apikey': _apiKey, 'Accept': 'application/json'})
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _cachedOrThrow(
          cached,
          'Supabase respondió con estado ${response.statusCode}',
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      final entries = decoded
          .map(
            (item) => DocumentTypeEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where(
            (entry) =>
                entry.isActive == 1 &&
                DocumentType.fromCode(entry.code) != null,
          )
          .toList(growable: false);

      // Un catálogo vacío no debe borrar la caché: es más probable que sea un
      // despliegue incompleto que un retiro real de todos los tipos.
      if (entries.isNotEmpty) {
        await _replaceCache(entries);
      }

      final refreshed = _toDomain(entries);
      if (refreshed.isNotEmpty) return refreshed;
      return _cachedOrThrow(
        cached,
        'El maestro de tipos de documento llegó vacío.',
      );
    } on DocumentTypeRepositoryException {
      rethrow;
    } catch (_) {
      return _cachedOrThrow(cached, 'No fue posible consultar Supabase');
    }
  }

  Future<void> _replaceCache(List<DocumentTypeEntry> entries) async {
    final dao = (await _database).documentTypeDao;
    await dao.deleteAll();
    await dao.insertDocumentTypes(entries);
  }

  List<DocumentType> _toDomain(List<DocumentTypeEntry> entries) {
    return [
      for (final entry in entries)
        if (DocumentType.fromCode(entry.code) case final type?) type,
    ];
  }

  List<DocumentType> _cachedOrThrow(List<DocumentType> cached, String message) {
    if (cached.isNotEmpty) return cached;
    throw DocumentTypeRepositoryException(message);
  }
}
