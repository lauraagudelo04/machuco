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
    // Firestore rules accept at most this many photos per entry.
    const hardMax = 10;
    int read(String key, int fallback) {
      final value = json[key];
      return value is int && value > 0 ? value : fallback;
    }

    return PqrsSettings(
      maxPhotos: read('max_photos', defaults.maxPhotos).clamp(1, hardMax),
      imageQuality: read('image_quality', defaults.imageQuality),
      maxWidthPx: read('max_width_px', defaults.maxWidthPx),
      maxHeightPx: read('max_height_px', defaults.maxHeightPx),
    );
  }

  /// Same keys as the Supabase row; used to cache it in `shared_preferences`.
  Map<String, dynamic> toJson() => {
    'max_photos': maxPhotos,
    'image_quality': imageQuality,
    'max_width_px': maxWidthPx,
    'max_height_px': maxHeightPx,
  };

  final int maxPhotos;

  /// Compression quality, 1 to 100.
  final int imageQuality;
  final int maxWidthPx;
  final int maxHeightPx;
}
