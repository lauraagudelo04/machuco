import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:machuco/database/model/pqrs_type/pqrs_type_entry.dart';
import 'package:machuco/database/repository/pqrs_type/pqrs_type_dao.dart';
import 'package:machuco/database/repository/pqrs_type/pqrs_type_repository.dart';
import 'package:machuco/models/pqrs/pqrs_config_result.dart';
import 'package:machuco/models/pqrs/pqrs_type_info.dart';
import 'package:machuco/service/supabase/supabase_config.dart';
import 'package:machuco/service/supabase/supabase_json_reader.dart';
import 'package:machuco/utils/pqrs_config_messages.dart';

/// Reads the PQRS type catalog (`pqrs_types`) from Supabase (REST, read only)
/// and caches it in Floor.
///
/// Network first; the full response replaces the cache, so a withdrawn type
/// disappears. Fallback chain: cache, then the four default types. Rows whose
/// `code` is not in the `PqrsType` enum are ignored (the app could not store
/// them and Firestore rules would reject them). A response that leaves no
/// usable type is treated as a failure, because the form would have nothing
/// to offer.
class SupabasePqrsTypeRepository implements PqrsTypeRepository {
  SupabasePqrsTypeRepository({
    required this._daoProvider,
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

  final Future<PqrsTypeDao> Function() _daoProvider;
  final SupabaseJsonReader _reader;

  @override
  Future<PqrsConfigResult<List<PqrsTypeInfo>>> loadTypes() async {
    try {
      final rows = await _reader.getRows('pqrs_types', {
        'select':
            'id,code,name,description,response_days,allows_photos,'
            'sort_order,is_active',
        'is_active': 'eq.true',
        'order': 'sort_order.asc',
      });
      final entries = [
        for (final row in rows) PqrsTypeEntry.fromJson(row),
      ].where(_isUsable).toList();
      final types = _toInfos(entries);
      if (types.isEmpty) {
        throw const SupabaseReadException(
          SupabaseReadFailure.invalidResponse,
          'pqrs_types has no usable type',
        );
      }
      await _save(entries);
      return PqrsConfigResult(value: types, source: PqrsConfigSource.remote);
    } on SupabaseReadException catch (error) {
      debugPrint('PQRS types: ${error.failure.name}');
      final cached = _toInfos((await _readCache()).where(_isUsable).toList());
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
        value: PqrsTypeInfo.defaults,
        source: PqrsConfigSource.defaults,
        message: pqrsConfigFallbackMessage(
          error.failure,
          PqrsConfigSource.defaults,
        ),
      );
    }
  }

  bool _isUsable(PqrsTypeEntry entry) =>
      entry.isActive == 1 && PqrsTypeInfo.typeFromCode(entry.code) != null;

  /// Sorted by `sortOrder`. A missing name or description falls back to the
  /// default label of that type.
  List<PqrsTypeInfo> _toInfos(List<PqrsTypeEntry> entries) {
    final sorted = List.of(entries)
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    final result = <PqrsTypeInfo>[];
    for (final entry in sorted) {
      final type = PqrsTypeInfo.typeFromCode(entry.code);
      if (type == null) continue;
      final fallback = PqrsTypeInfo.defaults.firstWhere(
        (info) => info.type == type,
      );
      result.add(
        PqrsTypeInfo(
          type: type,
          name: entry.name.isEmpty ? fallback.name : entry.name,
          description: entry.description.isEmpty
              ? fallback.description
              : entry.description,
          responseDays: entry.responseDays,
          allowsPhotos: entry.allowsPhotos == 1,
          sortOrder: entry.sortOrder,
        ),
      );
    }
    return result;
  }

  // A cache problem must not hide a good remote answer nor break the
  // fallback chain: it is logged (no data) and the chain goes on.

  Future<void> _save(List<PqrsTypeEntry> entries) async {
    try {
      final dao = await _daoProvider();
      await dao.replaceAll(entries);
    } on Exception catch (error) {
      debugPrint('PQRS types cache write failed: ${error.runtimeType}');
    }
  }

  Future<List<PqrsTypeEntry>> _readCache() async {
    try {
      final dao = await _daoProvider();
      return await dao.findAll();
    } on Exception catch (error) {
      debugPrint('PQRS types cache read failed: ${error.runtimeType}');
      return const [];
    }
  }
}
