import 'package:machuco/models/client/client.dart';

abstract final class ClientController {
  static final List<Client> clients = [
    const Client(
      id: '1',
      name: 'Valentina Gómez',
      phone: '310 456 7890',
      email: 'valentina.gomez@correo.com',
      password: 'Val123',
    ),
    const Client(
      id: '2',
      name: 'Santiago Pérez',
      phone: '320 123 4567',
      email: 'santiago.perez@correo.com',
      password: 'San456',
    ),
    const Client(
      id: '3',
      name: 'Mariana Torres',
      phone: '301 987 6543',
      email: 'mariana.torres@correo.com',
      password: 'Mar789',
    ),
    const Client(
      id: '4',
      name: 'Andrés Ramírez',
      phone: '315 654 3210',
      email: 'andres.ramirez@correo.com',
      password: 'And321',
    ),
    const Client(
      id: '5',
      name: 'Laura Restrepo',
      phone: '300 111 2233',
      email: 'laura.restrepo@correo.com',
      password: 'Lau654',
    ),
    const Client(
      id: '6',
      name: 'Julián Castro',
      phone: '317 888 9999',
      email: 'julian.castro@correo.com',
      password: 'Jul987',
    ),
  ];

  static Client get currentClient => clients.first;

  static List<Client> search(String query) {
    if (query.isEmpty) return clients;
    final lower = query.toLowerCase();
    return clients
        .where(
          (c) =>
              c.name.toLowerCase().contains(lower) ||
              c.email.toLowerCase().contains(lower),
        )
        .toList();
  }

  static Client? getById(String id) {
    for (final client in clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  static void updateClient({
    required String id,
    required String name,
    required String phone,
    required String password,
  }) {
    final index = clients.indexWhere((c) => c.id == id);
    if (index == -1) return;
    clients[index] = clients[index].copyWith(
      name: name,
      phone: phone,
      password: password,
    );
  }

  static void unlink(Client client) {
    clients.remove(client);
  }
}
