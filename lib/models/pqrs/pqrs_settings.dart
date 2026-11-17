/// General PQRS photo settings (single row of `pqrs_settings`).
class PqrsSettings {
  const PqrsSettings({
    this.maxPhotos = 3,
    this.imageQuality = 60,
    this.maxWidthPx = 1280,
    this.maxHeightPx = 1280,
  });

  /// Reads the Supabase row; missing or mistyped fields keep their default.
  factory PqrsSettings.fromJson(Map<String, dynamic> json) {
    const defaults = PqrsSettings();
    int read(String key, int fallback) {
      final value = json[key];
      return value is int && value > 0 ? value : fallback;
    }

    return PqrsSettings(
      maxPhotos: read('max_photos', defaults.maxPhotos),
      imageQuality: read('image_quality', defaults.imageQuality),
      maxWidthPx: read('max_width_px', defaults.maxWidthPx),
      maxHeightPx: read('max_height_px', defaults.maxHeightPx),
    );
  }

  final int maxPhotos;

  /// Compression quality, 1 to 100.
  final int imageQuality;
  final int maxWidthPx;
  final int maxHeightPx;
}
