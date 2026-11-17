import 'package:machuco/models/pqrs/pqrs_config_result.dart';
import 'package:machuco/models/pqrs/pqrs_type_info.dart';

/// Contract for the PQRS type catalog. It does not name any provider.
///
/// [loadTypes] never throws: when the fresh catalog cannot be read it falls
/// back to the cache and then to the four default types, and says so in the
/// result.
abstract class PqrsTypeRepository {
  /// Active types sorted by `sortOrder`. Unknown codes are never returned.
  Future<PqrsConfigResult<List<PqrsTypeInfo>>> loadTypes();
}
