import 'package:flutter/foundation.dart';
import 'package:machuco/database/repository/image_format/pqrs_validation_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/models/pqrs/pqrs_image_format.dart';
import 'package:machuco/models/pqrs/pqrs_settings.dart';
import 'package:machuco/repositories/pqrs/pqrs_repository_provider.dart';
import 'package:machuco/service/media/pqrs_photo_picker.dart';
import 'package:machuco/utils/pqrs_image_validator.dart';

const pqrsFormatNotAllowedMessage = 'Formato de imagen no permitido';
const pqrsInvalidImageMessage = 'El archivo no es una imagen válida';
const _pickFailedMessage =
    'No se pudo abrir la cámara o la galería. Revisa los permisos de la app';

/// Photos the user is attaching to a form or a comment.
///
/// Loads the allowed formats and the settings lazily, the first time the
/// selector is used (Supabase, then cache, then defaults, so attaching is
/// never blocked), compresses with the picker and validates each photo before
/// it is added. The validation is only a courtesy: Firestore rules enforce
/// the same limits.
class PqrsPhotoController extends ChangeNotifier {
  PqrsPhotoController({
    required this._picker,
    required this._author,
    this._validation,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Controller wired to the composed photo source and configuration.
  factory PqrsPhotoController.fromProvider(PqrsActor author) =>
      PqrsPhotoController(
        picker: PqrsRepositoryProvider.photoPicker(),
        author: author,
        validation: PqrsRepositoryProvider.validation,
      );

  final PqrsPhotoPicker _picker;
  final PqrsActor _author;
  final PqrsValidationRepository? _validation;
  final DateTime Function() _clock;

  final List<PqrsAttachment> _photos = [];
  List<PqrsImageFormat> _formats = PqrsImageFormat.defaults;
  PqrsSettings _settings = const PqrsSettings();
  Future<void>? _loading;
  String? _error;
  bool _picking = false;
  bool _disposed = false;
  int _sequence = 0;

  List<PqrsAttachment> get photos => List.unmodifiable(_photos);

  /// Message of the last rejected photo, shown under the photo field.
  String? get error => _error;

  bool get isPicking => _picking;

  PqrsSettings get settings => _settings;

  /// Active formats as readable names ("JPEG, PNG, WEBP").
  String get acceptedFormats => _formats
      .where((format) => format.isActive)
      .map((format) => format.mimeType.split('/').last.toUpperCase())
      .join(', ');

  Future<void> _ensureConfig() => _loading ??= _loadConfig();

  Future<void> _loadConfig() async {
    final validation = _validation;
    if (validation == null) return;
    try {
      final formats = await validation.loadImageFormats();
      final settings = await validation.loadSettings();
      _formats = formats.value;
      _settings = settings.value;
    } on Object catch (error) {
      // The contract never throws; keep the defaults if it ever does.
      debugPrint('PQRS: photo config ${error.runtimeType}');
    }
  }

  /// Opens the picker, compresses and validates the photo, and adds it.
  Future<bool> add(PqrsPhotoOrigin origin) async {
    if (_picking) return false;
    _picking = true;
    _error = null;
    _notify();
    try {
      await _ensureConfig();
      if (_photos.length >= _settings.maxPhotos) {
        return _reject(_tooMany);
      }
      final picked = await _picker.pick(origin: origin, settings: _settings);
      if (picked == null) return false;

      final result = PqrsImageValidator.validate(
        bytes: picked.bytes,
        mimeType: picked.mimeType,
        fileName: picked.fileName,
        formats: _formats,
        settings: _settings,
        currentCount: _photos.length,
      );
      final format = _formatOf(picked);
      if (!result.isOk || format == null) {
        return _reject(_messageOf(result.error, format));
      }
      _photos.add(
        PqrsAttachment(
          id: 'att-${_clock().microsecondsSinceEpoch}-${_sequence++}',
          label: picked.fileName,
          author: _author,
          capturedAt: _clock(),
          seed: picked.fileName.hashCode.abs(),
          bytes: picked.bytes,
          mimeType: format.mimeType,
        ),
      );
      return true;
    } on Object catch (error) {
      debugPrint('PQRS: picker ${error.runtimeType}');
      return _reject(_pickFailedMessage);
    } finally {
      _picking = false;
      _notify();
    }
  }

  void remove(PqrsAttachment photo) {
    _photos.remove(photo);
    _error = null;
    _notify();
  }

  /// Drops every photo (a type without photos, or a sent request).
  void clear() {
    _photos.clear();
    _error = null;
    _notify();
  }

  String get _tooMany => 'Máximo ${_settings.maxPhotos} fotos';

  bool _reject(String message) {
    _error = message;
    return false;
  }

  PqrsImageFormat? _formatOf(PqrsPickedPhoto photo) {
    final mime = photo.mimeType?.trim().toLowerCase();
    final dot = photo.fileName.lastIndexOf('.');
    final extension = dot < 0 ? null : photo.fileName.substring(dot + 1);
    for (final format in _formats) {
      if (!format.isActive) continue;
      if (mime != null && mime.isNotEmpty) {
        if (format.mimeType == mime) return format;
      } else if (extension != null &&
          format.extensions.contains(extension.toLowerCase())) {
        return format;
      }
    }
    return null;
  }

  String _messageOf(PqrsImageError? error, PqrsImageFormat? format) {
    switch (error) {
      case PqrsImageError.tooMany:
        return _tooMany;
      case PqrsImageError.invalidSignature:
        return pqrsInvalidImageMessage;
      case PqrsImageError.tooLarge:
        final kb = ((format?.maxSizeBytes ?? pqrsDefaultImageMaxBytes) / 1024)
            .round();
        return 'La imagen supera el tamaño máximo ($kb KB)';
      case PqrsImageError.formatNotAllowed:
      case null:
        return pqrsFormatNotAllowedMessage;
    }
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
