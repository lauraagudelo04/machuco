import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/database/repository/auth/administrators_store.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/auth/auth_account_provisioner.dart';

UserProfile adminProfile(
  String uid, {
  AccountStatus status = AccountStatus.active,
  bool mustChangePassword = false,
  String? name,
  String? createdBy,
  RegisteredUserRole role = RegisteredUserRole.admin,
}) => UserProfile(
  uid: uid,
  fullName: name ?? 'Admin $uid',
  email: '$uid@example.com',
  phoneNumber: '+573001234567',
  role: role,
  accountStatus: status,
  firstNames: 'Admin',
  lastNames: uid,
  phoneCountryCodeId: 1,
  mustChangePassword: mustChangePassword,
  createdBy: createdBy,
  createdAt: DateTime.utc(2026, 1, 1),
);

/// In-memory [AdministratorsStore] with Firestore-like optimistic
/// transactions: if a document read by a transaction changed before it
/// commits, the body runs again.
class FakeAdministratorsStore implements AdministratorsStore {
  FakeAdministratorsStore({Iterable<UserProfile> profiles = const []}) {
    for (final profile in profiles) {
      this.profiles[profile.uid] = profile;
    }
  }

  final profiles = <String, UserProfile>{};
  final _versions = <String, int>{};

  /// `null` = the registry document does not exist yet.
  int? registryCount;
  int _registryVersion = 0;

  int ensureRegistryCalls = 0;
  int transactionAttempts = 0;
  final clearedMustChange = <String>[];

  /// Fails the next transaction commit (before applying any write).
  AdministratorsRepositoryException? failNextCommit;

  /// Fails the next fetch.
  AdministratorsRepositoryException? failNextFetch;

  int _versionOf(String uid) => _versions[uid] ?? 0;

  void _bump(String uid) => _versions[uid] = _versionOf(uid) + 1;

  @override
  Future<List<UserProfile>> fetchAdministrators() async {
    final failure = failNextFetch;
    if (failure != null) {
      failNextFetch = null;
      throw failure;
    }
    return [
      for (final p in profiles.values)
        if (p.role == RegisteredUserRole.admin) p,
    ];
  }

  @override
  Future<UserProfile?> fetchProfile(String uid) async => profiles[uid];

  @override
  Future<int> countActiveAdministrators() async => profiles.values
      .where(
        (p) =>
            p.role == RegisteredUserRole.admin &&
            p.accountStatus == AccountStatus.active,
      )
      .length;

  @override
  Future<void> ensureRegistry(int initialCount) async {
    ensureRegistryCalls++;
    registryCount ??= initialCount < 1 ? 1 : initialCount;
  }

  @override
  Future<void> clearMustChangePassword(String uid) async {
    clearedMustChange.add(uid);
    final profile = profiles[uid];
    if (profile != null) {
      profiles[uid] = adminProfile(
        uid,
        status: profile.accountStatus ?? AccountStatus.active,
      );
    }
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(AdminTransaction tx) action,
  ) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      transactionAttempts++;
      final tx = _FakeTransaction(this);
      final result = await action(tx);
      // Simulates the network round trip so concurrent bodies interleave.
      await Future<void>.delayed(Duration.zero);
      final failure = failNextCommit;
      if (failure != null) {
        failNextCommit = null;
        throw failure;
      }
      if (tx.isStale) continue;
      tx.commit();
      return result;
    }
    throw const AdministratorsRepositoryException(
      AdministratorsFailureType.unknown,
      'Demasiados conflictos.',
    );
  }
}

class _FakeTransaction implements AdminTransaction {
  _FakeTransaction(this._store);

  final FakeAdministratorsStore _store;
  final _readVersions = <String, int>{};
  int? _registryReadVersion;
  final _writes = <void Function()>[];

  bool get isStale {
    for (final entry in _readVersions.entries) {
      if (_store._versionOf(entry.key) != entry.value) return true;
    }
    final registryRead = _registryReadVersion;
    return registryRead != null && registryRead != _store._registryVersion;
  }

  void commit() {
    for (final write in _writes) {
      write();
    }
  }

  @override
  Future<UserProfile?> readProfile(String uid) async {
    _readVersions[uid] = _store._versionOf(uid);
    return _store.profiles[uid];
  }

  @override
  Future<int?> readActiveAdminCount() async {
    _registryReadVersion = _store._registryVersion;
    return _store.registryCount;
  }

  @override
  void createAdminProfile(
    String uid,
    NewAdministratorData data, {
    required String createdBy,
  }) {
    _writes.add(() {
      _store.profiles[uid] = UserProfile(
        uid: uid,
        fullName: '${data.firstNames} ${data.lastNames}'.trim(),
        email: data.email,
        phoneNumber: data.phoneNumber,
        role: RegisteredUserRole.admin,
        accountStatus: AccountStatus.active,
        firstNames: data.firstNames,
        lastNames: data.lastNames,
        phoneCountryCodeId: data.phoneCountryCodeId,
        mustChangePassword: true,
        createdBy: createdBy,
      );
      _store._bump(uid);
    });
  }

  @override
  void updateContact(String uid, AdministratorContactChanges changes) {
    _writes.add(() {
      final before = _store.profiles[uid];
      if (before == null) return;
      _store.profiles[uid] = UserProfile(
        uid: uid,
        fullName: changes.fullName,
        email: before.email,
        phoneNumber: changes.phoneNumber,
        role: before.role,
        accountStatus: before.accountStatus,
        firstNames: changes.firstNames,
        lastNames: changes.lastNames,
        phoneCountryCodeId: changes.phoneCountryCodeId,
        mustChangePassword: before.mustChangePassword,
        createdBy: before.createdBy,
        createdAt: before.createdAt,
      );
      _store._bump(uid);
    });
  }

  @override
  void anonymize(String uid, {required String actorUid}) {
    _writes.add(() {
      final before = _store.profiles[uid];
      _store.profiles[uid] = UserProfile(
        uid: uid,
        fullName: FirestoreAdministratorsStore.anonymizedName,
        email: '',
        phoneNumber: '',
        role: RegisteredUserRole.admin,
        accountStatus: AccountStatus.anonymized,
        createdBy: before?.createdBy,
        createdAt: before?.createdAt,
      );
      _store._bump(uid);
    });
  }

  @override
  void setActiveAdminCount(int count) {
    _writes.add(() {
      _store.registryCount = count;
      _store._registryVersion++;
    });
  }
}

class FakeProvisionedAccount implements ProvisionedAccount {
  FakeProvisionedAccount(this.uid);

  @override
  final String uid;
  bool rolledBack = false;
  bool closed = false;

  @override
  Future<void> rollback() async => rolledBack = true;

  @override
  Future<void> close() async => closed = true;
}

class FakeProvisioner implements AuthAccountProvisioner {
  final existingEmails = <String>{};
  final accounts = <FakeProvisionedAccount>[];
  final passwords = <String>[];
  final emails = <String>[];
  AdministratorsRepositoryException? failWith;

  @override
  Future<ProvisionedAccount> createAccount({
    required String email,
    required String password,
  }) async {
    final failure = failWith;
    if (failure != null) throw failure;
    if (existingEmails.contains(email)) {
      throw const AdministratorsRepositoryException(
        AdministratorsFailureType.emailInUse,
        'Ese correo ya está en uso.',
      );
    }
    emails.add(email);
    passwords.add(password);
    final account = FakeProvisionedAccount('new-${accounts.length + 1}');
    accounts.add(account);
    return account;
  }
}

/// Repository double for controller and service tests.
class FakeAdministratorsRepository implements AdministratorsRepository {
  final calls = <String>[];
  List<UserProfile> admins = [];
  AdministratorsRepositoryException? failNext;
  AdministratorsRepositoryException? failClearMark;
  AdministratorsRepositoryException? failList;
  CreatedAdministrator? createResult;
  NewAdministratorData? lastCreate;
  AdministratorContactChanges? lastChanges;

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<List<UserProfile>> listAdministrators() async {
    calls.add('list');
    final failure = failList;
    if (failure != null) throw failure;
    return List.of(admins);
  }

  @override
  Future<UserProfile> getAdministrator(String uid) async {
    calls.add('get:$uid');
    return admins.firstWhere((a) => a.uid == uid);
  }

  @override
  Future<CreatedAdministrator> createAdministrator(
    NewAdministratorData data,
  ) async {
    calls.add('create');
    lastCreate = data;
    _maybeFail();
    return createResult ??
        CreatedAdministrator(
          profile: adminProfile('new', mustChangePassword: true),
          temporaryPassword: 'Temp-Password-1!',
        );
  }

  @override
  Future<void> updateAdministrator(
    String uid,
    AdministratorContactChanges changes,
  ) async {
    calls.add('update:$uid');
    lastChanges = changes;
    _maybeFail();
  }

  @override
  Future<void> anonymizeAdministrator(String uid) async {
    calls.add('anonymize:$uid');
    _maybeFail();
    admins = [
      for (final a in admins)
        if (a.uid != uid) a,
    ];
  }

  @override
  Future<void> anonymizeOwnAccount() async {
    calls.add('anonymizeOwn');
    _maybeFail();
  }

  @override
  Future<void> clearMustChangePassword() async {
    calls.add('clearMark');
    final failure = failClearMark;
    if (failure != null) throw failure;
  }
}
