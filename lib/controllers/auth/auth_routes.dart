/// Rutas del módulo de autenticación.
///
/// Constantes temporales: `lib/routes/routes.dart` pertenece al frontend, que
/// las referenciará desde `AppRoutes` (mismos valores) y registrará las
/// pantallas. Los controllers solo devuelven estas cadenas.
abstract final class AuthRoutes {
  static const accountReview = '/auth/account-review';
  static const adminOwnerApprovals = '/auth/admin/owner-approvals';
  static const adminOwnerApprovalDetail = '/auth/admin/owner-approvals/detail';
  static const adminAdministrators = '/auth/admin/administrators';
}
