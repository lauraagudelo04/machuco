import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/pqrs/pqrs_image_format.dart';
import 'package:machuco/models/pqrs/pqrs_settings.dart';
import 'package:machuco/utils/pqrs_image_validator.dart';

Uint8List _jpeg([int length = 100]) =>
    Uint8List(length)..setAll(0, [0xFF, 0xD8, 0xFF]);

Uint8List _png() =>
    Uint8List(100)..setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

Uint8List _webp({bool withWebp = true}) {
  final bytes = Uint8List(100)..setAll(0, [0x52, 0x49, 0x46, 0x46]);
  if (withWebp) bytes.setAll(8, [0x57, 0x45, 0x42, 0x50]);
  return bytes;
}

Uint8List _gif() =>
    Uint8List(100)..setAll(0, [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);

PqrsImageError? _check(
  Uint8List bytes,
  String? mime,
  String name, {
  List<PqrsImageFormat> formats = PqrsImageFormat.defaults,
  int count = 0,
}) => PqrsImageValidator.validate(
  bytes: bytes,
  mimeType: mime,
  fileName: name,
  formats: formats,
  settings: const PqrsSettings(),
  currentCount: count,
).error;

void main() {
  test('default size limit is 921600 bytes', () {
    expect(pqrsDefaultImageMaxBytes, 921600);
    for (final format in PqrsImageFormat.defaults) {
      expect(format.maxSizeBytes, pqrsDefaultImageMaxBytes);
    }
  });

  test('valid JPEG, PNG and WebP are accepted', () {
    expect(_check(_jpeg(), 'image/jpeg', 'a.jpg'), isNull);
    expect(_check(_png(), 'image/png', 'a.png'), isNull);
    expect(_check(_webp(), 'image/webp', 'a.webp'), isNull);
  });

  test('GIF renamed to .jpg has an invalid signature', () {
    expect(_check(_gif(), null, 'a.jpg'), PqrsImageError.invalidSignature);
  });

  test('WebP without WEBP at offset 8 is rejected', () {
    expect(
      _check(_webp(withWebp: false), 'image/webp', 'a.webp'),
      PqrsImageError.invalidSignature,
    );
  });

  test('null MIME is deduced from the extension', () {
    expect(_check(_png(), null, 'photo.PNG'), isNull);
  });

  test('unknown extension is not allowed', () {
    expect(_check(_jpeg(), null, 'a.xyz'), PqrsImageError.formatNotAllowed);
  });

  test('size over the limit is rejected, the limit itself is accepted', () {
    expect(
      _check(_jpeg(pqrsDefaultImageMaxBytes + 1), 'image/jpeg', 'a.jpg'),
      PqrsImageError.tooLarge,
    );
    expect(
      _check(_jpeg(pqrsDefaultImageMaxBytes), 'image/jpeg', 'a.jpg'),
      isNull,
    );
  });

  test('fourth photo is rejected', () {
    expect(
      _check(_jpeg(), 'image/jpeg', 'a.jpg', count: 3),
      PqrsImageError.tooMany,
    );
    expect(_check(_jpeg(), 'image/jpeg', 'a.jpg', count: 2), isNull);
  });

  test('inactive format is never accepted', () {
    const formats = [
      PqrsImageFormat(
        mimeType: 'image/jpeg',
        extensions: ['jpg'],
        signatures: [PqrsImageSignature(offset: 0, hex: 'FFD8FF')],
        isActive: false,
      ),
    ];
    expect(
      _check(_jpeg(), 'image/jpeg', 'a.jpg', formats: formats),
      PqrsImageError.formatNotAllowed,
    );
    expect(
      _check(_jpeg(), null, 'a.jpg', formats: formats),
      PqrsImageError.formatNotAllowed,
    );
  });
}
