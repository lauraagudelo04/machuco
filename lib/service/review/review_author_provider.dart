import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/service/firebase/current_user.dart';

/// Autor de una reseña: id estable y nombre visible.
typedef ReviewAuthor = ({String id, String name});

/// Responde "¿quién está escribiendo la reseña?" sin que el controlador
/// conozca el proveedor de autenticación.
///
/// Solo decide qué se muestra; que nadie publique a nombre de otro lo debe
/// garantizar el backend.
abstract interface class ReviewAuthorProvider {
  /// Autor de la sesión actual, o `null` si no hay sesión.
  Future<ReviewAuthor?> currentAuthor();
}

/// Toma el `uid` de Firebase Auth y el nombre del perfil en Firestore.
///
/// No toca Firebase hasta que se pide el autor, así crear el controlador no
/// requiere Firebase inicializado.
class FirebaseReviewAuthorProvider implements ReviewAuthorProvider {
  FirebaseReviewAuthorProvider({this._profiles});

  UserProfileRepository? _profiles;

  @override
  Future<ReviewAuthor?> currentAuthor() async {
    final uid = CurrentUser.uid;
    if (uid == null) return null;
    final profiles = _profiles ??= FirestoreUserProfileRepository();
    final profile = await profiles.getProfile(uid);
    // Sin perfil se muestra un nombre genérico; nunca el correo, que es un
    // dato personal.
    final name = profile?.fullName.trim() ?? '';
    return (id: uid, name: name.isEmpty ? 'Cliente' : name);
  }
}
