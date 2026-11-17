import 'dart:convert';

import 'package:floor/floor.dart';
import 'package:machuco/models/pqrs/pqrs_image_format.dart';

/// Cache of a row of the Supabase master `allowed_image_formats`.
/// [extensions] and [signatures] are JSON text (list of strings and list of
/// `{"offset": int, "hex": String}`).
@Entity(tableName: 'allowed_image_formats')
class AllowedImageFormatEntry {
  const AllowedImageFormatEntry({
    required this.id,
    required this.mimeType,
    required this.extensions,
    required this.signatures,
    required this.maxSizeBytes,
    required this.isActive,
  });

  factory AllowedImageFormatEntry.fromFormat(int id, PqrsImageFormat format) =>
      AllowedImageFormatEntry(
        id: id,
        mimeType: format.mimeType,
        extensions: jsonEncode(format.extensions),
        signatures: jsonEncode([
          for (final signature in format.signatures)
            {'offset': signature.offset, 'hex': signature.hex},
        ]),
        maxSizeBytes: format.maxSizeBytes,
        isActive: format.isActive ? 1 : 0,
      );

  @PrimaryKey()
  final int id;
  final String mimeType;
  final String extensions;
  final String signatures;
  final int maxSizeBytes;

  /// 1 = accepted, 0 = withdrawn.
  final int isActive;

  /// Rebuilds the domain format. A corrupt JSON column yields an empty list
  /// instead of throwing, so one bad row cannot break the whole cache.
  PqrsImageFormat toFormat() => PqrsImageFormat.fromJson({
    'mime_type': mimeType,
    'extensions': _decodeList(extensions),
    'signatures': _decodeList(signatures),
    'max_size_bytes': maxSizeBytes,
    'is_active': isActive == 1,
  });

  static List<dynamic> _decodeList(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is List ? decoded : const [];
    } on FormatException {
      return const [];
    }
  }
}
