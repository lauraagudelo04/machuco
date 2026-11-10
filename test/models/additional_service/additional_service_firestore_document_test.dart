import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/models/additional_service/additional_service_firestore_document.dart';

Map<String, dynamic> _validData() => {
  'ownerId': 'u1',
  'motelId': 'm1',
  'name': 'Jacuzzi',
  'description': 'Jacuzzi privado',
  'category': 'Bienestar',
  'price': 30000,
  'active': true,
};

void main() {
  group('AdditionalServiceFirestoreDocument.fromFirestore', () {
    test('lee todos los campos', () {
      final document = AdditionalServiceFirestoreDocument.fromFirestore(
        's1',
        _validData(),
      );

      expect(document.ownerId, 'u1');
      expect(document.service.id, 's1');
      expect(document.service.motelId, 'm1');
      expect(document.service.price, 30000);
      expect(document.service.active, isTrue);
    });

    test('rechaza precio no entero o no positivo', () {
      for (final price in <Object?>[0, -5, 10.5, '30000', null]) {
        expect(
          () => AdditionalServiceFirestoreDocument.fromFirestore('s1', {
            ..._validData(),
            'price': price,
          }),
          throwsFormatException,
        );
      }
    });

    test('rechaza campos de texto vacíos o ausentes', () {
      for (final key in [
        'ownerId',
        'motelId',
        'name',
        'description',
        'category',
      ]) {
        expect(
          () => AdditionalServiceFirestoreDocument.fromFirestore('s1', {
            ..._validData(),
            key: '',
          }),
          throwsFormatException,
        );
        expect(
          () => AdditionalServiceFirestoreDocument.fromFirestore(
            's1',
            Map.of(_validData())..remove(key),
          ),
          throwsFormatException,
        );
      }
    });

    test('rechaza un estado que no es booleano', () {
      expect(
        () => AdditionalServiceFirestoreDocument.fromFirestore('s1', {
          ..._validData(),
          'active': 'yes',
        }),
        throwsFormatException,
      );
    });
  });

  group('toFirestore', () {
    const service = AdditionalService(
      id: 's1',
      motelId: 'm1',
      name: 'Jacuzzi',
      description: 'Jacuzzi privado',
      category: 'Bienestar',
      price: 30000,
      active: false,
    );

    test('crea con exactamente los campos que permiten las reglas', () {
      final data = const AdditionalServiceFirestoreDocument(
        ownerId: 'u1',
        service: service,
      ).toFirestore();

      expect(data.keys.toSet(), {
        'ownerId',
        'motelId',
        'name',
        'description',
        'category',
        'price',
        'active',
        'updatedAt',
      });
      expect(data['updatedAt'], isA<FieldValue>());
    });

    test('la edición nunca envía ownerId ni motelId', () {
      final data = AdditionalServiceFirestoreDocument.updateData(service);

      expect(data.containsKey('ownerId'), isFalse);
      expect(data.containsKey('motelId'), isFalse);
      expect(data['active'], isFalse);
    });
  });
}
