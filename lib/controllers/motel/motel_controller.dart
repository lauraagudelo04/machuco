import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/motel/motel_repository.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/service/phone_country_code/supabase_phone_country_code_config.dart';

class MotelController {
  MotelController({MotelRepository? repository}) : _repository = repository;

  factory MotelController.persistent() {
    return MotelController(
      repository: MotelRepository(
        baseUrl: SupabasePhoneCountryCodeConfig.baseUrl,
        apiKey: SupabasePhoneCountryCodeConfig.apiKey,
        daoProvider: () async {
          final db = await AppDatabaseProvider.database;
          return db.motelDao;
        },
      ),
    );
  }

  final MotelRepository? _repository;

  static final List<Motel> _mockDatabase = [
    Motel(
      id: '1',
      ownerId: 'owner-1020304050',
      name: 'Motel Paraíso Élite',
      email: 'admin@paraisoelite.com',
      roomCount: 15,
      nit: '900123456-1',
      address: 'Calle 123 # 45-67, Rionegro',
      phone: '3001234567',
      description:
          'Un espacio discreto y elegante con acabados de lujo, ideal para salir de la rutina y disfrutar en pareja.',
      generalLocation: 'Rionegro - Zona Rosa',
      paymentMethods: ['Efectivo', 'Nequi', 'Tarjeta'],
      imageUrls: ['url_imagen_1.jpg'],
      isAvailable: true,
    ),
    Motel(
      id: '2',
      ownerId: 'owner-1020304050',
      name: 'Motel El Edén',
      email: 'reservas@eleden.com',
      roomCount: 20,
      nit: '900987654-2',
      address: 'Avenida Llanogrande # 12-34',
      phone: '3109876543',
      description:
          'Cabañas exclusivas rodeadas de naturaleza con la mayor privacidad y servicios de primera clase.',
      generalLocation: 'Llanogrande',
      paymentMethods: ['Efectivo', 'Transferencia'],
      imageUrls: ['url_imagen_2.jpg'],
      isAvailable: true,
    ),
    Motel(
      id: '3',
      ownerId: 'owner-900123456',
      name: 'Motel Eclipse',
      email: 'contacto@moteleclipse.com',
      roomCount: 30,
      nit: '900123456-3',
      address: 'Carrera 7 # 89-01, Rionegro',
      phone: '3119876543',
      description:
          'Económico y acogedor. El mejor servicio al mejor precio del sector.',
      generalLocation: 'Rionegro - Centro',
      paymentMethods: ['Efectivo'],
      imageUrls: [],
      isAvailable: true,
    ),
  ];

  Future<List<Motel>> getMyMotels() async {
    if (_repository == null) {
      await Future.delayed(const Duration(seconds: 1));
      const currentLoggedInUserId = 'owner-1020304050';
      return _mockDatabase
          .where((motel) => motel.ownerId == currentLoggedInUserId)
          .toList();
    }
    final motels = await _repository.getMotels();
    const currentLoggedInUserId = 'owner-1020304050';
    return motels.where((motel) => motel.ownerId == currentLoggedInUserId).toList();
  }

  Future<List<Motel>> getMotelsByOwnerId(String ownerId) async {
    if (_repository == null) {
      await Future.delayed(const Duration(milliseconds: 800));
      return _mockDatabase.where((motel) => motel.ownerId == ownerId).toList();
    }
    final motels = await _repository.getMotels();
    return motels.where((motel) => motel.ownerId == ownerId).toList();
  }

  Future<List<Motel>> getRecommendedMotels() async {
    if (_repository == null) {
      await Future.delayed(const Duration(seconds: 1));
      return _mockDatabase.where((motel) => motel.isAvailable).toList();
    }
    final motels = await _repository.getMotels();
    return motels.where((motel) => motel.isAvailable).toList();
  }

  Future<List<Motel>> getAllMotels() async {
    if (_repository == null) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _mockDatabase;
    }
    return _repository.getMotels();
  }

  Future<Motel?> getMotelById(String id) async {
    if (_repository == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      return _mockDatabase.cast<Motel?>().firstWhere(
            (motel) => motel?.id == id,
            orElse: () => null,
          );
    }
    final motels = await _repository.getMotels();
    for (final motel in motels) {
      if (motel.id == id) return motel;
    }
    return null;
  }

  Future<void> addMotel(Motel newMotel) async {
    if (_repository == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      _mockDatabase.add(newMotel);
      return;
    }
    await _repository.addMotel(newMotel);
  }

  Future<void> updateMotel(Motel updatedMotel) async {
    if (_repository == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      final index = _mockDatabase.indexWhere((m) => m.id == updatedMotel.id);
      if (index != -1) {
        _mockDatabase[index] = updatedMotel;
      }
      return;
    }
    await _repository.updateMotel(updatedMotel);
  }

  Future<void> toggleMotelStatus(String motelId) async {
    if (_repository == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final index = _mockDatabase.indexWhere((m) => m.id == motelId);
      if (index != -1) {
        final current = _mockDatabase[index];
        _mockDatabase[index] = Motel(
          id: current.id,
          ownerId: current.ownerId,
          name: current.name,
          email: current.email,
          roomCount: current.roomCount,
          nit: current.nit,
          address: current.address,
          phone: current.phone,
          description: current.description,
          generalLocation: current.generalLocation,
          paymentMethods: current.paymentMethods,
          imageUrls: current.imageUrls,
          isAvailable: !current.isAvailable,
        );
      }
      return;
    }
    final motels = await _repository.getMotels();
    Motel? current;
    for (final motel in motels) {
      if (motel.id == motelId) {
        current = motel;
        break;
      }
    }
    if (current == null) return;
    await _repository.setAvailability(motelId, !current.isAvailable);
  }
}