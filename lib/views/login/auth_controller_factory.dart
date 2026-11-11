import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/database/repository/auth/auth_catalog_repository.dart';
import 'package:machuco/database/repository/auth/auth_user_profile_repository.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/firebase_auth_service.dart';
import 'package:machuco/service/auth/phone_verification_service.dart';

/// Construye el [LoginController] de producción. Lo comparten el login y las
/// pantallas de autenticación que se abren por ruta (cuenta en revisión).
LoginController buildLoginController({AuthService? authService}) {
  final preferences = AuthPreferences();
  return LoginController(
    authService: authService ?? FirebaseAuthService(),
    // Con un servicio inyectado (pruebas) no se toca Firebase ni se pide SMS.
    phoneVerificationService: authService == null
        ? FirebasePhoneVerificationService()
        : null,
    preferences: preferences,
    catalogRepository: AuthCatalogRepository.fromEnvironment(
      preferences: preferences,
    ),
    profileCache: FloorAuthUserProfileRepository(),
  );
}
