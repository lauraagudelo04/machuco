import 'package:floor/floor.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';

/// Caché local (una sola fila) del perfil básico del usuario autenticado.
///
/// Firestore (`users/{uid}`) es la fuente de verdad; esto solo permite
/// mostrar datos sin red y NO autoriza nada. Deliberadamente no guarda NIT,
/// fecha de nacimiento, contraseñas ni tokens.
@Entity(tableName: 'auth_user_profile')
class AuthUserProfileEntry {
  const AuthUserProfileEntry({
    required this.uid,
    required this.email,
    required this.firstNames,
    required this.lastNames,
    required this.role,
    required this.accountStatus,
    required this.syncedAt,
    this.phoneCountryCodeId,
    this.phoneNumber,
    this.companyName,
  });

  /// Proyecta un perfil de Firestore a la fila local, sin datos sensibles.
  factory AuthUserProfileEntry.fromProfile(
    UserProfile profile, {
    required DateTime syncedAt,
  }) {
    final hasSplitNames =
        (profile.firstNames ?? '').isNotEmpty ||
        (profile.lastNames ?? '').isNotEmpty;
    return AuthUserProfileEntry(
      uid: profile.uid,
      email: profile.email.trim().toLowerCase(),
      firstNames: hasSplitNames ? profile.firstNames ?? '' : profile.fullName,
      lastNames: hasSplitNames ? profile.lastNames ?? '' : '',
      role: profile.role.metadataValue,
      accountStatus: profile.accountStatus?.storageValue ?? '',
      phoneCountryCodeId: profile.phoneCountryCodeId,
      phoneNumber: profile.phoneNumber.isEmpty ? null : profile.phoneNumber,
      companyName: profile.companyName,
      syncedAt: syncedAt.toUtc().toIso8601String(),
    );
  }

  @PrimaryKey(autoGenerate: false)
  final String uid;

  final String email;

  @ColumnInfo(name: 'first_names')
  final String firstNames;

  @ColumnInfo(name: 'last_names')
  final String lastNames;

  final String role;

  @ColumnInfo(name: 'account_status')
  final String accountStatus;

  @ColumnInfo(name: 'phone_country_code_id')
  final int? phoneCountryCodeId;

  @ColumnInfo(name: 'phone_number')
  final String? phoneNumber;

  @ColumnInfo(name: 'company_name')
  final String? companyName;

  /// ISO-8601 (UTC) de la última sincronización con Firestore.
  @ColumnInfo(name: 'synced_at')
  final String syncedAt;

  String get fullName => '$firstNames $lastNames'.trim();
}
