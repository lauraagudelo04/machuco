import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/user_profile_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/password_change_service.dart';
import 'package:machuco/views/auth/change_password_page.dart';

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
  }) async {}

  @override
  Future<void> clearMustChangePassword(String uid) async {
    profile = UserProfile(
      uid: profile.uid,
      fullName: profile.fullName,
      email: profile.email,
      phoneNumber: profile.phoneNumber,
      role: profile.role,
      accountStatus: profile.accountStatus,
      mustChangePassword: false,
    );
  }

  @override
  Future<void> deleteProfile(String uid) async {}
}

class _FailingPasswordService implements PasswordChangeService {
  _FailingPasswordService(this.failure);

  final AuthFailure failure;

  @override
  Future<void> changePassword({required String newPassword}) async {
    throw failure;
  }
}

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

UserProfile _profile({bool mustChangePassword = true}) => UserProfile(
  uid: 'uid-owner',
  fullName: 'Juan Camilo Garcia',
  email: 'juan.garcia@example.com',
  phoneNumber: '+573102781291',
  role: RegisteredUserRole.owner,
  accountStatus: AccountStatus.active,
  mustChangePassword: mustChangePassword,
);

UserProfileController _controller(
  UserProfile profile, {
  PasswordChangeService? passwords,
}) {
  final controller = UserProfileController(
    repository: _FakeProfiles(profile),
    passwordChangeService: passwords,
    currentUserId: () => 'uid-owner',
  );
  controller.load();
  return controller;
}

void main() {
  testWidgets('avisa cuando la cuenta usa contraseña temporal', (
    tester,
  ) async {
    final controller = _controller(_profile());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(ChangePasswordPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('contraseña temporal'), findsOneWidget);
  });

  testWidgets('exige que la confirmación coincida', (tester) async {
    final controller = _controller(_profile(mustChangePassword: false));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(ChangePasswordPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nueva contraseña'),
      'claveSegura123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar contraseña'),
      'otraClave123',
    );
    await tester.tap(find.widgetWithText(AppButton, 'Guardar contraseña'));
    await tester.pumpAndSettle();

    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
  });

  testWidgets('muestra el error de Firebase al cambiar la contraseña', (
    tester,
  ) async {
    final controller = _controller(
      _profile(mustChangePassword: false),
      passwords: _FailingPasswordService(
        const AuthFailure(
          AuthFailureType.requiresRecentLogin,
          'Por seguridad, inicia sesión de nuevo para cambiar tu contraseña.',
        ),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(ChangePasswordPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nueva contraseña'),
      'claveSegura123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar contraseña'),
      'claveSegura123',
    );
    await tester.tap(find.widgetWithText(AppButton, 'Guardar contraseña'));
    await tester.pumpAndSettle();

    expect(find.textContaining('inicia sesión de nuevo'), findsOneWidget);
  });
}
