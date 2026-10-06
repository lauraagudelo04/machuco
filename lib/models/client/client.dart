import 'package:floor/floor.dart';

@Entity(tableName: 'clients')
class Client {
  const Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
  });

  @PrimaryKey()
  final String id;

  @ColumnInfo(name: 'name')
  final String name;

  @ColumnInfo(name: 'phone')
  final String phone;

  @ColumnInfo(name: 'email')
  final String email;

  @ColumnInfo(name: 'password')
  final String password;

  String get initials =>
      name.split(' ').take(2).map((w) => w[0]).join();

  String get maskedPassword => '*' * password.length;

  Client copyWith({
    String? name,
    String? phone,
    String? email,
    String? password,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }
}
