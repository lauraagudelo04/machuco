import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/phone_country_code/phone_country_code.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/database/repository/phone_country_code/supabase_phone_country_code_repository.dart';
import 'package:machuco/models/client/client_model.dart';
import 'package:machuco/service/phone_country_code/supabase_phone_country_code_config.dart';

class ClientController extends ChangeNotifier {
  ClientController._();
  static final ClientController instance = ClientController._();

  late PhoneCountryCodeRepository _phoneCountryCodeRepo;
  late UserProfileRepository _userProfileRepo;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ClientModel? _currentClient;
  List<ClientModel> _allClients = [];
  List<PhoneCountryCode> _countryCodes = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  ClientModel? get currentClient => _currentClient;
  List<ClientModel> get allClients => List.unmodifiable(_allClients);
  List<PhoneCountryCode> get countryCodes => List.unmodifiable(_countryCodes);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Indica si el usuario autenticado se registró con correo/contraseña.
  bool get canChangePassword {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'password');
  }

  /// Retorna el nombre del proveedor de inicio de sesión social si no usa contraseña.
  String get authProviderName {
    final user = _auth.currentUser;
    if (user == null) return '';

    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return 'Google';
      if (info.providerId == 'github.com') return 'GitHub';
    }
    return 'un proveedor externo';
  }

  Future<void> _initRepositories() async {
    if (!_isInitialized) {
      _phoneCountryCodeRepo = PhoneCountryCodeRepository(
        baseUrl: SupabasePhoneCountryCodeConfig.baseUrl,
        apiKey: SupabasePhoneCountryCodeConfig.apiKey,
        daoProvider: () async => (await AppDatabaseProvider.database).phoneCountryCodeDao,
      );
      _userProfileRepo = FirestoreUserProfileRepository();
      _countryCodes = await _phoneCountryCodeRepo.getCountryCodes();
      _isInitialized = true;
    }
  }

  (String code, String number) _parsePhoneNumber(String fullPhone) {
    String code = '+57';
    String number = fullPhone.trim();

    for (final country in _countryCodes) {
      if (number.startsWith(country.callingCode)) {
        code = country.callingCode;
        number = number.substring(country.callingCode.length).trim();
        break;
      }
    }
    return (code, number);
  }

  Future<void> loadProfileData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _initRepositories();
      final firebaseUser = _auth.currentUser;

      if (firebaseUser != null) {
        final profile = await _userProfileRepo.getProfile(firebaseUser.uid);
        if (profile != null) {
          final (code, phone) = _parsePhoneNumber(profile.phoneNumber);

          _currentClient = ClientModel(
            uid: profile.uid,
            name: profile.fullName,
            phone: phone,
            email: profile.email,
            countryCode: code,
          );
        }
      }
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      _errorMessage = 'No pudimos cargar la información de tu perfil.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAllClients() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _initRepositories();
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        _allClients = [];
        return;
      }

      final reservationsSnapshot = await _firestore
          .collection('reservations')
          .where('ownerId', isEqualTo: currentUser.uid)
          .get();

      final guestIds = reservationsSnapshot.docs
          .map((doc) => doc.data()['guestId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      if (guestIds.isEmpty) {
        _allClients = [];
        return;
      }

      final List<ClientModel> clients = [];

      for (var i = 0; i < guestIds.length; i += 30) {
        final chunk = guestIds.sublist(
          i,
          i + 30 > guestIds.length ? guestIds.length : i + 30,
        );

        final usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in usersSnapshot.docs) {
          final data = doc.data();
          final rawPhone = (data['phoneNumber'] ?? '') as String;
          final (code, phone) = _parsePhoneNumber(rawPhone);

          clients.add(
            ClientModel(
              uid: doc.id,
              name: (data['fullName'] ?? '') as String,
              email: (data['email'] ?? '') as String,
              phone: phone,
              countryCode: code,
            ),
          );
        }
      }

      _allClients = clients;
    } catch (e) {
      debugPrint('Error obteniendo clientes vinculados de Firestore: $e');
      _errorMessage = 'No pudimos cargar el listado de clientes.';
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
        final fullPhoneNumber = '$countryCode$phone'.replaceAll(' ', '');
        await _userProfileRepo.updateProfile(
          uid: firebaseUser.uid,
          fullName: name,
          phoneNumber: fullPhoneNumber,
        );
      }

      _currentClient = updatedClientModel;
      return true;
    } catch (e) {
      _errorMessage = 'No fue posible actualizar el perfil.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!canChangePassword) {
      _errorMessage = 'Tu cuenta está autenticada con $authProviderName. Debes administrar tu contraseña directamente en esa plataforma.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No existe una sesión activa.');
      }

      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      await user.updatePassword(newPassword);

      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _errorMessage = 'La contraseña actual no es correcta.';
      } else if (e.code == 'weak-password') {
        _errorMessage = 'La nueva contraseña debe tener al menos 6 caracteres.';
      } else {
        _errorMessage = e.message ?? 'No se pudo actualizar la contraseña.';
      }
      return false;
    } catch (e) {
      _errorMessage = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
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
        (client.uid != null && c.uid == client.uid));
    notifyListeners();
  }
}