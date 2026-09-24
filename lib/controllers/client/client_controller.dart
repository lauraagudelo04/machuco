import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:machuco/models/client/client.dart';

class ClientController extends ChangeNotifier {
  ClientController._() {
    _allClients = List.of(_initialMockClients);
    loadCurrentClient();
  }
  static final ClientController instance = ClientController._();

  static const _clientKey = 'current_client_data';
  
  late List<Client> _allClients;
  Client? _currentClient;
  bool _isLoading = true;
  String? _errorMessage;

  Client? get currentClient => _currentClient;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Client> get allClients => List.unmodifiable(_allClients);

  Future<void> loadCurrentClient() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final clientJson = prefs.getString(_clientKey);
      
      if (clientJson != null) {
        final data = jsonDecode(clientJson) as Map<String, dynamic>;
        _currentClient = Client(
          id: data['id'] as String,
          name: data['name'] as String,
          phone: data['phone'] as String,
          email: data['email'] as String,
          password: data['password'] as String,
        );
        // Sincronizamos el directorio del propietario con los datos locales guardados
        _syncToDirectory(_currentClient!);
      } else {
        // Mock por defecto si no hay nada guardado
        _currentClient = _allClients.first;
      }
    } catch (e) {
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
  }) async {
    if (_currentClient == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 600)); // Simula red

      final updatedClient = _currentClient!.copyWith(
        name: name,
        phone: phone,
        password: password,
      );

      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_clientKey, jsonEncode({
        'id': updatedClient.id,
        'name': updatedClient.name,
        'phone': updatedClient.phone,
        'email': updatedClient.email,
        'password': updatedClient.password,
      }));

      if (success) {
        _currentClient = updatedClient;
        // Actualizamos la lista global para que el Propietario vea el cambio instantáneamente
        _syncToDirectory(updatedClient);
        return true;
      } else {
        throw Exception('Error persistiendo los datos');
      }
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

  Client? getById(String id) {
    for (final client in _allClients) {
      if (client.id == id) return client;
    }
    return null;
  }

  void unlink(Client client) {
    _allClients.removeWhere((c) => c.id == client.id);
    notifyListeners();
  }

  static final List<Client> _initialMockClients = [
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
}
