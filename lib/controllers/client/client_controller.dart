import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/phone_country_code/phone_country_code.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/database/repository/phone_country_code/supabase_phone_country_code_repository.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/client/client_model.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/password_change_service.dart';
import 'package:machuco/service/phone_country_code/supabase_phone_country_code_config.dart';

class ClientController extends ChangeNotifier {
  ClientController._({
    PasswordChangeService? passwordChangeService,
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _passwordChangeService =
           passwordChangeService ?? FirebasePasswordChangeService(),
       _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  static final ClientController instance = ClientController._();

  final PasswordChangeService _passwordChangeService;
  final Future<SharedPreferences> Function() _prefsProvider;

  static const String _profileCachePrefix = 'client_profile_cache_';
  static const String _lastSearchQueryKey = 'client_last_search_query';

  late PhoneCountryCodeRepository _phoneCountryCodeRepo;
  late UserProfileRepository _userProfileRepo;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ClientModel? _currentClient;
  List<ClientModel> _allClients = [];
  List<PhoneCountryCode> _countryCodes = [];
  String _lastSearchQuery = '';
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  ClientModel? get currentClient => _currentClient;
  List<ClientModel> get allClients => List.unmodifiable(_allClients);
  List<PhoneCountryCode> get countryCodes => List.unmodifiable(_countryCodes);
  String get lastSearchQuery => _lastSearchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get canChangePassword {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'password');
  }

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
        daoProvider: () async =>
            (await AppDatabaseProvider.database).phoneCountryCodeDao,
      );
      _userProfileRepo = FirestoreUserProfileRepository();
      _countryCodes = await _phoneCountryCodeRepo.getCountryCodes();
      _isInitialized = true;
    }
  }

  Future<void> _saveProfileToPrefs(ClientModel client) async {
    final uid = client.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final prefs = await _prefsProvider();
      await prefs.setString(
        '$_profileCachePrefix$uid',
        jsonEncode(client.toJson()),
      );
    } catch (e) {
      debugPrint('Error guardando perfil en SharedPreferences: $e');
    }
  }

  Future<ClientModel?> _loadProfileFromPrefs(String uid) async {
    try {
      final prefs = await _prefsProvider();
      final raw = prefs.getString('$_profileCachePrefix$uid');
      if (raw == null || raw.isEmpty) return null;
      return ClientModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error leyendo perfil desde SharedPreferences: $e');
      return null;
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
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        _currentClient = null;
        return;
      }

      final cached = await _loadProfileFromPrefs(firebaseUser.uid);
      if (cached != null) {
        _currentClient = cached;
        _isLoading = false;
        notifyListeners();
      }

      await _initRepositories();
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
        await _saveProfileToPrefs(_currentClient!);
      }
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      // Solo reporta error si tampoco había datos en SharedPreferences
      if (_currentClient == null) {
        _errorMessage = 'No pudimos cargar la información de tu perfil.';
      }
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
          .where((doc) {
            final data = doc.data();
            final status = (data['status'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
            return status != ReservationStatus.cancelled.name &&
                status != ReservationStatus.completed.name;
          })
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

        // `firestore.rules` solo deja a un propietario leer perfiles de
        // clientes: la consulta debe pedirlo explícitamente o se rechaza.
        final usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .where('role', isEqualTo: 'client')
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
      await _saveProfileToPrefs(updatedClientModel);
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
      _errorMessage =
          'Tu cuenta está autenticada con $authProviderName. Debes administrar tu contraseña directamente en esa plataforma.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _passwordChangeService.changePassword(newPassword: newPassword);
      return true;
    } on AuthFailure catch (e) {
      _errorMessage = e.message;
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
    _lastSearchQuery = query;
    _prefsProvider()
        .then((prefs) {
          if (query.trim().isEmpty) {
            prefs.remove(_lastSearchQueryKey);
          } else {
            prefs.setString(_lastSearchQueryKey, query);
          }
        })
        .catchError((e) {
          debugPrint('Error guardando búsqueda en SharedPreferences: $e');
        });

    if (query.trim().isEmpty) return allClients;
    final q = query.toLowerCase().trim();
    return _allClients.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.phone.contains(q);
    }).toList();
  }

  Future<bool> unlink(ClientModel client) async {
    final currentUser = _auth.currentUser;
    final guestId = client.uid;

    if (currentUser == null || guestId == null || guestId.isEmpty) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final reservationsSnapshot = await _firestore
          .collection('reservations')
          .where('ownerId', isEqualTo: currentUser.uid)
          .where('guestId', isEqualTo: guestId)
          .get();

      final batch = _firestore.batch();
      var hasActiveReservations = false;

      for (final doc in reservationsSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase().trim();

        if (status != ReservationStatus.cancelled.name &&
            status != ReservationStatus.completed.name) {
          batch.update(doc.reference, {
            'status': ReservationStatus.cancelled.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          hasActiveReservations = true;
        }
      }

      if (hasActiveReservations) {
        await batch.commit();
      }

      _allClients.removeWhere(
        (c) =>
            (client.id != null && c.id == client.id) ||
            (client.uid != null && c.uid == client.uid),
      );

      return true;
    } catch (e) {
      debugPrint('Error al desvincular el cliente en Firestore: $e');
      _errorMessage = 'No fue posible desvincular al cliente.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
