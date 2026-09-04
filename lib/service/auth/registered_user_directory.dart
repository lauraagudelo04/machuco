import 'package:machuco/models/auth/registered_user.dart';

abstract interface class RegisteredUserDirectory {
  Future<List<RegisteredUser>> listUsers({String? accessToken});

  Future<void> upsertUser(RegisteredUser user);
}

final class InMemoryRegisteredUserDirectory implements RegisteredUserDirectory {
  InMemoryRegisteredUserDirectory({List<RegisteredUser>? initialUsers})
    : _users = List<RegisteredUser>.from(initialUsers ?? _seededUsers);

  final List<RegisteredUser> _users;

  static final List<RegisteredUser> _seededUsers = [
    RegisteredUser(
      id: 'seed-user-001',
      fullName: 'Laura Gómez Restrepo',
      email: 'laura.gomez@machuco.com',
      phoneNumber: '+57 300 123 4567',
      role: RegisteredUserRole.owner,
      createdAt: DateTime.utc(2026, 1, 8, 14, 0),
    ),
    RegisteredUser(
      id: 'seed-user-002',
      fullName: 'Simón Restrepo Vélez',
      email: 'simon.restrepo@machuco.com',
      phoneNumber: '+57 311 987 6543',
      role: RegisteredUserRole.finalUser,
      createdAt: DateTime.utc(2026, 2, 15, 9, 45),
    ),
    RegisteredUser(
      id: 'seed-user-003',
      fullName: 'Inversiones Machuco S.A.S.',
      email: 'contacto@inversionesmachuco.com',
      phoneNumber: '+57 604 444 5566',
      role: RegisteredUserRole.administrator,
      createdAt: DateTime.utc(2026, 3, 20, 16, 30),
    ),
  ];

  @override
  Future<List<RegisteredUser>> listUsers({String? accessToken}) async {
    final users = List<RegisteredUser>.from(_users)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(users);
  }

  @override
  Future<void> upsertUser(RegisteredUser user) async {
    final existingIndex = _users.indexWhere(
      (candidate) => candidate.email.toLowerCase() == user.email.toLowerCase(),
    );
    if (existingIndex == -1) {
      _users.add(user);
      return;
    }
    _users[existingIndex] = user;
  }
}
