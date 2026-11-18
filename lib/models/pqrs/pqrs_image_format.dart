/// Largest photo accepted by default, in bytes (900 KB). It must match the
/// `max_size_bytes` limit in Supabase and the photo limit in `firestore.rules`.
const pqrsDefaultImageMaxBytes = 921600;

/// A magic-byte signature: [hex] must appear at byte [offset] of the file.
class PqrsImageSignature {
  const PqrsImageSignature({required this.offset, required this.hex});

  factory PqrsImageSignature.fromJson(Map<String, dynamic> json) {
    final offset = json['offset'];
    final hex = json['hex'];
    return PqrsImageSignature(
      offset: offset is int ? offset : 0,
      hex: hex is String ? hex : '',
    );
  }

  final int offset;
  final String hex;

  /// Decoded [hex], or null when it is empty or not valid hexadecimal.
  List<int>? get bytes {
    final clean = hex.replaceAll(RegExp(r'\s'), '');
    if (clean.isEmpty || clean.length.isOdd) return null;
    final result = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      final value = int.tryParse(clean.substring(i, i + 2), radix: 16);
      if (value == null) return null;
      result.add(value);
    }
    return result;
  }
}

/// An image format the PQRS photos may use (row of `allowed_image_formats`).
class PqrsImageFormat {
  const PqrsImageFormat({
    required this.mimeType,
    required this.extensions,
    required this.signatures,
    this.maxSizeBytes = pqrsDefaultImageMaxBytes,
    this.isActive = true,
  });

  factory PqrsImageFormat.fromJson(Map<String, dynamic> json) {
    final extensions = json['extensions'];
    final signatures = json['signatures'];
    final maxSize = json['max_size_bytes'];
    final active = json['is_active'];
    return PqrsImageFormat(
      mimeType: (json['mime_type'] as String? ?? '').toLowerCase(),
      extensions: [
        if (extensions is List)
          for (final item in extensions)
            if (item is String) item.toLowerCase(),
      ],
      signatures: [
        if (signatures is List)
          for (final item in signatures)
            if (item is Map<String, dynamic>) PqrsImageSignature.fromJson(item),
      ],
      maxSizeBytes: maxSize is int ? maxSize : pqrsDefaultImageMaxBytes,
      isActive: active is bool ? active : true,
    );
  }

  final String mimeType;

  /// Extensions without the dot, lowercase.
  final List<String> extensions;

  /// A file must match ALL of them.
  final List<PqrsImageSignature> signatures;
  final int maxSizeBytes;
  final bool isActive;

  /// Formats used when the catalog has not been loaded: JPEG, PNG and WebP.
  static const List<PqrsImageFormat> defaults = [
    PqrsImageFormat(
      mimeType: 'image/jpeg',
      extensions: ['jpg', 'jpeg'],
      signatures: [PqrsImageSignature(offset: 0, hex: 'FFD8FF')],
    ),
    PqrsImageFormat(
      mimeType: 'image/png',
      extensions: ['png'],
      signatures: [PqrsImageSignature(offset: 0, hex: '89504E470D0A1A0A')],
    ),
    PqrsImageFormat(
      mimeType: 'image/webp',
      extensions: ['webp'],
      signatures: [
        PqrsImageSignature(offset: 0, hex: '52494646'),
        PqrsImageSignature(offset: 8, hex: '57454250'),
      ],
    ),
  ];
}
