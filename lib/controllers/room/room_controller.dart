import 'package:flutter/foundation.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/models/room/room_service.dart';
import 'package:machuco/repositories/room/room_dao.dart';
import 'package:machuco/repositories/room/room_service_repository.dart';
import 'package:machuco/service/room/supabase_room_config.dart';
import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

/// Conecta la presentación del maestro con su repositorio.
class RoomController extends ChangeNotifier {
  RoomController({
    required RoomDao roomDao,
    required RoomServiceRepository serviceRepository,
    required LocalPreferencesService preferences,
  }) : this._(roomDao, serviceRepository, preferences);

  RoomController._(this._roomDao, this._serviceRepository, this._preferences);

  factory RoomController.fromEnvironment({AppDatabase? database}) {
    final appDatabase = database ?? AppDatabase();
    return RoomController(
      roomDao: appDatabase.roomDao,
      serviceRepository: RoomServiceRepository(
        baseUrl: SupabaseRoomConfig.baseUrl,
        apiKey: SupabaseRoomConfig.apiKey,
        roomDao: appDatabase.roomDao,
      ),
      preferences: SharedPreferencesLocalService(namespace: 'rooms'),
    );
  }

  final RoomDao _roomDao;
  final RoomServiceRepository _serviceRepository;
  final LocalPreferencesService _preferences;
  List<RoomVisualData> _rooms = const [];
  List<RoomTypeData> _roomTypes = const [];
  List<RoomService> _includedServices = const [];
  bool _isLoadingServices = false;
  String? _servicesError;

  List<RoomVisualData> get rooms => List.unmodifiable(_rooms);
  List<RoomTypeData> get roomTypes => List.unmodifiable(_roomTypes);
  List<RoomService> get includedServices =>
      List.unmodifiable(_includedServices);
  bool get isLoadingServices => _isLoadingServices;
  String? get servicesError => _servicesError;

  Future<void> loadLocalData() async {
    _rooms = await _roomDao.getRooms();
    _roomTypes = await _roomDao.getRoomTypes();
    notifyListeners();
  }

  Future<void> saveRooms(List<RoomVisualData> rooms) async {
    await _roomDao.saveRooms(rooms);
    _rooms = List.of(rooms);
    notifyListeners();
  }

  Future<void> upsertRoom(RoomVisualData room) async {
    await _roomDao.upsertRoom(room);
    final index = _rooms.indexWhere((item) => item.id == room.id);
    if (index == -1) {
      _rooms = [..._rooms, room];
    } else {
      _rooms = [..._rooms]..[index] = room;
    }
    notifyListeners();
  }

  Future<void> deleteRoom(String roomId) async {
    await _roomDao.deleteRoom(roomId);
    _rooms = _rooms.where((room) => room.id != roomId).toList();
    notifyListeners();
  }

  Future<void> saveRoomTypes(List<RoomTypeData> roomTypes) async {
    await _roomDao.saveRoomTypes(roomTypes);
    _roomTypes = List.of(roomTypes);
    notifyListeners();
  }

  Future<void> upsertRoomType(RoomTypeData roomType) async {
    await _roomDao.upsertRoomType(roomType);
    final index = _roomTypes.indexWhere((item) => item.id == roomType.id);
    if (index == -1) {
      _roomTypes = [..._roomTypes, roomType];
    } else {
      _roomTypes = [..._roomTypes]..[index] = roomType;
    }
    notifyListeners();
  }

  Future<void> deleteRoomType(String typeId) async {
    await _roomDao.deleteRoomType(typeId);
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
