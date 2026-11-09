import 'package:floor/floor.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/auth/auth_user_profile_entry.dart';
import 'package:machuco/models/auth/user_profile.dart';

@dao
abstract class AuthUserProfileDao {
  @Query('SELECT * FROM auth_user_profile LIMIT 1')
  Future<AuthUserProfileEntry?> findCurrent();

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertProfile(AuthUserProfileEntry entry);

  @Query('DELETE FROM auth_user_profile')
  Future<void> deleteAll();

  /// Una sola fila: borra la anterior (otro usuario) y guarda la nueva.
  @transaction
  Future<void> replaceCurrent(AuthUserProfileEntry entry) async {
    await deleteAll();
    await insertProfile(entry);
  }
}

/// Contrato de la caché local del perfil del usuario autenticado.
///
/// Firestore es la fuente de verdad; esta caché solo sirve para mostrar datos
/// sin red y nunca autoriza nada.
abstract interface class AuthUserProfileRepository {
  /// Reemplaza la fila existente con el perfil del usuario actual.
  Future<void> saveCurrent(UserProfile profile);

  /// `null` si no hay perfil guardado.
  Future<AuthUserProfileEntry?> loadCurrent();

  Future<void> clear();
}

/// [AuthUserProfileRepository] sobre SQLite (Floor / `AppDatabase`).
class FloorAuthUserProfileRepository implements AuthUserProfileRepository {
  FloorAuthUserProfileRepository({
    AppDatabase? database,
    DateTime Function()? clock,
  }) : _injectedDatabase = database,
       _clock = clock ?? DateTime.now;

  final AppDatabase? _injectedDatabase;
  final DateTime Function() _clock;

  // Apertura perezosa: construir el repositorio no abre SQLite.
  Future<AuthUserProfileDao> _dao() async =>
      (_injectedDatabase ?? await AppDatabaseProvider.database)
          .authUserProfileDao;

  @override
  Future<void> saveCurrent(UserProfile profile) async {
    final entry = AuthUserProfileEntry.fromProfile(profile, syncedAt: _clock());
    await (await _dao()).replaceCurrent(entry);
  }

  @override
  Future<AuthUserProfileEntry?> loadCurrent() async =>
      (await _dao()).findCurrent();

  @override
  Future<void> clear() async => (await _dao()).deleteAll();
}

/// Implementación en memoria para pruebas.
class InMemoryAuthUserProfileRepository implements AuthUserProfileRepository {
  InMemoryAuthUserProfileRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  AuthUserProfileEntry? _current;

  @override
  Future<void> saveCurrent(UserProfile profile) async {
    _current = AuthUserProfileEntry.fromProfile(profile, syncedAt: _clock());
  }

  @override
  Future<AuthUserProfileEntry?> loadCurrent() async => _current;

  @override
  Future<void> clear() async {
    _current = null;
  }
}
