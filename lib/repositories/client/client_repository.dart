import '../../models/client/client.dart';
import 'client_dao.dart';

class ClientRepository {
  final ClientDao _clientDao;

  ClientRepository(this._clientDao);

  Future<List<Client>> getAllClients() async {
    return await _clientDao.findAll();
  }

  Future<Client?> getClientById(String id) async {
    return await _clientDao.findById(id);
  }

  Future<void> saveClient(Client client) async {
    await _clientDao.insertClient(client);
  }

  Future<void> updateClient(Client client) async {
    await _clientDao.updateClient(client);
  }

  Future<void> removeClient(Client client) async {
    await _clientDao.deleteClient(client);
  }
}