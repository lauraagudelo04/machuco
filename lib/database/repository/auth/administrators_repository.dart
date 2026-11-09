import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/auth/validators/auth_input_normalizer.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/database/repository/auth/administrators_store.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/administrator_models.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/auth/auth_account_provisioner.dart';
import 'package:machuco/service/auth/temporary_password_generator.dart';

export 'package:machuco/models/auth/administrator_models.dart';

/// Contract to manage administrator accounts, independent of the provider.
///
/// There is no own backend (Spark plan): the authority is `firestore.rules`.
/// Client-side checks (valid input, "last administrator") only give clear
/// messages and keep the registry consistent; they never replace the rules.
abstract interface class AdministratorsRepository {
  /// Administrators except anonymized ones.
  Future<List<UserProfile>> listAdministrators();

  /// Throws `notFound` if it does not exist, is anonymized or is not an admin.
  Future<UserProfile> getAdministrator(String uid);

  /// Creates a Firebase Auth user with a generated temporary password and its
  /// `users/{uid}` profile (`mustChangePassword: true`). The creator keeps
  /// their session. No email or SMS is sent.
  Future<CreatedAdministrator> createAdministrator(NewAdministratorData data);

  /// Updates names, surnames, dial code and phone (and recalculates
  /// `fullName`). Email, role and status are never edited.
  Future<void> updateAdministrator(
    String uid,
    AdministratorContactChanges changes,
  );

  /// Anonymizes another administrator's profile. The Firebase Auth user is
  /// NOT deleted (no Admin SDK): its email stays taken.
  Future<void> anonymizeAdministrator(String uid);

  /// Anonymizes the signed-in administrator's own profile. Idempotent: an
  /// already anonymized profile is a success (retry after a partial failure).
  Future<void> anonymizeOwnAccount();

  /// Clears `mustChangePassword` on the signed-in administrator's profile.
  Future<void> clearMustChangePassword();
}

enum _Outcome { done, registryMissing, lastAdmin, notFound, notActive }

/// [AdministratorsRepository] on top of an [AdministratorsStore] (Firestore by
/// default) and an [AuthAccountProvisioner] (secondary Firebase app).
///
/// `system/adminRegistry.activeAdminCount` counts every administrator with
/// `accountStatus == active`, even one still holding a temporary password.
/// Creating adds 1 and anonymizing subtracts 1 inside a transaction that also
/// reads the count, so two simultaneous deletions cannot leave zero.
class FirestoreAdministratorsRepository implements AdministratorsRepository {
  FirestoreAdministratorsRepository({
    AdministratorsStore? store,
    AuthAccountProvisioner? provisioner,
    String? Function()? currentUid,
    String Function()? passwordGenerator,
  }) : _injectedStore = store,
       _injectedProvisioner = provisioner,
       _injectedUid = currentUid,
       _generatePassword =
           passwordGenerator ?? (() => TemporaryPasswordGenerator.generate());

  static const notFoundMessage = 'Esa cuenta de administrador ya no existe.';
  static const lastAdminMessage =
      'Eres el único administrador activo. Crea otro administrador antes de '
      'eliminar esta cuenta.';

  final AdministratorsStore? _injectedStore;
  final AuthAccountProvisioner? _injectedProvisioner;
  final String? Function()? _injectedUid;
  final String Function() _generatePassword;

  late final AdministratorsStore _store =
      _injectedStore ?? FirestoreAdministratorsStore();
  late final AuthAccountProvisioner _provisioner =
      _injectedProvisioner ?? FirebaseAuthAccountProvisioner();

  String? get _uid =>
      (_injectedUid ?? () => FirebaseAuth.instance.currentUser?.uid)();

  String _requireUid() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw const AdministratorsRepositoryException(
        AdministratorsFailureType.permissionDenied,
        'No tienes permisos para realizar esta operación.',
      );
    }
    return uid;
  }

  @override
  Future<List<UserProfile>> listAdministrators() async {
    final all = await _store.fetchAdministrators();
    final visible = [
      for (final profile in all)
        if (profile.role == RegisteredUserRole.admin &&
            profile.accountStatus != AccountStatus.anonymized)
          profile,
    ];
    visible.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return visible;
  }

  @override
  Future<UserProfile> getAdministrator(String uid) async {
    final profile = await _store.fetchProfile(uid);
    if (profile == null ||
        profile.role != RegisteredUserRole.admin ||
        profile.accountStatus == AccountStatus.anonymized) {
      throw const AdministratorsRepositoryException(
        AdministratorsFailureType.notFound,
        notFoundMessage,
      );
    }
    return profile;
  }

  @override
  Future<CreatedAdministrator> createAdministrator(
    NewAdministratorData data,
  ) async {
    final actorUid = _requireUid();
    final prepared = _prepare(data);

    final password = _generatePassword();
    // Fails with `emailInUse` without touching any existing account.
    final account = await _provisioner.createAccount(
      email: prepared.email,
      password: password,
    );
    try {
      final outcome = await _runWithRegistry((tx) async {
        final count = await tx.readActiveAdminCount();
        if (count == null) return _Outcome.registryMissing;
        tx.createAdminProfile(account.uid, prepared, createdBy: actorUid);
        tx.setActiveAdminCount(count + 1);
        return _Outcome.done;
      });
      _throwUnlessDone(outcome);
    } catch (error) {
      // Rollback: do not leave an Auth user without a profile.
      await account.rollback();
      if (error is AdministratorsRepositoryException) rethrow;
      debugPrint('Creación de administrador falló: ${error.runtimeType}');
      throw const AdministratorsRepositoryException(
        AdministratorsFailureType.unknown,
        'No pudimos crear el administrador. Intenta nuevamente.',
      );
    } finally {
      await account.close();
    }
    return CreatedAdministrator(
      profile: UserProfile(
        uid: account.uid,
        fullName: '${prepared.firstNames} ${prepared.lastNames}'.trim(),
        email: prepared.email,
        phoneNumber: prepared.phoneNumber,
        role: RegisteredUserRole.admin,
        accountStatus: AccountStatus.active,
        firstNames: prepared.firstNames,
        lastNames: prepared.lastNames,
        phoneCountryCodeId: prepared.phoneCountryCodeId,
        mustChangePassword: true,
        createdBy: actorUid,
      ),
      temporaryPassword: password,
    );
  }

  @override
  Future<void> updateAdministrator(
    String uid,
    AdministratorContactChanges changes,
  ) async {
    _requireUid();
    final prepared = AdministratorContactChanges(
      firstNames: AuthInputNormalizer.text(changes.firstNames),
      lastNames: AuthInputNormalizer.text(changes.lastNames),
      phoneCountryCodeId: changes.phoneCountryCodeId,
      phoneNumber: changes.phoneNumber.trim(),
    );
    _validateContact(
      prepared.firstNames,
      prepared.lastNames,
      prepared.phoneCountryCodeId,
      prepared.phoneNumber,
    );
    final outcome = await _store.runTransaction((tx) async {
      final target = await tx.readProfile(uid);
      if (!_isEditableAdmin(target)) return _Outcome.notFound;
      tx.updateContact(uid, prepared);
      return _Outcome.done;
    });
    _throwUnlessDone(outcome);
  }

  @override
  Future<void> anonymizeAdministrator(String uid) =>
      _anonymize(uid, actorUid: _requireUid(), tolerateAlreadyDone: false);

  @override
  Future<void> anonymizeOwnAccount() {
    final uid = _requireUid();
    return _anonymize(uid, actorUid: uid, tolerateAlreadyDone: true);
  }

  Future<void> _anonymize(
    String uid, {
    required String actorUid,
    required bool tolerateAlreadyDone,
  }) async {
    var alreadyAnonymized = false;
    final outcome = await _runWithRegistry((tx) async {
      alreadyAnonymized = false;
      final target = await tx.readProfile(uid);
      if (target != null &&
          target.role == RegisteredUserRole.admin &&
          target.accountStatus == AccountStatus.anonymized) {
        alreadyAnonymized = true;
        return _Outcome.notFound;
      }
      if (target == null || target.role != RegisteredUserRole.admin) {
        return _Outcome.notFound;
      }
      if (target.accountStatus != AccountStatus.active) {
        return _Outcome.notActive;
      }
      final count = await tx.readActiveAdminCount();
      if (count == null) return _Outcome.registryMissing;
      // Atomic with the writes below: a concurrent deletion makes Firestore
      // retry this body, which then sees the lowered count.
      if (count <= 1) return _Outcome.lastAdmin;
      tx.anonymize(uid, actorUid: actorUid);
      tx.setActiveAdminCount(count - 1);
      return _Outcome.done;
    });
    if (outcome == _Outcome.notFound &&
        alreadyAnonymized &&
        tolerateAlreadyDone) {
      return;
    }
    _throwUnlessDone(outcome);
  }

  @override
  Future<void> clearMustChangePassword() =>
      _store.clearMustChangePassword(_requireUid());

  // ------------------------------------------------------------- internals

  /// Runs [body] in a transaction; if the registry does not exist yet, creates
  /// it counting the active administrators and runs [body] again.
  Future<_Outcome> _runWithRegistry(
    Future<_Outcome> Function(AdminTransaction tx) body,
  ) async {
    var outcome = await _store.runTransaction(body);
    if (outcome == _Outcome.registryMissing) {
      await _store.ensureRegistry(await _store.countActiveAdministrators());
      outcome = await _store.runTransaction(body);
    }
    return outcome;
  }

  static bool _isEditableAdmin(UserProfile? profile) =>
      profile != null &&
      profile.role == RegisteredUserRole.admin &&
      profile.accountStatus == AccountStatus.active;

  static void _throwUnlessDone(_Outcome outcome) {
    switch (outcome) {
      case _Outcome.done:
        return;
      case _Outcome.lastAdmin:
        throw const AdministratorsRepositoryException(
          AdministratorsFailureType.lastAdmin,
          lastAdminMessage,
        );
      case _Outcome.notFound:
        throw const AdministratorsRepositoryException(
          AdministratorsFailureType.notFound,
          notFoundMessage,
        );
      case _Outcome.notActive:
        throw const AdministratorsRepositoryException(
          AdministratorsFailureType.invalidInput,
          'Solo se puede eliminar un administrador con la cuenta activa.',
        );
      case _Outcome.registryMissing:
        throw const AdministratorsRepositoryException(
          AdministratorsFailureType.unknown,
          'No pudimos completar la operación. Intenta nuevamente.',
        );
    }
  }

  static NewAdministratorData _prepare(NewAdministratorData data) {
    final prepared = NewAdministratorData(
      firstNames: AuthInputNormalizer.text(data.firstNames),
      lastNames: AuthInputNormalizer.text(data.lastNames),
      phoneCountryCodeId: data.phoneCountryCodeId,
      phoneNumber: data.phoneNumber.trim(),
      email: AuthInputNormalizer.email(data.email),
    );
    _validateContact(
      prepared.firstNames,
      prepared.lastNames,
      prepared.phoneCountryCodeId,
      prepared.phoneNumber,
    );
    _fail(AuthValidators.email(prepared.email));
    return prepared;
  }

  static void _validateContact(
    String firstNames,
    String lastNames,
    int phoneCountryCodeId,
    String phoneNumber,
  ) {
    _fail(AuthValidators.firstNames(firstNames));
    _fail(AuthValidators.lastNames(lastNames));
    if (phoneCountryCodeId <= 0) _fail('Selecciona el indicativo.');
    if (phoneNumber.length < 4 || phoneNumber.length > 20) {
      _fail('Ingresa un número de celular válido.');
    }
  }

  static void _fail(String? message) {
    if (message == null) return;
    throw AdministratorsRepositoryException(
      AdministratorsFailureType.invalidInput,
      message,
    );
  }
}
