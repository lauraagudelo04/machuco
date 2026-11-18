import 'dart:convert';

import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

/// Preferencias locales no sensibles del módulo de autenticación
/// (namespace `auth`).
///
/// Es la API pública para que otras funcionalidades (perfil, reservas, PQRS,
/// pagos) lean el correo del usuario autenticado sin conocer las claves:
///
/// ```dart
/// final email = await AuthPreferences().loadCurrentUserEmail();
/// ```
///
/// El correo sirve para mostrar y precargar datos, **nunca para autorizar**:
/// la autorización se valida con la sesión en el backend. Aquí no se guardan
/// contraseñas, tokens ni el NIT.
class AuthPreferences {
  AuthPreferences({LocalPreferencesService? preferences})
    : _preferences =
          preferences ?? SharedPreferencesLocalService(namespace: namespace);

  static const namespace = 'auth';

  static const _currentUserEmailKey = 'currentUserEmail';
  static const _lastCountryCodeIdKey = 'lastCountryCodeId';
  static const _catalogsSyncedAtKey = 'catalogsSyncedAt';
  static const _phoneLengthsKey = 'phoneLengths';

  static const _rememberEmailKey = 'rememberEmail';
  static const _rememberedEmailKey = 'rememberedEmail';

  final LocalPreferencesService _preferences;

  /// Normaliza el correo antes de guardarlo: sin espacios y en minúsculas.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  /// Correo del usuario autenticado, o `null` si no hay ninguno guardado.
  Future<String?> loadCurrentUserEmail() async {
    final email = await _preferences.getString(_currentUserEmailKey);
    if (email == null || email.trim().isEmpty) return null;
    return email;
  }

  Future<void> saveCurrentUserEmail(String email) async {
    final normalized = normalizeEmail(email);
    if (normalized.isEmpty) {
      await clearCurrentUserEmail();
      return;
    }
    await _preferences.setString(_currentUserEmailKey, normalized);
  }

  Future<void> clearCurrentUserEmail() =>
      _preferences.remove(_currentUserEmailKey);

  /// Estado de "Recordar mi correo": si la opción está marcada y el último
  /// correo guardado (`null` si no hay). Solo para precargar el formulario.
  Future<({bool remember, String? email})> loadRememberedEmail() async {
    final remember = await _preferences.getBool(_rememberEmailKey) ?? false;
    if (!remember) return (remember: false, email: null);
    final email = await _preferences.getString(_rememberedEmailKey);
    return (
      remember: true,
      email: email == null || email.trim().isEmpty ? null : email,
    );
  }

  /// Marca "Recordar mi correo" y guarda [email] normalizado.
  Future<void> saveRememberedEmail(String email) async {
    final normalized = normalizeEmail(email);
    if (normalized.isEmpty) {
      await clearRememberedEmail();
      return;
    }
    await _preferences.setBool(_rememberEmailKey, true);
    await _preferences.setString(_rememberedEmailKey, normalized);
  }

  /// Desmarca "Recordar mi correo" y elimina el correo recordado. Cerrar
  /// sesión no la llama (se conserva); [clearAll] sí lo borra todo.
  Future<void> clearRememberedEmail() async {
    await _preferences.remove(_rememberEmailKey);
    await _preferences.remove(_rememberedEmailKey);
  }

  /// Borra TODO el namespace `auth` (correo de sesión, correo recordado,
  /// último indicativo, marca de sincronización...). Se usa al eliminar la
  /// cuenta; no toca las preferencias de otros módulos ni los maestros en
  /// SQLite.
  Future<void> clearAll() => _preferences.clear();

  Future<int?> loadLastCountryCodeId() =>
      _preferences.getInt(_lastCountryCodeIdKey);

  Future<void> saveLastCountryCodeId(int id) =>
      _preferences.setInt(_lastCountryCodeIdKey, id);

  /// Momento de la última sincronización de maestros con Supabase.
  Future<DateTime?> loadCatalogsSyncedAt() async {
    final raw = await _preferences.getString(_catalogsSyncedAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Longitud del celular por indicativo (`phone_min_length` y
  /// `phone_max_length` de Supabase), por id de `phone_country_codes`. Datos
  /// públicos del maestro; el SQLite compartido no tiene esas columnas.
  Future<Map<int, ({int min, int max})>> loadPhoneLengths() async {
    final raw = await _preferences.getString(_phoneLengthsKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final lengths = <int, ({int min, int max})>{};
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key.toString());
        final value = entry.value;
        if (id == null || value is! List || value.length != 2) continue;
        final min = value[0];
        final max = value[1];
        if (min is int && max is int) lengths[id] = (min: min, max: max);
      }
      return lengths;
    } catch (_) {
      return const {};
    }
  }

  Future<void> savePhoneLengths(Map<int, ({int min, int max})> lengths) =>
      _preferences.setString(
        _phoneLengthsKey,
        jsonEncode({
          for (final entry in lengths.entries)
            '${entry.key}': [entry.value.min, entry.value.max],
        }),
      );

  Future<void> saveCatalogsSyncedAt(DateTime value) => _preferences.setString(
    _catalogsSyncedAtKey,
    value.toUtc().toIso8601String(),
  );
}
