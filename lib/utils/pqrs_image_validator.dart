import 'dart:typed_data';

import 'package:machuco/models/pqrs/pqrs_image_format.dart';
import 'package:machuco/models/pqrs/pqrs_settings.dart';

/// Why a photo was rejected.
enum PqrsImageError {
  /// The MIME type or extension is not an active allowed format.
  formatNotAllowed,

  /// The bytes do not start with the signatures of the declared format.
  invalidSignature,

  /// The file is larger than the format allows.
  tooLarge,

  /// The request already has the maximum number of photos.
  tooMany,
}

/// Outcome of [PqrsImageValidator.validate]: [error] is null when accepted.
class PqrsImageValidation {
  const PqrsImageValidation.ok() : error = null;
  const PqrsImageValidation.failure(PqrsImageError this.error);

  final PqrsImageError? error;

  bool get isOk => error == null;
}

/// Client-side check of a photo before it is attached.
///
/// This only improves the experience: the real limits are enforced by
/// `firestore.rules`, so it never replaces backend validation.
abstract final class PqrsImageValidator {
  static PqrsImageValidation validate({
    required Uint8List bytes,
    required String? mimeType,
    required String fileName,
    required List<PqrsImageFormat> formats,
    required PqrsSettings settings,
    required int currentCount,
  }) {
    if (currentCount >= settings.maxPhotos) {
      return const PqrsImageValidation.failure(PqrsImageError.tooMany);
    }

    final format = _resolveFormat(mimeType, fileName, formats);
    if (format == null) {
      return const PqrsImageValidation.failure(PqrsImageError.formatNotAllowed);
    }

    if (!_matchesAllSignatures(bytes, format.signatures)) {
      return const PqrsImageValidation.failure(PqrsImageError.invalidSignature);
    }

    if (bytes.length > format.maxSizeBytes) {
      return const PqrsImageValidation.failure(PqrsImageError.tooLarge);
    }

    return const PqrsImageValidation.ok();
  }

  /// Active format for the MIME type, or for the extension when it is null.
  static PqrsImageFormat? _resolveFormat(
    String? mimeType,
    String fileName,
    List<PqrsImageFormat> formats,
  ) {
    final mime = mimeType?.trim().toLowerCase();
    final hasMime = mime != null && mime.isNotEmpty;
    final extension = _extensionOf(fileName);

    for (final format in formats) {
      if (!format.isActive) continue;
      if (hasMime) {
        if (format.mimeType == mime) return format;
      } else if (extension != null && format.extensions.contains(extension)) {
        return format;
      }
    }
    return null;
  }

  static String? _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    return fileName.substring(dot + 1).toLowerCase();
  }

  static bool _matchesAllSignatures(
    Uint8List bytes,
    List<PqrsImageSignature> signatures,
  ) {
    if (signatures.isEmpty) return false;
    for (final signature in signatures) {
      final expected = signature.bytes;
      if (expected == null || signature.offset < 0) return false;
      final end = signature.offset + expected.length;
      if (end > bytes.length) return false;
      for (var i = 0; i < expected.length; i++) {
        if (bytes[signature.offset + i] != expected[i]) return false;
      }
    }
    return true;
  }
}
