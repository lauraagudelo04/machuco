import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:machuco/models/client/client_model.dart';
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

  List<ClientModel> _allClients = [];
  ClientModel? _currentClient;
  List<PhoneCountryCode> _countryCodes = [];

  bool _isInitialized = false;
  
  bool _isLoading = false; 
  String? _errorMessage;

  ClientModel? get currentClient => _currentClient;
  List<ClientModel> get allClients => List.unmodifiable(_allClients);
  List<PhoneCountryCode> get countryCodes => List.unmodifiable(_countryCodes);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadData() async {
    if (!_isInitialized) {
      _clientRepo = ClientRepository();
      _countryCodeRepo = CountryCodeRepository();
      _isInitialized = true;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _countryCodes = await _countryCodeRepo.getActiveCountryCodes();
      
      final clientEntries = await _clientRepo.getAllClients();
      
      _allClients = clientEntries.map((entry) => ClientModel(
        id: entry.id,
        name: entry.name,
        phone: entry.phone,
        email: entry.email,
        countryCode: entry.countryCode,
        password: entry.password,
      )).toList();

      final prefs = await SharedPreferences.getInstance();
      final clientJson = prefs.getString(_clientKey);
      
      if (clientJson != null) {
        final data = jsonDecode(clientJson) as Map<String, dynamic>;
        _currentClient = ClientModel(
          id: data['id'] as int?, 
          name: data['name'] as String,
          phone: data['phone'] as String,
          email: data['email'] as String,
          password: data['password'] as String,
          countryCode: (data['countryCode'] ?? data['country_code'] ?? '+57') as String,
        );
        _syncToDirectory(_currentClient!);
      } else if (_allClients.isNotEmpty) {
        _currentClient = _allClients.first;
      } else {
        _currentClient = const ClientModel(
          id: 1,
          name: 'Usuario de Prueba',
          phone: '3001234567',
          email: 'prueba@machuco.com',
          password: 'password123',
          countryCode: '+57',
        );
      }
    } catch (e, stacktrace) {
      print('CRÍTICO - Error cargando perfil: $e'); 
      print(stacktrace);
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
      final updatedClientModel = _currentClient!.copyWith(
        name: name,
        phone: phone,
        password: password,
        countryCode: countryCode,
      );

      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_clientKey, jsonEncode({
         'id': updatedClientModel.id,
         'name': updatedClientModel.name,
         'phone': updatedClientModel.phone,
         'email': updatedClientModel.email,
         'countryCode': updatedClientModel.countryCode,
         'password': updatedClientModel.password,
      }));

      if (!success) throw Exception('Error guardando en SharedPreferences');

      final entryToUpdate = ClientEntry(
        id: updatedClientModel.id,
        name: updatedClientModel.name,
        phone: updatedClientModel.phone,
        email: updatedClientModel.email,
        countryCode: updatedClientModel.countryCode,
        password: updatedClientModel.password,
      );
      await _clientRepo.updateClient(entryToUpdate);

      _currentClient = updatedClientModel;
      _syncToDirectory(updatedClientModel);
      
      return true;
    } catch (e) {
      _errorMessage = 'No fue posible actualizar el perfil. Intenta de nuevo.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _syncToDirectory(ClientModel updatedClient) {
    final index = _allClients.indexWhere((c) => c.id == updatedClient.id);
    if (index != -1) {
      _allClients[index] = updatedClient;
    } else {
      _allClients.insert(0, updatedClient);
    }
  }

  List<ClientModel> search(String query) {
    if (query.isEmpty) return List.unmodifiable(_allClients);
    final lower = query.toLowerCase();
    return _allClients
        .where((c) =>
            c.name.toLowerCase().contains(lower) ||
            c.email.toLowerCase().contains(lower))
        .toList();
  }

  ClientModel? getById(int id) {
    for (final client in _allClients) {
      if (client.id == id) return client;
    }
    return null;
  }

  void unlink(ClientModel client) async {
    _allClients.removeWhere((c) => c.id == client.id);
    
    final entryToDelete = ClientEntry(
        id: client.id,
        name: client.name,
        phone: client.phone,
        email: client.email,
        countryCode: client.countryCode,
        password: client.password,
    );
    await _clientRepo.removeClient(entryToDelete);

    if (_currentClient?.id == client.id) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clientKey);
      _currentClient = null;
    }
    
    notifyListeners();
  }
}