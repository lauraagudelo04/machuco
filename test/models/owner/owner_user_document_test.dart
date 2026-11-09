import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/models/owner_management/owner_user_document.dart';

void main() {
  const owner = Owner(
    id: 'draft',
    fullName: 'Laura Gómez Restrepo',
    documentType: DocumentType.citizenshipCard,
    documentNumber: '1020304050',
    email: 'laura.gomez@machuco.com',
    phone: '300 123 4567',
    countryCode: '+57',
    countryName: 'Colombia',
    address: 'Calle 10 # 43-25',
    accountStatus: AccountStatus.active,
  );

  group('fromFirestore', () {
    test('lee un documento creado por el panel con todos los campos', () {
      final result = OwnerUserDocument.fromFirestore('uid-1', {
        'fullName': 'Laura Gómez Restrepo',
        'email': 'laura.gomez@machuco.com',
        'role': 'owner',
        'accountStatus': 'active',
        'phone': '300 123 4567',
        'phoneNumber': '+573001234567',
        'countryCode': '+57',
        'countryName': 'Colombia',
        'documentType': 'passport',
        'documentNumber': 'AV123456',
        'nit': 'AV123456',
        'personType': 'natural',
        'address': 'Calle 10 # 43-25',
      });

      expect(result.id, 'uid-1');
      expect(result.documentType, DocumentType.passport);
      expect(result.documentNumber, 'AV123456');
      expect(result.phone, '300 123 4567');
      expect(result.countryCode, '+57');
      expect(result.address, 'Calle 10 # 43-25');
      expect(result.isActive, isTrue);
      expect(result.accountStatus, AccountStatus.active);
      expect(result.isSynchronized, isTrue);
    });

    test('un perfil registrado solo con nit/personType se puede leer', () {
      final result = OwnerUserDocument.fromFirestore('uid-2', {
        'fullName': 'Inversiones Ejemplo S.A.S.',
        'email': 'contacto@ejemplo.com',
        'role': 'owner',
        'accountStatus': 'pending_approval',
        'phoneNumber': '+573001112233',
        'personType': 'juridica',
        'nit': '900123456-8',
      });

      expect(result.documentType, DocumentType.taxId);
      expect(result.documentNumber, '900123456-8');
      // El registro no separa el indicativo: el formulario lo divide luego.
      expect(result.phone, '+573001112233');
      expect(result.countryCode, isNull);
      expect(result.isActive, isFalse);
      expect(result.isPendingApproval, isTrue);
    });

    test('falla si falta el nombre', () {
      expect(
        () => OwnerUserDocument.fromFirestore('uid-3', {
          'email': 'x@y.com',
          'nit': '900123456-8',
          'personType': 'juridica',
        }),
        throwsFormatException,
      );
    });
  });

  group('createMap', () {
    test('escribe los campos del perfil y los legales sincronizados', () {
      final map = OwnerUserDocument.createMap(
        owner: owner,
        accountStatus: AccountStatus.pendingApproval,
        adminId: 'admin-1',
        phoneCountryCodeId: 1,
      );

      expect(map['role'], 'owner');
      expect(map['accountStatus'], 'pending_approval');
      expect(map['mustChangePassword'], isTrue);
      expect(map['createdBy'], 'admin-1');
      expect(map['phoneNumber'], '+573001234567');
      expect(map['phoneCountryCodeId'], 1);
      expect(map['documentType'], 'citizenshipCard');
      expect(map['documentNumber'], '1020304050');
      expect(map['nit'], '1020304050');
      expect(map['personType'], 'natural');
      expect(map['address'], 'Calle 10 # 43-25');
      expect(map['countryCode'], '+57');
      expect(map['countryName'], 'Colombia');
      for (final key in [
        'role',
        'accountStatus',
        'createdAt',
        'createdBy',
        'mustChangePassword',
        'fullName',
        'email',
        'phone',
        'phoneNumber',
        'documentType',
        'documentNumber',
        'nit',
        'personType',
        'address',
        'countryCode',
        'countryName',
        'updatedBy',
        'updatedAt',
      ]) {
        expect(map, contains(key));
      }
      expect(map.keys.every(OwnerUserDocument.createKeys.contains), isTrue);
    });

    test('una empresa queda como persona jurídica', () {
      final map = OwnerUserDocument.createMap(
        owner: const Owner(
          id: 'draft',
          fullName: 'Inversiones Machuco S.A.S.',
          documentType: DocumentType.taxId,
          documentNumber: '900123456-7',
          email: 'contacto@machuco.com',
          phone: '604 444 5566',
          countryCode: '+57',
        ),
        accountStatus: AccountStatus.active,
        adminId: 'admin-1',
      );

      expect(map['personType'], 'juridica');
      expect(map['nit'], '900123456-7');
    });
  });

  test('updateMap no toca correo, rol ni estado', () {
    final map = OwnerUserDocument.updateMap(owner: owner, adminId: 'admin-1');

    expect(map.keys, isNot(contains('email')));
    expect(map.keys, isNot(contains('role')));
    expect(map.keys, isNot(contains('accountStatus')));
    expect(map.keys, isNot(contains('createdAt')));
    expect(map['updatedBy'], 'admin-1');
    expect(map['fullName'], 'Laura Gómez Restrepo');
  });
}
