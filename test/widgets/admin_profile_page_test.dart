import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/user_profile_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/views/admin_access/admin_profile_page.dart';

class _FakeProfiles implements UserProfileRepository {
  _FakeProfiles(this.profile);

  UserProfile profile;

  @override
  Future<UserProfile?> getProfile(String uid) async => profile;

  @override
  Future<void> createProfile(UserProfile profile) async {}

  @override
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
  }) async {
    profile = _profile(
      fullName: fullName,
      phoneNumber: phoneNumber,
      mustChangePassword: profile.mustChangePassword,
    );
  }

  @override
  Future<void> clearMustChangePassword(String uid) async {
    profile = _profile(
      fullName: profile.fullName,
      phoneNumber: profile.phoneNumber,
      mustChangePassword: false,
    );
  }

  @override
  Future<void> deleteProfile(String uid) async {}
}

UserProfile _profile({
  String fullName = 'Admin Uno',
  String phoneNumber = '+573009998877',
  bool mustChangePassword = false,
}) => UserProfile(
  uid: 'uid-admin',
  fullName: fullName,
  email: 'admin@machuco.com',
  phoneNumber: phoneNumber,
  role: RegisteredUserRole.admin,
  accountStatus: AccountStatus.active,
  mustChangePassword: mustChangePassword,
);

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

UserProfileController _controller(UserProfile profile) => UserProfileController(
  repository: _FakeProfiles(profile),
  currentUserId: () => 'uid-admin',
);

void main() {
  testWidgets('muestra los datos del administrador y su rol', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _controller(_profile());
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(AdminProfilePage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('Admin Uno'), findsWidgets);
    expect(find.text('admin@machuco.com'), findsWidgets);
    expect(find.text('+573009998877'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
    expect(find.text('Editar perfil'), findsOneWidget);
    expect(find.text('Cambiar contraseña'), findsOneWidget);
  });

  testWidgets('con contraseña temporal avisa y deshabilita la edición', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _controller(_profile(mustChangePassword: true));
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(AdminProfilePage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.textContaining('contraseña temporal'), findsOneWidget);
    final editButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Editar perfil'),
    );
    expect(editButton.onPressed, isNull);
  });
}
