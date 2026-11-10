import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/owner_approval_request.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';
import 'package:machuco/models/auth/user_profile.dart';

void main() {
  group('PersonType', () {
    test('valor de metadata y lectura segura', () {
      expect(PersonType.natural.metadataValue, 'natural');
      expect(PersonType.juridica.metadataValue, 'juridica');
      expect(personTypeFromMetadata(' Juridica '), PersonType.juridica);
      expect(personTypeFromMetadata('natural'), PersonType.natural);
      expect(personTypeFromMetadata('otro'), isNull);
      expect(personTypeFromMetadata(null), isNull);
    });
  });

  group('RegistrationData', () {
    test('cliente lleva fecha de nacimiento y ningún dato de propietario', () {
      final data = RegistrationData.client(
        firstNames: 'Ana',
        lastNames: 'Pérez',
        phoneCountryCodeId: 1,
        phoneNumber: '3001234567',
        email: 'ana@example.com',
        password: 'secreto123',
        birthDate: DateTime(1990, 5, 20),
      );
      expect(data.role, RegisteredUserRole.client);
      expect(data.birthDate, DateTime(1990, 5, 20));
      expect(data.nit, isNull);
      expect(data.personType, isNull);
      expect(data.planId, isNull);
      expect(data.fullName, 'Ana Pérez');
    });

    test('propietario natural descarta la razón social', () {
      final data = RegistrationData.owner(
        firstNames: 'Luz',
        lastNames: 'Mora',
        phoneCountryCodeId: 1,
        phoneNumber: '3001234567',
        email: 'luz@example.com',
        password: 'secreto123',
        personType: PersonType.natural,
        nit: '1020304050-8',
        companyName: 'X',
        planId: 3,
      );
      expect(data.role, RegisteredUserRole.owner);
      expect(data.companyName, isNull);
      expect(data.birthDate, isNull);
      expect(data.planId, 3);
    });

    test('toString no expone la contraseña', () {
      final data = RegistrationData.client(
        firstNames: 'Ana',
        lastNames: 'Pérez',
        phoneCountryCodeId: 1,
        phoneNumber: '3001234567',
        email: 'ana@example.com',
        password: 'secreto123',
        birthDate: DateTime(1990, 5, 20),
      );
      expect(data.toString(), isNot(contains('secreto123')));
    });
  });

  group('UserProfile ampliado', () {
    test('un perfil antiguo sin los campos nuevos sigue cargando', () {
      final profile = UserProfile.fromFirestore('u1', {
        'fullName': 'Ana Pérez',
        'email': 'ana@example.com',
        'phoneNumber': '+573001234567',
        'role': 'client',
        'accountStatus': 'active',
      });
      expect(profile.firstNames, isNull);
      expect(profile.birthDate, isNull);
      expect(profile.personType, isNull);
      expect(profile.planId, isNull);
      expect(profile.rejectionReason, isNull);
      expect(profile.accountStatus, AccountStatus.active);
    });

    test('lee los campos nuevos y tolera tipos numéricos', () {
      final profile = UserProfile.fromFirestore('u2', {
        'fullName': 'Luz Mora',
        'email': 'luz@example.com',
        'phoneNumber': '+573001234567',
        'role': 'owner',
        'accountStatus': 'rejected',
        'firstNames': 'Luz',
        'lastNames': 'Mora',
        'phoneCountryCodeId': 1.0,
        'personType': 'juridica',
        'nit': '900123456-8',
        'companyName': 'Moteles SAS',
        'planId': '2',
        'rejectionReason': 'NIT no coincide',
        'birthDate': Timestamp.fromDate(DateTime.utc(1990, 5, 20)),
      });
      expect(profile.phoneCountryCodeId, 1);
      expect(profile.planId, 2);
      expect(profile.personType, PersonType.juridica);
      expect(profile.rejectionReason, 'NIT no coincide');
      expect(profile.birthDate, DateTime.utc(1990, 5, 20));
    });

    test('toFirestore omite los opcionales nulos y fija birthDate en UTC', () {
      const legacy = UserProfile(
        uid: 'u',
        fullName: 'Ana Pérez',
        email: 'ana@example.com',
        phoneNumber: '+573001234567',
        role: RegisteredUserRole.client,
        accountStatus: AccountStatus.active,
      );
      expect(legacy.toFirestore().keys.toSet(), {
        'fullName',
        'email',
        'phoneNumber',
        'role',
        'accountStatus',
        'createdAt',
      });

      final client = UserProfile(
        uid: 'u',
        fullName: 'Ana Pérez',
        email: 'ana@example.com',
        phoneNumber: '+573001234567',
        role: RegisteredUserRole.client,
        accountStatus: AccountStatus.active,
        firstNames: 'Ana',
        lastNames: 'Pérez',
        phoneCountryCodeId: 1,
        birthDate: DateTime(1990, 5, 20, 23, 30),
      );
      final map = client.toFirestore();
      expect(map['birthDate'], Timestamp.fromDate(DateTime.utc(1990, 5, 20)));
      expect(map.containsKey('nit'), isFalse);
      expect(map.containsKey('rejectionReason'), isFalse);
    });

    test('el propietario escribe tipo, NIT, razón social y plan', () {
      const owner = UserProfile(
        uid: 'u',
        fullName: 'Luz Mora',
        email: 'luz@example.com',
        phoneNumber: '+573001234567',
        role: RegisteredUserRole.owner,
        accountStatus: AccountStatus.pendingApproval,
        personType: PersonType.juridica,
        nit: '900123456-8',
        companyName: 'Moteles SAS',
        planId: 2,
      );
      final map = owner.toFirestore();
      expect(map['personType'], 'juridica');
      expect(map['nit'], '900123456-8');
      expect(map['companyName'], 'Moteles SAS');
      expect(map['planId'], 2);
      expect(map['accountStatus'], 'pending_approval');
      expect(map.containsKey('birthDate'), isFalse);
    });
  });

  group('OwnerApplication', () {
    test('se construye desde un perfil con nombres separados', () {
      const profile = UserProfile(
        uid: 'o1',
        fullName: 'Luz Mora',
        email: 'luz@example.com',
        phoneNumber: '+573001234567',
        role: RegisteredUserRole.owner,
        accountStatus: AccountStatus.pendingApproval,
        firstNames: 'Luz',
        lastNames: 'Mora',
        personType: PersonType.natural,
        nit: '1020304050-8',
        planId: 1,
      );
      final application = OwnerApplication.fromProfile(profile);
      expect(application.uid, 'o1');
      expect(application.fullName, 'Luz Mora');
      expect(application.nit, '1020304050-8');
      expect(application.personType, PersonType.natural);
    });

    test('tolera un perfil antiguo que solo tiene fullName', () {
      const profile = UserProfile(
        uid: 'o2',
        fullName: 'Pedro Gil',
        email: 'pedro@example.com',
        phoneNumber: '+573009998877',
        role: RegisteredUserRole.owner,
        accountStatus: AccountStatus.pendingApproval,
      );
      final application = OwnerApplication.fromProfile(profile);
      expect(application.fullName, 'Pedro Gil');
      expect(application.personType, isNull);
      expect(application.nit, isNull);
    });
  });

  group('SubscriptionPlanOption', () {
    test('lee id numérico o textual y descarta filas inválidas', () {
      expect(
        SubscriptionPlanOption.tryFromJson({'id': 1, 'name': ' Básico '}),
        const SubscriptionPlanOption(id: 1, name: 'Básico'),
      );
      expect(
        SubscriptionPlanOption.tryFromJson({'id': '2', 'name': 'Premium'}),
        const SubscriptionPlanOption(id: 2, name: 'Premium'),
      );
      expect(
        SubscriptionPlanOption.tryFromJson({'id': 'x', 'name': 'A'}),
        isNull,
      );
      expect(
        SubscriptionPlanOption.tryFromJson({'id': 3, 'name': ' '}),
        isNull,
      );
      expect(SubscriptionPlanOption.tryFromJson({'name': 'A'}), isNull);
    });
  });
}
