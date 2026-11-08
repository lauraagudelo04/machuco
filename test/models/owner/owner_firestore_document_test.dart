import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/models/owner_management/owner_firestore_document.dart';

void main() {
  const owner = Owner(
    id: 'owner-1',
    fullName: 'Laura Gómez Restrepo',
    documentType: DocumentType.citizenshipCard,
    documentNumber: '1020304050',
    email: 'laura.gomez@machuco.com',
    phone: '300 123 4567',
    countryCode: '+57',
    countryName: 'Colombia',
    address: 'Calle 10 # 43-25',
    isActive: true,
  );

  test('convierte un propietario a Firestore con su auditoría', () {
    final data = OwnerFirestoreDocument(
      owner: owner,
      updatedBy: 'admin-uid',
    ).toFirestore();

    expect(data['fullName'], 'Laura Gómez Restrepo');
    expect(data['documentType'], 'citizenshipCard');
    expect(data['documentNumber'], '1020304050');
    expect(data['email'], 'laura.gomez@machuco.com');
    expect(data['phone'], '300 123 4567');
    expect(data['countryCode'], '+57');
    expect(data['countryName'], 'Colombia');
    expect(data['address'], 'Calle 10 # 43-25');
    expect(data['isActive'], isTrue);
    expect(data['updatedBy'], 'admin-uid');
    expect(data['updatedAt'], isA<FieldValue>());
  });

  test('reconstruye un propietario tolerando opcionales ausentes', () {
    final data =
        OwnerFirestoreDocument(
            owner: owner,
            updatedBy: 'admin-uid',
          ).toFirestore()
          ..remove('updatedAt')
          ..remove('countryCode')
          ..remove('countryName')
          ..remove('address');

    final decoded = OwnerFirestoreDocument.fromFirestore('owner-1', data);

    expect(decoded.owner.id, 'owner-1');
    expect(decoded.owner.documentType, DocumentType.citizenshipCard);
    expect(decoded.owner.countryCode, isNull);
    expect(decoded.owner.countryName, isNull);
    expect(decoded.owner.address, isNull);
    expect(decoded.owner.isSynchronized, isTrue);
    expect(decoded.updatedBy, 'admin-uid');
  });

  test('rechaza documentos remotos inválidos', () {
    final data = OwnerFirestoreDocument(
      owner: owner,
      updatedBy: 'admin-uid',
    ).toFirestore()..remove('updatedAt');

    expect(
      () => OwnerFirestoreDocument.fromFirestore(
        'owner-1',
        Map<String, dynamic>.of(data)..['documentType'] = 'ZZ',
      ),
      throwsFormatException,
    );
    expect(
      () => OwnerFirestoreDocument.fromFirestore(
        'owner-1',
        Map<String, dynamic>.of(data)..['fullName'] = ' ',
      ),
      throwsFormatException,
    );
    expect(
      () => OwnerFirestoreDocument.fromFirestore(
        'owner-1',
        Map<String, dynamic>.of(data)..['isActive'] = 'si',
      ),
      throwsFormatException,
    );
  });
}
