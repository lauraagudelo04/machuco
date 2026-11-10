import 'package:floor/floor.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/client/client.dart';

@dao
abstract class ClientDao {
  @Query('SELECT * FROM clients WHERE id = :id LIMIT 1')
  Future<ClientEntry?> findById(int id);

  @Query('SELECT * FROM clients')
  Future<List<ClientEntry>> findAll();

  @insert
  Future<int> insertClient(ClientEntry client);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertClients(List<ClientEntry> clients);

  @update
  Future<int> updateClient(ClientEntry client);

  @delete
  Future<int> deleteClient(ClientEntry client);

  @Query('DELETE FROM clients WHERE id = :id')
  Future<void> deleteById(int id);
}

class ClientRepositoryException implements Exception {
  const ClientRepositoryException(this.message);
  final String message;
}

class ClientRepository {
  ClientRepository({
    AppDatabase? database,
  }) : _database = database == null
            ? AppDatabaseProvider.database
            : Future.value(database);

  final Future<AppDatabase> _database;

  Future<List<ClientEntry>> getAllClients() async {
    final dao = (await _database).clientDao;
    return await dao.findAll();
  }

  Future<ClientEntry?> getClientById(int id) async {
    final dao = (await _database).clientDao;
    return await dao.findById(id);
  }

  Future<void> saveClient(ClientEntry client) async {
    final dao = (await _database).clientDao;
    await dao.insertClient(client);
  }

  Future<void> updateClient(ClientEntry client) async {
    final dao = (await _database).clientDao;
    await dao.updateClient(client);
  }

  Future<void> removeClient(ClientEntry client) async {
    final dao = (await _database).clientDao;
    await dao.deleteClient(client);
  }
}