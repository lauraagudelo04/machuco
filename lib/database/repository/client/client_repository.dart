import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:floor/floor.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/client/client.dart';

@dao
abstract class ClientDao {
  @Query('SELECT * FROM clients WHERE id = :id LIMIT 1')
  Future<Client?> findById(int id);

  @Query('SELECT * FROM clients')
  Future<List<Client>> findAll();

  @insert
  Future<int> insertClient(Client client); 

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertClients(List<Client> clients);

  @update
  Future<int> updateClient(Client client);

  @delete
  Future<int> deleteClient(Client client);

  @Query('DELETE FROM clients WHERE id = :id')
  Future<void> deleteById(int id);
}

class ClientRepository {
  ClientRepository({
    AppDatabase? database,
    http.Client? httpClient,
    String? supabaseUrl,
    String? publishableKey,
  })  : _database = database == null
            ? AppDatabaseProvider.database
            : Future.value(database),
        _get = httpClient?.get ?? http.get,
        _supabaseUrl = supabaseUrl ??
            const String.fromEnvironment(
              'SUPABASE_URL',
              defaultValue: 'https://ogrbbuwtsyezegkpwtsl.supabase.co',
            ),
        _publishableKey = publishableKey ??
            const String.fromEnvironment(
              'SUPABASE_PUBLISHABLE_KEY',
              defaultValue: 'sb_publishable_Wv16MVxsTzA89lBeocarLQ_YL33Ya_E',
            );

  final Future<AppDatabase> _database;
  final Future<http.Response> Function(Uri, {Map<String, String>? headers}) _get;
  final String _supabaseUrl;
  final String _publishableKey;

  /// Descarga los clientes de Supabase y los guarda en Floor
  Future<void> _syncClients() async {
    // Pedimos los datos ordenados por ID para asegurar que "el primero" siempre sea el mismo
    final uri = Uri.parse('$_supabaseUrl/rest/v1/clients?select=*&order=id.asc');
    try {
      final response = await _get(
        uri,
        headers: {'apikey': _publishableKey, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> rows = jsonDecode(utf8.decode(response.bodyBytes));
        final clients = rows
            .map((row) => Client.fromJson(row as Map<String, dynamic>))
            .toList();

        final dao = (await _database).clientDao;
        // Guarda todos los clientes en la base de datos local de un solo golpe
        await dao.insertClients(clients);
      }
    } catch (e) {
      print('Sincronización de clientes fallida (Offline): $e');
    }
  }

  Future<List<Client>> getAllClients() async {
    // 1. Primero intentamos sincronizar con la nube silenciosamente
    await _syncClients();
    
    // 2. Retornamos lo que hay en la base de datos local (que ahora está actualizada)
    final dao = (await _database).clientDao;
    return await dao.findAll();
  }

  Future<Client?> getClientById(int id) async {
    final dao = (await _database).clientDao;
    return await dao.findById(id);
  }

  Future<void> saveClient(Client client) async {
    final dao = (await _database).clientDao;
    await dao.insertClient(client);
  }

  Future<void> updateClient(Client client) async {
    final dao = (await _database).clientDao;
    await dao.updateClient(client);
  }

  Future<void> removeClient(Client client) async {
    final dao = (await _database).clientDao;
    await dao.deleteClient(client);
  }
}