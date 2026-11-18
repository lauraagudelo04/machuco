/// Rutas del módulo de autenticación.
///
/// Constantes temporales: `lib/routes/routes.dart` pertenece al frontend, que
/// las referenciará desde `AppRoutes` (mismos valores) y registrará las
/// pantallas. Los controllers solo devuelven estas cadenas.
abstract final class AuthRoutes {
  static const accountReview = '/auth/account-review';

  /// "Completar perfil" tras ingresar con Google o GitHub sin `users/{uid}`.
  static const completeProfile = '/auth/complete-profile';
  static const adminOwnerApprovals = '/auth/admin/owner-approvals';
  static const adminOwnerApprovalDetail = '/auth/admin/owner-approvals/detail';
  static const adminAdministrators = '/auth/admin/administrators';
  static const adminProfile = '/auth/admin/profile';
  static const adminCreateAdministrator = '/auth/admin/administrators/new';
  static const adminAdministratorDetail = '/auth/admin/administrators/detail';

  /// Primer ingreso de un administrador creado con contraseña temporal.
  static const adminChangePassword = '/auth/admin/change-password';
}
