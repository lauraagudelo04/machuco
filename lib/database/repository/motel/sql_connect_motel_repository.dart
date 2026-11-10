import 'package:machuco/database/model/motel/motel_entity.dart';
import 'package:machuco/database/repository/motel/motel_dao.dart';
import 'package:machuco/database/repository/motel/motel_firestore_registry.dart';
import 'package:machuco/database/repository/motel/motel_repository.dart';
import 'package:machuco/database/repository/motel/motel_sql_connect_gateway.dart';
import 'package:machuco/models/motel/motel_model.dart';

/// Moteles en Firebase SQL Connect con caché local en SQLite (Floor).
///
/// Lecturas: red primero; si SQL Connect falla se devuelve la caché y, si no
/// hay caché, se lanza [MotelRepositoryException]. Escrituras: siempre
/// requieren red y, si salen bien, actualizan la caché y el registro del
/// motel en Firestore (`motels`) que pueden consultar otros módulos.
class SqlConnectMotelRepository implements MotelRepository {
  SqlConnectMotelRepository({
    required MotelSqlConnectGateway gateway,
    required Future<MotelDao> Function() daoProvider,
    String? Function()? currentUid,
    MotelFirestoreRegistry? firestoreRegistry,
  }) : _gateway = gateway,
       _daoProvider = daoProvider,
       _currentUid = currentUid ?? (() => null),
       _firestoreRegistry = firestoreRegistry;

  final MotelSqlConnectGateway _gateway;
  final Future<MotelDao> Function() _daoProvider;

  /// Si es `null` no se escribe en Firestore (lecturas desde otros módulos).
  final MotelFirestoreRegistry? _firestoreRegistry;

  /// Uid de la sesión; solo se usa para filtrar la caché sin conexión.
  final String? Function() _currentUid;

  static const _readError = 'No fue posible consultar los moteles';

  @override
  Future<List<Motel>> getMotels() =>
      _read(_gateway.listAll, cacheFilter: (_) => true, replaceCache: true);

  @override
  Future<List<Motel>> getMyMotels() {
    final uid = _currentUid();
    return _read(
      _gateway.listMine,
      cacheFilter: (motel) => uid != null && motel.ownerId == uid,
    );
  }

  @override
  Future<List<Motel>> getAvailableMotels() =>
      _read(_gateway.listAvailable, cacheFilter: (motel) => motel.isAvailable);

  @override
  Future<Motel?> getMotelById(String id) async {
    final dao = await _daoProvider();
    try {
      final motel = await _gateway.getById(id);
      if (motel != null) await dao.upsert(MotelEntity.fromModel(motel));
      return motel;
    } catch (error) {
      final cached = await dao.findById(id);
      if (cached != null) return cached.toModel();
      throw MotelRepositoryException(
        sqlConnectErrorMessage(error, fallback: _readError),
      );
    }
  }

  @override
  Future<Motel> addMyMotel(Motel motel) => _write(() async {
    final id = await _gateway.createMine(motel);
    // El dueño real lo fija el backend con el token.
    return motel.copyWith(id: id, ownerId: _currentUid() ?? motel.ownerId);
  }, fallback: 'No fue posible crear el motel');

  @override
  Future<Motel> addMotelForOwner(Motel motel) => _write(
    () async => motel.copyWith(id: await _gateway.createForOwner(motel)),
    fallback: 'No fue posible crear el motel',
  );

  @override
  Future<Motel> updateMyMotel(Motel motel) => _write(() async {
    final updated = await _gateway.updateMine(motel);
    if (updated == 0) {
      throw const MotelRepositoryException(
        'No puedes editar un motel que no es tuyo',
      );
    }
    return motel;
  }, fallback: 'No fue posible actualizar el motel');

  @override
  Future<Motel> updateMotelAsAdmin(Motel motel) => _write(() async {
    await _gateway.updateAsAdmin(motel);
    return motel;
  }, fallback: 'No fue posible actualizar el motel');

  @override
  Future<void> setMyMotelAvailability(String id, bool isAvailable) async {
    final dao = await _daoProvider();
    try {
      final updated = await _gateway.setMineAvailability(id, isAvailable);
      if (updated == 0) {
        throw const MotelRepositoryException(
          'No puedes modificar un motel que no es tuyo',
        );
      }
    } on MotelRepositoryException {
      rethrow;
    } catch (error) {
      throw MotelRepositoryException(
        sqlConnectErrorMessage(
          error,
          fallback: 'No fue posible actualizar el motel',
        ),
      );
    }
    final cached = await dao.findById(id);
    if (cached != null) {
      final motel = cached.toModel().copyWith(isAvailable: isAvailable);
      await dao.upsert(MotelEntity.fromModel(motel));
      await _register(motel);
    }
  }

  /// Copia el motel en `motels/{id}` (Firestore) después de guardar en SQL Connect.
  Future<void> _register(Motel motel) async {
    final registry = _firestoreRegistry;
    if (registry == null) return;
    try {
      await registry.save(motel);
    } catch (_) {
      throw const MotelRepositoryException(
        'El motel se guardó, pero no se pudo registrar para las habitaciones. '
        'Vuelve a guardarlo para reintentar.',
      );
    }
  }

  Future<List<Motel>> _read(
    Future<List<Motel>> Function() remote, {
    required bool Function(Motel) cacheFilter,
    bool replaceCache = false,
  }) async {
    final dao = await _daoProvider();
    try {
      final motels = await remote();
      final entities = motels.map(MotelEntity.fromModel).toList();
      if (replaceCache) {
        await dao.replaceAll(entities);
      } else {
        await dao.upsertAll(entities);
      }
      return motels;
    } catch (error) {
      final cached = (await dao.findAll())
          .map((entity) => entity.toModel())
          .where(cacheFilter)
          .toList();
      if (cached.isNotEmpty) return cached;
      throw MotelRepositoryException(
        sqlConnectErrorMessage(error, fallback: _readError),
      );
    }
  }

  Future<Motel> _write(
    Future<Motel> Function() action, {
    required String fallback,
  }) async {
    final dao = await _daoProvider();
    final Motel motel;
    try {
      motel = await action();
    } on MotelRepositoryException {
      rethrow;
    } catch (error) {
      throw MotelRepositoryException(
        sqlConnectErrorMessage(error, fallback: fallback),
      );
    }
    await dao.upsert(MotelEntity.fromModel(motel));
    await _register(motel);
    return motel;
  }
}
