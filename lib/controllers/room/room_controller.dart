import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:machuco/database/repository/room/room_sync_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/models/room/room_service.dart';
import 'package:machuco/database/repository/room/room_dao.dart';
import 'package:machuco/database/repository/room/room_service_repository.dart';
import 'package:machuco/service/room/supabase_room_config.dart';
import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// Conecta la presentación del maestro con su repositorio.
class RoomController extends ChangeNotifier {
  RoomController({
    required RoomDao roomDao,
    required RoomServiceRepository serviceRepository,
    required LocalPreferencesService preferences,
    RoomSyncRepository? syncRepository,
  }) : this._(roomDao, serviceRepository, preferences, syncRepository);

  RoomController._(
    this._roomDao,
    this._serviceRepository,
    this._preferences,
    this._syncRepository,
  );

  factory RoomController.fromEnvironment({
    AppDatabase? database,
    String? motelId,
    String? ownerId,
  }) {
    final appDatabaseFuture = database == null
        ? AppDatabaseProvider.database
        : Future.value(database);
    final roomDao = RoomDao(
      () async => (await appDatabaseFuture).database as sqflite.Database,
    );
    return RoomController(
      roomDao: roomDao,
      syncRepository: RoomSyncRepository(
        dao: roomDao,
        firestore: FirebaseFirestore.instance,
        auth: FirebaseAuth.instance,
        motelId: motelId,
        ownerId: ownerId,
      ),
      serviceRepository: RoomServiceRepository(
        baseUrl: SupabaseRoomConfig.baseUrl,
        apiKey: SupabaseRoomConfig.apiKey,
        roomDao: roomDao,
      ),
      preferences: SharedPreferencesLocalService(namespace: 'rooms'),
    );
  }

  final RoomDao _roomDao;
  final RoomSyncRepository? _syncRepository;
  Timer? _syncTimer;
  String? syncError;

  Future<void> synchronize() async {
    if (_syncRepository == null || _disposed) return;
    try {
      await _syncRepository.sync();
      syncError = null;
      _rooms = await _roomDao.getRooms();
      _roomTypes = await _roomDao.getRoomTypes();
    } catch (error) {
      syncError =
          'Cambios guardados en este dispositivo. Sincronización pendiente: $error';
    }
    notifyListeners();
  }

  final RoomServiceRepository _serviceRepository;
  final LocalPreferencesService _preferences;
  List<RoomVisualData> _rooms = const [];
  List<RoomTypeData> _roomTypes = const [];
  List<RoomService> _includedServices = const [];
  bool _isLoadingServices = false;
  bool _disposed = false;

  @override
  void dispose() {
    _syncTimer?.cancel();
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  String? _servicesError;
  String? databasePath;

  List<RoomVisualData> get rooms => List.unmodifiable(_rooms);
  List<RoomTypeData> get roomTypes => List.unmodifiable(_roomTypes);
  List<RoomService> get includedServices =>
      List.unmodifiable(_includedServices);
  bool get isLoadingServices => _isLoadingServices;
  String? get servicesError => _servicesError;

  Future<void> loadLocalData() async {
    databasePath = await _roomDao.getDatabasePath();
    debugPrint('Room SQLite: $databasePath');
    await _roomDao.removeLegacyMockData();
    _rooms = await _roomDao.getRooms();
    _roomTypes = await _roomDao.getRoomTypes();
    notifyListeners();
    if (_syncRepository != null) {
      _syncTimer ??= Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(synchronize()),
      );
      unawaited(synchronize());
    }
  }

  Future<void> saveRooms(List<RoomVisualData> rooms) async {
    if (_syncRepository != null) {
      for (final room in rooms) {
        await upsertRoom(room);
      }
      return;
    }
    await _roomDao.saveRooms(rooms);
    _rooms = List.of(rooms);
    notifyListeners();
  }

  Future<void> upsertRoom(RoomVisualData room) async {
    if (_syncRepository == null) {
      await _roomDao.upsertRoom(room);
    } else {
      await _syncRepository.saveRoom(room);
      unawaited(synchronize());
    }
    final index = _rooms.indexWhere((item) => item.id == room.id);
    if (index == -1) {
      _rooms = [..._rooms, room];
    } else {
      _rooms = [..._rooms]..[index] = room;
    }
    notifyListeners();
  }

  Future<void> deleteRoom(String roomId) async {
    if (_syncRepository == null) {
      await _roomDao.deleteRoom(roomId);
    } else {
      await _syncRepository.deleteRoom(
        _rooms.firstWhere((r) => r.id == roomId),
      );
      unawaited(synchronize());
    }
    _rooms = _rooms.where((room) => room.id != roomId).toList();
    notifyListeners();
  }

  Future<void> saveRoomTypes(List<RoomTypeData> roomTypes) async {
    if (_syncRepository != null) {
      for (final type in roomTypes) {
        await upsertRoomType(type);
      }
      return;
    }
    await _roomDao.saveRoomTypes(roomTypes);
    _roomTypes = List.of(roomTypes);
    notifyListeners();
  }

  Future<void> upsertRoomType(RoomTypeData roomType) async {
    if (_syncRepository == null) {
      await _roomDao.upsertRoomType(roomType);
    } else {
      await _syncRepository.saveType(roomType);
      unawaited(synchronize());
    }
    final index = _roomTypes.indexWhere((item) => item.id == roomType.id);
    if (index == -1) {
      _roomTypes = [..._roomTypes, roomType];
    } else {
      _roomTypes = [..._roomTypes]..[index] = roomType;
    }
    notifyListeners();
  }

  Future<void> deleteRoomType(String typeId) async {
    if (_syncRepository == null) {
      await _roomDao.deleteRoomType(typeId);
    } else {
      await _syncRepository.deleteType(
        _roomTypes.firstWhere((t) => t.id == typeId),
      );
      unawaited(synchronize());
    }
    _roomTypes = _roomTypes.where((type) => type.id != typeId).toList();
    notifyListeners();
  }

  Future<void> loadIncludedServices({bool forceRefresh = false}) async {
    _isLoadingServices = true;
    _servicesError = null;
    notifyListeners();

    try {
      _includedServices = await _serviceRepository.getIncludedServices(
        forceRefresh: forceRefresh,
      );
      await _preferences.setInt(
        'lastServiceSyncEpoch',
        DateTime.now().millisecondsSinceEpoch,
      );
    } on RoomServiceRepositoryException catch (error) {
      _servicesError = error.message;
    } finally {
      _isLoadingServices = false;
      notifyListeners();
    }
  }
}
