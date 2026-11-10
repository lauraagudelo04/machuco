import 'package:firebase_auth/firebase_auth.dart';
import 'package:machuco/controllers/auth/administrators_controller.dart';
import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/service/auth/password_change_service.dart';

/// Uid del usuario autenticado, o `null` si no hay sesión (o Firebase no está
/// inicializado). Solo sirve para mostrar la etiqueta "Tú".
String? currentAdminUid() {
  try {
    return FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    return null;
  }
}

/// Construye el [AdministratorsController] de producción. Las vistas de
/// administradores lo comparten por argumentos de ruta.
AdministratorsController buildAdministratorsController() {
  return AdministratorsController(
    repository: FirestoreAdministratorsRepository(),
    passwordChangeService: FirebasePasswordChangeService(),
    currentUid: currentAdminUid,
  );
}
