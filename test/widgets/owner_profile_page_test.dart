import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/owner_management/owner_profile_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/views/motel/owner_view/owner_profile_page.dart';

class _FakeUserProfileRepository implements UserProfileRepository {
  _FakeUserProfileRepository(this.profile);

  final UserProfile profile;

  @override
  Future<UserProfile?> getProfile(String uid) async => profile;

  @override
  Future<void> createProfile(UserProfile profile) async {}

  @override
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
  }) async {}

  @override
  Future<void> clearMustChangePassword(String uid) async {}

  @override
  Future<void> deleteProfile(String uid) async {}
}

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  testWidgets('muestra los datos reales del propietario', (tester) async {
    final controller = OwnerProfileController(
      repository: _FakeUserProfileRepository(
        const UserProfile(
          uid: 'uid-owner',
          fullName: 'Juan Camilo Garcia',
          email: 'juan.garcia@example.com',
          phoneNumber: '+573102781291',
          role: RegisteredUserRole.owner,
          accountStatus: AccountStatus.active,
          personType: PersonType.natural,
          nit: '10364044-2',
          planId: 1,
        ),
      ),
      currentUserId: () => 'uid-owner',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(OwnerProfilePage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juan Camilo Garcia'), findsWidgets);
    expect(find.text('juan.garcia@example.com'), findsWidgets);
    expect(find.text('+573102781291'), findsOneWidget);
    expect(find.text('10364044-2'), findsOneWidget);
    expect(find.text('Persona natural'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
  });
}
