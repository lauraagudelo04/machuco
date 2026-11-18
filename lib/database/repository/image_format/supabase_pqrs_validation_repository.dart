import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:machuco/database/model/image_format/allowed_image_format_entry.dart';
import 'package:machuco/database/repository/image_format/allowed_image_format_dao.dart';
import 'package:machuco/database/repository/image_format/pqrs_validation_repository.dart';
import 'package:machuco/models/pqrs/pqrs_config_result.dart';
import 'package:machuco/models/pqrs/pqrs_image_format.dart';
import 'package:machuco/models/pqrs/pqrs_settings.dart';
import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/supabase/supabase_config.dart';
import 'package:machuco/service/supabase/supabase_json_reader.dart';
import 'package:machuco/utils/pqrs_config_messages.dart';

/// Reads the allowed image formats and the general PQRS settings from
/// Supabase (REST, read only) and caches them locally.
///
/// Network first: a withdrawn format (`is_active = false`) would keep being
/// accepted if the cache were consulted first. Chain per part: Supabase, then
/// cache, then defaults. The formats list lives in Floor
/// (`allowed_image_formats`, replaced by the full response); the single
/// settings row lives in `shared_preferences` under [settingsKey].
///
/// Client-side validation does not replace Firestore rules: the 900 KB and
/// 3 photos limits are also enforced by the backend.
class SupabasePqrsValidationRepository implements PqrsValidationRepository {
  SupabasePqrsValidationRepository({
    required this._daoProvider,
    required this._preferences,
    String baseUrl = SupabaseConfig.baseUrl,
    String apiKey = SupabaseConfig.apiKey,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  }) : _reader = SupabaseJsonReader(
         baseUrl: baseUrl,
         apiKey: apiKey,
         httpClient: httpClient,
         timeout: timeout,
       );

  /// Key inside the `pqrs` namespace of [LocalPreferencesService].
  static const settingsKey = 'pqrsSettings';

  final Future<AllowedImageFormatDao> Function() _daoProvider;
  final LocalPreferencesService _preferences;
  final SupabaseJsonReader _reader;

  @override
  Future<PqrsConfigResult<List<PqrsImageFormat>>> loadImageFormats() async {
    try {
      final rows = await _reader.getRows('allowed_image_formats', {
        'select': 'id,mime_type,extensions,signatures,max_size_bytes,is_active',
        'is_active': 'eq.true',
        'order': 'id.asc',
      });
      final entries = <AllowedImageFormatEntry>[];
      for (var index = 0; index < rows.length; index++) {
        final format = PqrsImageFormat.fromJson(rows[index]);
        // An inactive or unnamed format is never kept, even if the API sent it.
        if (!format.isActive || format.mimeType.isEmpty) continue;
        final id = rows[index]['id'];
        entries.add(
          AllowedImageFormatEntry.fromFormat(
            id is int ? id : index + 1,
            format,
          ),
        );
      }
      await _saveFormats(entries);
      return PqrsConfigResult(
        value: [for (final entry in entries) entry.toFormat()],
        source: PqrsConfigSource.remote,
      );
    } on SupabaseReadException catch (error) {
      debugPrint('PQRS formats: ${error.failure.name}');
      final cached = await _readCachedFormats();
      if (cached.isNotEmpty) {
        return PqrsConfigResult(
          value: cached,
          source: PqrsConfigSource.cache,
          message: pqrsConfigFallbackMessage(
            error.failure,
            PqrsConfigSource.cache,
          ),
        );
      }
      return PqrsConfigResult(
        value: PqrsImageFormat.defaults,
        source: PqrsConfigSource.defaults,
        message: pqrsConfigFallbackMessage(
          error.failure,
          PqrsConfigSource.defaults,
        ),
      );
    }
  }

  @override
  Future<PqrsConfigResult<PqrsSettings>> loadSettings() async {
    try {
      final rows = await _reader.getRows('pqrs_settings', {
        'select': 'max_photos,image_quality,max_width_px,max_height_px',
        'id': 'eq.1',
        'limit': '1',
      });
      if (rows.isEmpty) {
        throw const SupabaseReadException(
          SupabaseReadFailure.invalidResponse,
          'pqrs_settings has no row',
        );
      }
      final settings = PqrsSettings.fromJson(rows.first);
      await _saveSettings(settings);
      return PqrsConfigResult(value: settings, source: PqrsConfigSource.remote);
    } on SupabaseReadException catch (error) {
      debugPrint('PQRS settings: ${error.failure.name}');
      final cached = await _readCachedSettings();
      if (cached != null) {
        return PqrsConfigResult(
          value: cached,
          source: PqrsConfigSource.cache,
          message: pqrsConfigFallbackMessage(
            error.failure,
            PqrsConfigSource.cache,
          ),
        );
      }
      return PqrsConfigResult(
        value: const PqrsSettings(),
        source: PqrsConfigSource.defaults,
        message: pqrsConfigFallbackMessage(
          error.failure,
          PqrsConfigSource.defaults,
        ),
      );
    }
  }

  // A cache problem must not hide a good remote answer nor break the
  // fallback chain: it is logged (no data) and the chain goes on.

  Future<void> _saveFormats(List<AllowedImageFormatEntry> entries) async {
    try {
      final dao = await _daoProvider();
      await dao.replaceAll(entries);
    } on Exception catch (error) {
      debugPrint('PQRS formats cache write failed: ${error.runtimeType}');
    }
  }

  Future<List<PqrsImageFormat>> _readCachedFormats() async {
    try {
      final dao = await _daoProvider();
      return [
        for (final entry in await dao.findAll())
          if (entry.isActive == 1) entry.toFormat(),
      ];
    } on Exception catch (error) {
      debugPrint('PQRS formats cache read failed: ${error.runtimeType}');
      return const [];
    }
  }

  Future<void> _saveSettings(PqrsSettings settings) async {
    try {
      await _preferences.setString(settingsKey, jsonEncode(settings.toJson()));
    } on Exception catch (error) {
      debugPrint('PQRS settings cache write failed: ${error.runtimeType}');
    }
  }

  Future<PqrsSettings?> _readCachedSettings() async {
    try {
      final raw = await _preferences.getString(settingsKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return PqrsSettings.fromJson(Map<String, dynamic>.from(decoded));
    } on Exception catch (error) {
      debugPrint('PQRS settings cache read failed: ${error.runtimeType}');
      return null;
    }
  }
}
