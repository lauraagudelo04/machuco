import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:machuco/models/pqrs/pqrs_settings.dart';

/// Where a photo comes from.
enum PqrsPhotoOrigin { camera, gallery }

/// A photo already compressed by the picker, before validation.
class PqrsPickedPhoto {
  const PqrsPickedPhoto({
    required this.bytes,
    required this.fileName,
    this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;

  /// Type reported by the platform; may be `null` (the validator then falls
  /// back to the file extension).
  final String? mimeType;
}

/// Source of photos for PQRS. The abstraction lets controllers and tests work
/// without the platform plugin.
abstract interface class PqrsPhotoPicker {
  /// Picks one photo compressed with the quality and the maximum size of
  /// [settings]. Returns `null` when the user cancels.
  Future<PqrsPickedPhoto?> pick({
    required PqrsPhotoOrigin origin,
    required PqrsSettings settings,
  });
}

/// [PqrsPhotoPicker] backed by `image_picker`.
class ImagePickerPqrsPhotoPicker implements PqrsPhotoPicker {
  ImagePickerPqrsPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PqrsPickedPhoto?> pick({
    required PqrsPhotoOrigin origin,
    required PqrsSettings settings,
  }) async {
    final file = await _picker.pickImage(
      source: origin == PqrsPhotoOrigin.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: settings.imageQuality.clamp(1, 100),
      maxWidth: settings.maxWidthPx.toDouble(),
      maxHeight: settings.maxHeightPx.toDouble(),
    );
    if (file == null) return null;
    return PqrsPickedPhoto(
      bytes: await file.readAsBytes(),
      fileName: file.name,
      mimeType: file.mimeType,
    );
  }
}
