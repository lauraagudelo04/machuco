import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Rutas actualizadas hacia la carpeta database
import 'package:machuco/database/model/client/client.dart';
import 'package:machuco/database/repository/client/client_repository.dart';

import 'package:machuco/database/model/phone_country_code/phone_country_code.dart';
import 'package:machuco/database/repository/phone_country_code/phone_country_code_repository.dart';

class ClientController extends ChangeNotifier {
  ClientController._();
  static final ClientController instance = ClientController._();

  static const _clientKey = 'current_client_data';

  late ClientRepository _clientRepo;
  late CountryCodeRepository _countryCodeRepo;

  List<Client> _allClients = [];
  Client? _currentClient;
  List<PhoneCountryCode> _countryCodes = [];
  
  bool _isLoading = true;
  String? _errorMessage;

  Client? get currentClient => _currentClient;
  List<Client> get allClients => List.unmodifiable(_allClients);
  List<PhoneCountryCode> get countryCodes => List.unmodifiable(_countryCodes);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void init(CountryCodeRepository countryCodeRepo, {ClientRepository? clientRepo}) {
    _clientRepo = clientRepo ?? ClientRepository();
    _countryCodeRepo = countryCodeRepo;
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _countryCodes = await _countryCodeRepo.getActiveCountryCodes();

      _allClients = await _clientRepo.getAllClients();

      final prefs = await SharedPreferences.getInstance();
      final clientJson = prefs.getString(_clientKey);
      
      if (clientJson != null) {
        final data = jsonDecode(clientJson) as Map<String, dynamic>;
        _currentClient = Client(
          // 3. El ID ahora se extrae como int?
          id: data['id'] as int?, 
          name: data['name'] as String,
          phone: data['phone'] as String,
          email: data['email'] as String,
          password: data['password'] as String,
          // 4. Soporte para la clave legacy 'countryCode' y la nueva 'country_code'
          countryCode: (data['countryCode'] ?? data['country_code'] ?? '+57') as String,
        );
        _syncToDirectory(_currentClient!);
      } else if (_allClients.isNotEmpty) {
        // Fallback si hay clientes en Floor pero no hay sesión guardada
        _currentClient = _allClients.first;
      }
    } catch (e, stacktrace) {
      print('CRÍTICO - Error cargando perfil: $e'); // Añade esto
      print(stacktrace); // Esto te dirá la línea exacta del fallo
      _errorMessage = 'No pudimos cargar la información de tu perfil.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateCurrentClient({
    required String name,
    required String phone,
    required String password,
    required String countryCode,
  }) async {
    if (_currentClient == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedClient = _currentClient!.copyWith(
        name: name,
        phone: phone,
        password: password,
        countryCode: countryCode,
      );

      // 1. Guardar sesión activa en SharedPreferences (usando toJson() del modelo)
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_clientKey, jsonEncode(updatedClient.toJson()));

      if (!success) throw Exception('Error guardando en SharedPreferences');

      // 2. Actualizar registro en la base de datos local (Floor)
      await _clientRepo.updateClient(updatedClient);

      // 3. Actualizar estado en memoria
      _currentClient = updatedClient;
      _syncToDirectory(updatedClient);
      
      return true;
    } catch (e) {
      _errorMessage = 'No fue posible actualizar el perfil. Intenta de nuevo.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _syncToDirectory(Client updatedClient) {
    final index = _allClients.indexWhere((c) => c.id == updatedClient.id);
    if (index != -1) {
      _allClients[index] = updatedClient;
    } else {
      _allClients.insert(0, updatedClient);
    }
  }

  List<Client> search(String query) {
    if (query.isEmpty) return List.unmodifiable(_allClients);
    final lower = query.toLowerCase();
    return _allClients
        .where((c) =>
            c.name.toLowerCase().contains(lower) ||
            c.email.toLowerCase().contains(lower))
        .toList();
  }

  // 5. El parámetro ID ahora es int
  Client? getById(int id) {
    for (final client in _allClients) {
      if (client.id == id) return client;
    }
    return null;
  }

  void unlink(Client client) async {
    // Eliminar de memoria
    _allClients.removeWhere((c) => c.id == client.id);
    
    // Eliminar de Floor
    await _clientRepo.removeClient(client);

    // Si se elimina el usuario actual, limpiar SharedPreferences
    if (_currentClient?.id == client.id) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clientKey);
      _currentClient = null;
    }
    
    notifyListeners();
  }
}