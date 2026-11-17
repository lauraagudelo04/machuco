import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/controllers/pqrs/pqrs_photo_controller.dart';
import 'package:machuco/controllers/pqrs/pqrs_type_catalog.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/models/pqrs/pqrs_motel_option.dart';
import 'package:machuco/models/pqrs/pqrs_type_info.dart';
import 'package:machuco/repositories/pqrs/pqrs_repository_provider.dart';
import 'package:machuco/utils/pqrs_validator.dart';

/// Validation messages of the new-request form, one per field.
class PqrsFormErrors {
  const PqrsFormErrors({this.motel, this.type, this.subject, this.description});

  final String? motel;
  final String? type;
  final String? subject;
  final String? description;

  bool get isEmpty =>
      motel == null && type == null && subject == null && description == null;
}

/// State of the "Nueva solicitud" form of the client.
///
/// The motel list arrives through [motelLoader] and the types through
/// [PqrsTypeCatalog], so the view never reaches a service. Only the type
/// `code` ends up stored (the enum name); the visible name and description
/// are display data. Sending delegates to [PqrsController.createRequest].
class PqrsFormController extends ChangeNotifier {
  PqrsFormController({
    required this._requests,
    required this._photos,
    required this._catalog,
    required this._motelLoader,
  });

  /// Form wired to the composed repositories; it owns (and disposes) its
  /// photo controller and type catalog.
  factory PqrsFormController.fromProvider(PqrsController requests) {
    return PqrsFormController(
      requests: requests,
      photos: PqrsPhotoController(
        picker: PqrsRepositoryProvider.photoPicker(),
        author: PqrsActor.client,
        validation: PqrsRepositoryProvider.validation,
      ),
      catalog: PqrsTypeCatalog(repository: PqrsRepositoryProvider.types),
      motelLoader: PqrsRepositoryProvider.motelOptions,
    ).._ownsChildren = true;
  }

  bool _ownsChildren = false;

  final PqrsController _requests;
  final PqrsPhotoController _photos;
  final PqrsTypeCatalog _catalog;
  final Future<List<PqrsMotelOption>> Function() _motelLoader;

  List<PqrsMotelOption> _motels = const [];
  PqrsMotelOption? _motel;
  PqrsTypeInfo? _type;
  PqrsFormErrors _errors = const PqrsFormErrors();
  bool _loadingMotels = false;
  bool _motelsFailed = false;
  bool _disposed = false;

  PqrsPhotoController get photos => _photos;
  PqrsTypeCatalog get catalog => _catalog;
  List<PqrsMotelOption> get motels => _motels;
  PqrsMotelOption? get selectedMotel => _motel;
  PqrsTypeInfo? get selectedType => _type;
  PqrsFormErrors get errors => _errors;
  bool get isLoadingMotels => _loadingMotels;

  /// True when the motel list could not be read (the form offers a retry).
  bool get motelsFailed => _motelsFailed;

  /// The photo selector is shown only for a type that allows photos.
  bool get showsPhotos => _type?.allowsPhotos ?? false;

  Future<void> load() async {
    await Future.wait([_catalog.load(), loadMotels()]);
  }

  Future<void> loadMotels() async {
    _loadingMotels = true;
    _motelsFailed = false;
    _notify();
    try {
      _motels = await _motelLoader();
      // Keep the choice only while the motel is still offered.
      if (_motel != null && !_motels.any((m) => m.id == _motel!.id)) {
        _motel = null;
      }
    } on Object catch (error) {
      debugPrint('PQRS: motels ${error.runtimeType}');
      _motelsFailed = true;
    }
    _loadingMotels = false;
    _notify();
  }

  void selectMotel(PqrsMotelOption? motel) {
    _motel = motel;
    _errors = PqrsFormErrors(
      type: _errors.type,
      subject: _errors.subject,
      description: _errors.description,
    );
    _notify();
  }

  /// Chooses a type. A type without photos discards the photos already
  /// picked for the previous one.
  void selectType(PqrsTypeInfo info) {
    _type = info;
    if (!info.allowsPhotos) _photos.clear();
    _errors = PqrsFormErrors(
      motel: _errors.motel,
      subject: _errors.subject,
      description: _errors.description,
    );
    _notify();
  }

  /// Validates every field. Returns true when the form can be sent.
  bool validate({required String subject, required String description}) {
    _errors = PqrsFormErrors(
      motel: _motel == null ? PqrsValidator.motelRequiredMessage : null,
      type: _type == null ? PqrsValidator.typeRequiredMessage : null,
      subject: PqrsValidator.subject(subject),
      description: PqrsValidator.description(description),
    );
    _notify();
    return _errors.isEmpty;
  }

  /// Validates and sends. On success the choices and photos are cleared and
  /// the view empties the text fields; on failure everything is kept so the
  /// user can retry, and the reason is in [PqrsController.error].
  Future<bool> submit({
    required String subject,
    required String description,
  }) async {
    if (!validate(subject: subject, description: description)) return false;
    final motel = _motel!;
    final sent = await _requests.createRequest(
      motelId: motel.id,
      motelName: motel.name,
      ownerId: motel.ownerId,
      type: _type!.type,
      subject: subject,
      description: description,
      attachments: showsPhotos ? _photos.photos : const [],
    );
    if (sent) {
      _motel = null;
      _type = null;
      _errors = const PqrsFormErrors();
      _photos.clear();
      _notify();
    }
    return sent;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsChildren) {
      _photos.dispose();
      _catalog.dispose();
    }
    super.dispose();
  }
}
