import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/motel/motel_repository.dart';
import 'package:machuco/database/repository/motel/motel_sql_connect_gateway.dart';
import 'package:machuco/database/repository/motel/sql_connect_motel_repository.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/service/firebase/current_user.dart';

/// Lógica de aplicación de moteles.
///
/// Sin repositorio usa datos de ejemplo en memoria (los usan otros módulos y
/// pruebas). [MotelController.persistent] usa Firebase SQL Connect.
class MotelController {
  MotelController({MotelRepository? repository}) : _repository = repository;

  factory MotelController.persistent() {
    return MotelController(
      repository: SqlConnectMotelRepository(
        gateway: GeneratedMotelSqlConnectGateway(),
        daoProvider: () async {
          final db = await AppDatabaseProvider.database;
          return db.motelDao;
        },
        currentUid: () => CurrentUser.uidOrNull,
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

  /// Moteles del propietario autenticado. Con SQL Connect el filtro por
  /// dueño lo aplica el backend con el token de Firebase Auth.
  Future<List<Motel>> getMyMotels() async {
    final repository = _repository;
    if (repository == null) {
      await Future.delayed(const Duration(seconds: 1));
      return _mockDatabase
          .where((motel) => motel.ownerId == _currentOwnerId)
          .toList();
    }
    return repository.getMyMotels();
  }

  /// Signed-in Firebase uid; the demo owner without a session.
  static String get _currentOwnerId =>
      CurrentUser.uidOrNull ?? 'owner-1020304050';

  /// Moteles de un propietario concreto (vista del administrador).
  Future<List<Motel>> getMotelsByOwnerId(String ownerId) async {
    final repository = _repository;
    if (repository == null) {
      await Future.delayed(const Duration(milliseconds: 800));
      return _mockDatabase.where((motel) => motel.ownerId == ownerId).toList();
    }
    final motels = await repository.getMotels();
    return motels.where((motel) => motel.ownerId == ownerId).toList();
  }

  Future<List<Motel>> getRecommendedMotels() async {
    final repository = _repository;
    if (repository == null) {
      await Future.delayed(const Duration(seconds: 1));
      return _mockDatabase.where((motel) => motel.isAvailable).toList();
    }
    return repository.getAvailableMotels();
  }

  Future<List<Motel>> getAllMotels() async {
    final repository = _repository;
    if (repository == null) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _mockDatabase;
    }
    return repository.getMotels();
  }

  Future<Motel?> getMotelById(String id) async {
    final repository = _repository;
    if (repository == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      return _mockDatabase.cast<Motel?>().firstWhere(
        (motel) => motel?.id == id,
        orElse: () => null,
      );
    }
    return repository.getMotelById(id);
  }

  /// El propietario autenticado registra un motel propio.
  Future<Motel> addMotel(Motel newMotel) async {
    final repository = _repository;
    if (repository == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      _mockDatabase.add(newMotel);
      return newMotel;
    }
    return repository.addMyMotel(newMotel);
  }

  /// El administrador registra un motel para `newMotel.ownerId`.
  Future<Motel> adminAddMotel(Motel newMotel) async {
    final repository = _repository;
    if (repository == null) return addMotel(newMotel);
    return repository.addMotelForOwner(newMotel);
  }

  /// El propietario autenticado edita un motel propio.
  Future<Motel> updateMotel(Motel updatedMotel) async {
    final repository = _repository;
    if (repository == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      _replaceInMock(updatedMotel);
      return updatedMotel;
    }
    return repository.updateMyMotel(updatedMotel);
  }

  /// El administrador edita cualquier motel.
  Future<Motel> adminUpdateMotel(Motel updatedMotel) async {
    final repository = _repository;
    if (repository == null) return updateMotel(updatedMotel);
    return repository.updateMotelAsAdmin(updatedMotel);
  }

  /// El propietario autenticado habilita o inhabilita un motel propio.
  Future<void> toggleMotelStatus(String motelId) async {
    final repository = _repository;
    if (repository == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final current = _findInMock(motelId);
      if (current != null) {
        _replaceInMock(current.copyWith(isAvailable: !current.isAvailable));
      }
      return;
    }
    final current = await repository.getMotelById(motelId);
    if (current == null) return;
    await repository.setMyMotelAvailability(motelId, !current.isAvailable);
  }

  /// El administrador habilita o inhabilita cualquier motel.
  Future<Motel?> adminToggleMotelStatus(Motel motel) async {
    final toggled = motel.copyWith(isAvailable: !motel.isAvailable);
    final repository = _repository;
    if (repository == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      _replaceInMock(toggled);
      return toggled;
    }
    return repository.updateMotelAsAdmin(toggled);
  }

  Motel? _findInMock(String id) {
    for (final motel in _mockDatabase) {
      if (motel.id == id) return motel;
    }
    return null;
  }

  void _replaceInMock(Motel motel) {
    final index = _mockDatabase.indexWhere((m) => m.id == motel.id);
    if (index != -1) _mockDatabase[index] = motel;
  }
}
