import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';

void main() {
  group('UserProfile.fromFirestore', () {
    test('lee todos los campos', () {
      final profile = UserProfile.fromFirestore('u1', {
        'fullName': 'Ana Perez',
        'email': 'ana@example.com',
        'phoneNumber': '+573001234567',
        'role': 'owner',
        'accountStatus': 'pending_approval',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 27)),
      });

      expect(profile.uid, 'u1');
      expect(profile.role, RegisteredUserRole.owner);
      expect(profile.accountStatus, AccountStatus.pendingApproval);
      expect(profile.createdAt, DateTime.utc(2026, 10, 27));
    });

    test('tolera datos faltantes con rol cliente y estado nulo', () {
      final profile = UserProfile.fromFirestore('u2', const {});

      expect(profile.fullName, '');
      expect(profile.role, RegisteredUserRole.client);
      expect(profile.accountStatus, isNull);
      expect(profile.createdAt, isNull);
    });

    test('un estado desconocido no se interpreta como activo', () {
      final profile = UserProfile.fromFirestore('u3', {'accountStatus': 'vip'});

      expect(profile.accountStatus, isNull);
    });
  });

  test('toFirestore usa valores de almacenamiento y timestamp de servidor', () {
    const profile = UserProfile(
      uid: 'u1',
      fullName: 'Ana Perez',
      email: 'ana@example.com',
      phoneNumber: '+573001234567',
      role: RegisteredUserRole.owner,
      accountStatus: AccountStatus.pendingApproval,
    );

    final data = profile.toFirestore();

    expect(data['role'], 'owner');
    expect(data['accountStatus'], 'pending_approval');
    expect(data['createdAt'], isA<FieldValue>());
    expect(data.containsKey('uid'), isFalse);
  });

  group('reglas de registro publico', () {
    test('solo cliente y propietario se pueden registrar', () {
      expect(isPublicRegistrationRole(RegisteredUserRole.client), isTrue);
      expect(isPublicRegistrationRole(RegisteredUserRole.owner), isTrue);
      expect(isPublicRegistrationRole(RegisteredUserRole.admin), isFalse);
    });

    test('estado inicial por rol', () {
      expect(
        initialAccountStatusFor(RegisteredUserRole.client),
        AccountStatus.active,
      );
      expect(
        initialAccountStatusFor(RegisteredUserRole.owner),
        AccountStatus.pendingApproval,
      );
    });

    test('los valores de almacenamiento hacen ida y vuelta', () {
      for (final status in AccountStatus.values) {
        expect(accountStatusFromStorage(status.storageValue), status);
      }
      expect(accountStatusFromStorage(null), isNull);
    });
  });

  test('el contrato admite un fake sin red', () async {
    final repository = _FakeUserProfileRepository();
    const profile = UserProfile(
      uid: 'u1',
      fullName: 'Ana',
      email: 'ana@example.com',
      phoneNumber: '+573001234567',
      role: RegisteredUserRole.client,
      accountStatus: AccountStatus.active,
    );

    expect(await repository.getProfile('u1'), isNull);
    await repository.createProfile(profile);
    expect((await repository.getProfile('u1'))?.email, 'ana@example.com');
  });
}

final class _FakeUserProfileRepository implements UserProfileRepository {
  final _profiles = <String, UserProfile>{};

  @override
  Future<void> createProfile(UserProfile profile) async {
    _profiles[profile.uid] = profile;
  }

  @override
  Future<UserProfile?> getProfile(String uid) async => _profiles[uid];
}
