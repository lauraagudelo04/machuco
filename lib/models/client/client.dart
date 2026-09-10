class Client {
  const Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
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
