import 'package:flutter/foundation.dart';
import 'package:machuco/database/repository/pqrs_type/pqrs_type_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/models/pqrs/pqrs_config_result.dart';
import 'package:machuco/models/pqrs/pqrs_type_info.dart';
import 'package:machuco/repositories/pqrs/pqrs_repository_provider.dart';
import 'package:machuco/utils/pqrs_response_date.dart';

/// PQRS types as the catalog describes them, ready for the views.
///
/// Starts with the four default types so a screen never waits on the network;
/// [load] replaces them with the catalog (Supabase, then cache, then defaults)
/// and keeps the Spanish reason in [notice] when the fresh catalog could not
/// be read. Without a repository it keeps the defaults.
class PqrsTypeCatalog extends ChangeNotifier {
  PqrsTypeCatalog({this._repository});

  /// Catalog wired to the composed type repository.
  factory PqrsTypeCatalog.fromProvider() =>
      PqrsTypeCatalog(repository: PqrsRepositoryProvider.types);

  final PqrsTypeRepository? _repository;
  List<PqrsTypeInfo> _types = PqrsTypeInfo.defaults;
  String? _notice;
  bool _loading = false;
  bool _disposed = false;

  /// Active types sorted by `sortOrder`.
  List<PqrsTypeInfo> get types => _types;

  /// Why the catalog is not fresh, or `null`.
  String? get notice => _notice;

  bool get isLoading => _loading;

  /// Catalog entry of [type], or `null` when the catalog no longer has it.
  PqrsTypeInfo? infoOf(PqrsType type) {
    for (final info in _types) {
      if (info.type == type) return info;
    }
    return null;
  }

  /// Estimated response date of [request]: business days of its type added to
  /// the creation date. Informative only; it never changes the status.
  DateTime estimatedResponse(PqrsRequest request) => addBusinessDays(
    request.createdAt,
    infoOf(request.type)?.responseDays ?? pqrsDefaultResponseDays,
  );

  Future<void> load() async {
    final repository = _repository;
    if (repository == null) return;
    _loading = true;
    _notify();
    try {
      final result = await repository.loadTypes();
      _types = [...result.value]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _notice = result.source == PqrsConfigSource.remote
          ? null
          : result.message;
    } on Object catch (error) {
      // The contract never throws; this keeps the defaults if it ever does.
      debugPrint('PQRS: catalog ${error.runtimeType}');
    }
    _loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
