import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/owner_management/owner_profile_controller.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';

UserProfile _profile({
  String fullName = 'Juan Camilo Garcia',
  String phoneNumber = '+573102781291',
}) => UserProfile(
  uid: 'uid-owner',
  fullName: fullName,
  email: 'juan.garcia@example.com',
  phoneNumber: phoneNumber,
  role: RegisteredUserRole.owner,
  accountStatus: AccountStatus.active,
  personType: PersonType.natural,
  nit: '10364044-2',
  planId: 1,
);

class _FakeUserProfileRepository implements UserProfileRepository {
  _FakeUserProfileRepository({this.profile});

  UserProfile? profile;
  bool failLoad = false;
  bool failSave = false;
  int updateCalls = 0;

  @override
  Future<void> createProfile(UserProfile profile) async {
    this.profile = profile;
  }

  @override
  Future<UserProfile?> getProfile(String uid) async {
    if (failLoad) {
      throw const UserProfileRepositoryException(
        UserProfileFailureType.network,
        'No hay conexión.',
      );
    }
    return profile;
  }

  @override
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
  }) async {
    updateCalls++;
    if (failSave) {
      throw const UserProfileRepositoryException(
        UserProfileFailureType.permissionDenied,
        'No tienes permisos para realizar esta operación.',
      );
    }
    profile = _profile(fullName: fullName, phoneNumber: phoneNumber);
  }

  @override
  Future<void> deleteProfile(String uid) async {}
}

OwnerProfileController _buildController(
  _FakeUserProfileRepository repository, {
  String? currentUserId = 'uid-owner',
}) => OwnerProfileController(
  repository: repository,
  currentUserId: () => currentUserId,
);

void main() {
  test('load trae el perfil del propietario', () async {
    final repository = _FakeUserProfileRepository(profile: _profile());
    final controller = _buildController(repository);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.profile?.fullName, 'Juan Camilo Garcia');
    expect(controller.profile?.nit, '10364044-2');
    expect(controller.profile?.personType, PersonType.natural);
  });

  test('load sin sesión avisa y no consulta', () async {
    final repository = _FakeUserProfileRepository(profile: _profile());
    final controller = _buildController(repository, currentUserId: null);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.profile, isNull);
    expect(controller.errorMessage, contains('sesión'));
  });

  test('load sin conexión conserva el aviso del repositorio', () async {
    final repository = _FakeUserProfileRepository(profile: _profile())
      ..failLoad = true;
    final controller = _buildController(repository);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.profile, isNull);
    expect(controller.errorMessage, 'No hay conexión.');
  });

  test('update guarda nombre y teléfono y recarga el perfil', () async {
    final repository = _FakeUserProfileRepository(profile: _profile());
    final controller = _buildController(repository);
    addTearDown(controller.dispose);
    await controller.load();

    final saved = await controller.update(
      fullName: 'Juan C. García',
      phoneNumber: '+573119998888',
    );

    expect(saved, isTrue);
    expect(repository.updateCalls, 1);
    expect(controller.profile?.fullName, 'Juan C. García');
    expect(controller.profile?.phoneNumber, '+573119998888');
  });

  test('update valida nombre y teléfono antes de llamar a la nube', () async {
    final repository = _FakeUserProfileRepository(profile: _profile());
    final controller = _buildController(repository);
    addTearDown(controller.dispose);

    expect(
      await controller.update(fullName: 'JC', phoneNumber: '+573001234567'),
      isFalse,
    );
    expect(controller.errorMessage, contains('nombre completo'));

    expect(
      await controller.update(fullName: 'Juan Camilo', phoneNumber: '123'),
      isFalse,
    );
    expect(controller.errorMessage, contains('teléfono'));
    expect(repository.updateCalls, 0);
  });

  test('update informa cuando la nube rechaza el cambio', () async {
    final repository = _FakeUserProfileRepository(profile: _profile())
      ..failSave = true;
    final controller = _buildController(repository);
    addTearDown(controller.dispose);
    await controller.load();

    final saved = await controller.update(
      fullName: 'Juan C. García',
      phoneNumber: '+573119998888',
    );

    expect(saved, isFalse);
    expect(controller.errorMessage, contains('permisos'));
  });
}
