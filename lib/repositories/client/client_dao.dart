import 'package:floor/floor.dart';
import '../../models/client/client.dart';

@dao
abstract class ClientDao {
  @Query('SELECT * FROM clients WHERE id = :id LIMIT 1')
  Future<Client?> findById(String id);

  @Query('SELECT * FROM clients ORDER BY created_at_ms DESC')
  Future<List<Client>> findAll();

  @insert
  Future<void> insertClient(Client client);

  @update
  Future<int> updateClient(Client client);

  @delete
  Future<int> deleteClient(Client client);

  @Query('DELETE FROM clients WHERE id = :id')
  Future<void> deleteById(String id);
}