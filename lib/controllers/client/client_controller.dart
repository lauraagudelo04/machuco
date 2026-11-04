import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:machuco/database/model/client/client.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/database/repository/client/client_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/models/client/client_model.dart';
import 'package:machuco/database/repository/auth/auth_catalog_repository.dart';

class ClientController extends ChangeNotifier {
  ClientController._();
  static final ClientController instance = ClientController._();
  static const _clientKey = 'current_client_data';

  late ClientRepository _clientRepo;
  late AuthCatalogRepository _authCatalogRepo;
  late UserProfileRepository _userProfileRepo;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<ClientModel> _allClients = [];
  ClientModel? _currentClient;
  List<CountryPhoneCode> _countryCodes = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  ClientModel? get currentClient => _currentClient;
  List<ClientModel> get allClients => List.unmodifiable(_allClients);
  List<CountryPhoneCode> get countryCodes => List.unmodifiable(_countryCodes);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadData() async {
    if (!_isInitialized) {
      _clientRepo = ClientRepository();
      _authCatalogRepo = AuthCatalogRepository.fromEnvironment();
      _userProfileRepo = FirestoreUserProfileRepository();
      _isInitialized = true;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _countryCodes = await _authCatalogRepo.getCountryPhoneCodes();
      final firebaseUser = _auth.currentUser;

      if (firebaseUser != null) {
        final profile = await _userProfileRepo.getProfile(firebaseUser.uid);
        if (profile != null) {
          _currentClient = ClientModel(
            name: profile.fullName,
            phone: profile.phoneNumber,
            email: profile.email,
            countryCode: '+57',
          );
          await _saveToSharedPreferences(_currentClient!);
        }
      }

      if (_currentClient == null) {
        final prefs = await SharedPreferences.getInstance();
        final clientJson = prefs.getString(_clientKey);
        if (clientJson != null) {
          final data = jsonDecode(clientJson) as Map<String, dynamic>;
          _currentClient = ClientModel(
            id: data['id'] as int?,
            name: data['name'] as String,
            phone: data['phone'] as String,
            email: data['email'] as String,
            countryCode: (data['countryCode'] ?? data['country_code'] ?? '+57') as String,
          );
        }
      }
    } catch (e) {
      debugPrint('Error cargando perfil cliente de Firebase: $e');
      _errorMessage = 'No pudimos cargar la información de tu perfil.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerClient({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String countryCode,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) throw Exception('No se pudo generar el usuario.');

      final fullPhoneNumber = '$countryCode$phone';

      final userProfile = UserProfile(
        uid: uid,
        fullName: name,
        email: email,
        phoneNumber: fullPhoneNumber,
        role: RegisteredUserRole.client,
        accountStatus: initialAccountStatusFor(RegisteredUserRole.client),
      );
      await _userProfileRepo.createProfile(userProfile);

      final clientModel = ClientModel(
        name: name,
        phone: phone,
        email: email,
        countryCode: countryCode,
      );

      final entry = ClientEntry(
        name: name,
        phone: phone,
        email: email,
        countryCode: countryCode,
      );
      await _clientRepo.saveClient(entry);

      _currentClient = clientModel;
      await _saveToSharedPreferences(clientModel);

      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Error durante el registro.';
      return false;
    } catch (e) {
      _errorMessage = 'Ocurrió un error inesperado al registrarte.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateCurrentClient({
    required String name,
    required String phone,
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
        countryCode: countryCode,
      );

      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await _userProfileRepo.updateProfile(
          uid: firebaseUser.uid,
          fullName: name,
          phoneNumber: '$countryCode$phone',
        );
      }

      await _saveToSharedPreferences(updatedClientModel);

      // 3. Guardar en SQLite local
      final entryToUpdate = ClientEntry(
        id: updatedClientModel.id,
        name: updatedClientModel.name,
        phone: updatedClientModel.phone,
        email: updatedClientModel.email,
        countryCode: updatedClientModel.countryCode,
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

  Future<void> _saveToSharedPreferences(ClientModel client) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clientKey, jsonEncode({
      'id': client.id,
      'name': client.name,
      'phone': client.phone,
      'email': client.email,
      'countryCode': client.countryCode,
    }));
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
    if (query.trim().isEmpty) return allClients;
    final q = query.toLowerCase().trim();
    return _allClients.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.phone.contains(q);
    }).toList();
  }

  void unlink(ClientModel client) {
    _allClients.removeWhere((c) => 
      (client.id != null && c.id == client.id) || 
      (client.uid != null && c.uid == client.uid)
    );
    notifyListeners();
  }
}