import 'package:machuco/models/pqrs/pqrs_config_result.dart';
import 'package:machuco/models/pqrs/pqrs_image_format.dart';
import 'package:machuco/models/pqrs/pqrs_settings.dart';

/// Contract for the photo validation configuration (allowed formats and
/// general settings). It does not name any provider: the Supabase
/// implementation can be replaced without touching controllers or views.
///
/// Neither method throws: when the fresh value cannot be read they fall back
/// to the cache and then to safe defaults, and say so in the result.
abstract class PqrsValidationRepository {
  /// Active image formats only; a withdrawn format is never returned.
  Future<PqrsConfigResult<List<PqrsImageFormat>>> loadImageFormats();

  Future<PqrsConfigResult<PqrsSettings>> loadSettings();
}
