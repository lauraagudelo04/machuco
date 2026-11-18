import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/pqrs/pqrs_form_controller.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/controllers/pqrs/pqrs_photo_controller.dart';
import 'package:machuco/controllers/pqrs/pqrs_type_catalog.dart';
import 'package:machuco/database/repository/image_format/pqrs_validation_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/models/pqrs/pqrs_config_result.dart';
import 'package:machuco/models/pqrs/pqrs_image_format.dart';
import 'package:machuco/models/pqrs/pqrs_motel_option.dart';
import 'package:machuco/models/pqrs/pqrs_session.dart';
import 'package:machuco/models/pqrs/pqrs_settings.dart';
import 'package:machuco/models/pqrs/pqrs_type_info.dart';
import 'package:machuco/service/media/pqrs_photo_picker.dart';

import '../../fakes/in_memory_pqrs_repository.dart';

class _FakePicker implements PqrsPhotoPicker {
  PqrsPickedPhoto? next;
  int calls = 0;
  PqrsSettings? lastSettings;

  @override
  Future<PqrsPickedPhoto?> pick({
    required PqrsPhotoOrigin origin,
    required PqrsSettings settings,
  }) async {
    calls++;
    lastSettings = settings;
    return next;
  }
}

class _FakeValidation implements PqrsValidationRepository {
  _FakeValidation(this.settings);

  final PqrsSettings settings;

  @override
  Future<PqrsConfigResult<List<PqrsImageFormat>>> loadImageFormats() async =>
      const PqrsConfigResult(
        value: PqrsImageFormat.defaults,
        source: PqrsConfigSource.defaults,
      );

  @override
  Future<PqrsConfigResult<PqrsSettings>> loadSettings() async =>
      PqrsConfigResult(value: settings, source: PqrsConfigSource.remote);
}

PqrsPickedPhoto _jpeg({int size = 100, String name = 'foto.jpg'}) {
  final bytes = Uint8List(size)
    ..[0] = 0xFF
    ..[1] = 0xD8
    ..[2] = 0xFF;
  return PqrsPickedPhoto(bytes: bytes, fileName: name, mimeType: 'image/jpeg');
}

PqrsPickedPhoto _gif({String name = 'foto.gif', String? mime = 'image/gif'}) =>
    PqrsPickedPhoto(
      bytes: Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0, 0]),
      fileName: name,
      mimeType: mime,
    );

void main() {
  late _FakePicker picker;

  PqrsPhotoController build({PqrsSettings? settings}) => PqrsPhotoController(
    picker: picker,
    author: PqrsActor.client,
    validation: settings == null ? null : _FakeValidation(settings),
  );

  setUp(() => picker = _FakePicker());

  group('PqrsPhotoController', () {
    test('accepts a valid JPEG and keeps its bytes', () async {
      picker.next = _jpeg();
      final photos = build();

      expect(await photos.add(PqrsPhotoOrigin.gallery), isTrue);
      expect(photos.photos.single.hasImage, isTrue);
      expect(photos.photos.single.mimeType, 'image/jpeg');
      expect(photos.error, isNull);
    });

    test('rejects a GIF as a format not allowed', () async {
      picker.next = _gif();
      final photos = build();

      expect(await photos.add(PqrsPhotoOrigin.gallery), isFalse);
      expect(photos.error, 'Formato de imagen no permitido');
      expect(photos.photos, isEmpty);
    });

    test('rejects a renamed file whose bytes do not match', () async {
      picker.next = PqrsPickedPhoto(
        bytes: _gif().bytes,
        fileName: 'foto.jpg',
        mimeType: 'image/jpeg',
      );
      final photos = build();

      await photos.add(PqrsPhotoOrigin.gallery);
      expect(photos.error, 'El archivo no es una imagen válida');
    });

    test('rejects a photo over the size limit and names it in KB', () async {
      picker.next = _jpeg(size: pqrsDefaultImageMaxBytes + 1);
      final photos = build();

      await photos.add(PqrsPhotoOrigin.gallery);
      expect(photos.error, 'La imagen supera el tamaño máximo (900 KB)');
    });

    test('a null mime type is deduced from the extension', () async {
      picker.next = PqrsPickedPhoto(
        bytes: _jpeg().bytes,
        fileName: 'camara.jpg',
      );
      final photos = build();

      expect(await photos.add(PqrsPhotoOrigin.camera), isTrue);
      expect(photos.photos.single.mimeType, 'image/jpeg');
    });

    test('stops at max_photos without opening the picker', () async {
      final photos = build(settings: const PqrsSettings(maxPhotos: 2));
      picker.next = _jpeg();
      await photos.add(PqrsPhotoOrigin.gallery);
      await photos.add(PqrsPhotoOrigin.gallery);
      final calls = picker.calls;

      expect(await photos.add(PqrsPhotoOrigin.gallery), isFalse);
      expect(photos.error, 'Máximo 2 fotos');
      expect(picker.calls, calls);
    });

    test('compresses with the quality and size of the settings', () async {
      picker.next = _jpeg();
      final photos = build(
        settings: const PqrsSettings(imageQuality: 40, maxWidthPx: 1000),
      );

      await photos.add(PqrsPhotoOrigin.gallery);
      expect(picker.lastSettings?.imageQuality, 40);
      expect(picker.lastSettings?.maxWidthPx, 1000);
    });

    test('a cancelled pick changes nothing', () async {
      final photos = build();

      expect(await photos.add(PqrsPhotoOrigin.gallery), isFalse);
      expect(photos.photos, isEmpty);
      expect(photos.error, isNull);
    });
  });

  group('PqrsFormController', () {
    late InMemoryPqrsRepository repository;
    late PqrsController requests;
    late PqrsPhotoController photos;
    late PqrsFormController form;

    const noPhotos = PqrsTypeInfo(
      type: PqrsType.sugerencia,
      name: 'Sugerencia',
      description: 'Sin fotos',
      allowsPhotos: false,
      sortOrder: 4,
    );

    setUp(() {
      repository = InMemoryPqrsRepository();
      requests = PqrsController(
        repository: repository,
        session: const PqrsSession(
          uid: 'client-1',
          role: PqrsActor.client,
          name: 'Ana',
        ),
        clock: () => DateTime(2026, 11, 17),
      );
      photos = build();
      form = PqrsFormController(
        requests: requests,
        photos: photos,
        catalog: PqrsTypeCatalog(),
        motelLoader: () async => const [
          PqrsMotelOption(id: 'm1', name: 'Motel Luna', ownerId: 'owner-1'),
        ],
      );
    });

    test(
      'shows a field error for each empty field and sends nothing',
      () async {
        await form.load();

        expect(await form.submit(subject: '', description: ''), isFalse);
        expect(form.errors.motel, isNotNull);
        expect(form.errors.type, isNotNull);
        expect(form.errors.subject, isNotNull);
        expect(form.errors.description, isNotNull);
        expect(repository.createCalls, 0);
      },
    );

    test('a type without photos hides the selector and drops photos', () async {
      picker.next = _jpeg();
      await form.load();
      form.selectType(PqrsTypeInfo.defaults.first);
      expect(form.showsPhotos, isTrue);
      await photos.add(PqrsPhotoOrigin.gallery);
      expect(photos.photos, hasLength(1));

      form.selectType(noPhotos);

      expect(form.showsPhotos, isFalse);
      expect(photos.photos, isEmpty);
    });

    test('sends only the type code and clears the form', () async {
      await form.load();
      form.selectMotel(form.motels.first);
      form.selectType(PqrsTypeInfo.defaults[1]);

      final sent = await form.submit(
        subject: 'Demora',
        description: 'Esperé mucho tiempo en recepción.',
      );

      expect(sent, isTrue);
      expect(repository.requests.single.type, PqrsType.queja);
      expect(repository.requests.single.ownerId, 'owner-1');
      expect(form.selectedType, isNull);
    });
  });
}
