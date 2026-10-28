import 'dart:convert';
import 'package:http/http.dart' as http;
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

  Future<void> _syncClients() async {
    final base = Uri.tryParse(_supabaseUrl);
    
    if (base == null || base.scheme != 'https' || base.host.isEmpty || _publishableKey.isEmpty) {
      print('Advertencia: Conexión a Supabase no configurada. Usando datos locales.');
      return; 
    }

    final uri = base.replace(
      path: '/rest/v1/clients',
      queryParameters: {'select': '*', 'order': 'id.asc'},
    );

    late final http.Response response;
    try {
      response = await _get(
        uri,
        headers: {'apikey': _publishableKey, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      print('Advertencia: Sin internet. Usando caché local de clientes.');
      return;
    }

    if (response.statusCode != 200) {
      print('Error ${response.statusCode} al consultar Supabase.');
      return;
    }

    try {
      final rows = jsonDecode(utf8.decode(response.bodyBytes));
      if (rows is! List) throw const FormatException('Respuesta inválida');
      
      final clients = rows
          .map((row) => ClientEntry.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);

      final dao = (await _database).clientDao;
      await dao.insertClients(clients);

    } on FormatException {
      print('Error crítico: El JSON de clientes está malformado.');
    } on TypeError {
      print('Error crítico: Los tipos de datos de Supabase no coinciden con el modelo Client.');
    }
  }

  Future<List<ClientEntry>> getAllClients() async {
    await _syncClients();
    final dao = (await _database).clientDao;
    return await dao.findAll();
  }

  Future<ClientEntry?> getClientById(int id) async {
    final dao = (await _database).clientDao;
    return await dao.findById(id);
  }

  Future<void> saveClient(ClientEntry client) async {
    final uri = Uri.parse('$_supabaseUrl/rest/v1/clients');
    
    try {
      final response = await http.post(
        uri,
        headers: {
          'apikey': _publishableKey, 
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
        body: jsonEncode({
          'name': client.name,
          'phone': client.phone,
          'email': client.email,
          'country_code': client.countryCode,
          'password': client.password,
        }),
      ).timeout(const Duration(seconds: 10));

      final dao = (await _database).clientDao;
      
      if (response.statusCode == 201) {
        final List<dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final serverClient = ClientEntry.fromJson(responseData.first as Map<String, dynamic>);
        await dao.insertClient(serverClient);
      } else {
        print('Error de Supabase: ${response.statusCode} - ${response.body}');
        await dao.insertClient(client);
      }
    } catch (e) {
      print('Sin conexión. Guardando cliente localmente: $e');
      final dao = (await _database).clientDao;
      await dao.insertClient(client);
    }
  }

  Future<void> updateClient(ClientEntry client) async {
    if (client.id != null) {
      final uri = Uri.parse('$_supabaseUrl/rest/v1/clients?id=eq.${client.id}');
      try {
        final response = await http.patch(
          uri,
          headers: {
            'apikey': _publishableKey, 
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'name': client.name,
            'phone': client.phone,
            'email': client.email,
            'country_code': client.countryCode,
            'password': client.password,
          }),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode >= 400) {
           print('Error actualizando en Supabase: ${response.body}');
        }
      } catch (e) {
        print('Sin conexión. Actualizando cliente solo en modo local: $e');
      }
    }

    final dao = (await _database).clientDao;
    await dao.updateClient(client);
  }

  Future<void> removeClient(ClientEntry client) async {
    if (client.id != null) {
      final uri = Uri.parse('$_supabaseUrl/rest/v1/clients?id=eq.${client.id}');
      try {
        final response = await http.delete(
          uri,
          headers: {'apikey': _publishableKey},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode >= 400) {
           print('Error borrando en Supabase: ${response.body}');
        }
      } catch (e) {
        print('Sin conexión. Borrando cliente solo en modo local: $e');
      }
    }

    final dao = (await _database).clientDao;
    await dao.deleteClient(client);
  }
}