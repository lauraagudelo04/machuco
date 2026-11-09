import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:machuco/database/repository/room/room_dao.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

/// SQLite conserva los eventos hasta que Firestore confirma su recepción.
class RoomSyncRepository {
  RoomSyncRepository({
    required this.dao,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    RoomRemoteStore? remote,
    String? Function()? currentUserId,
    this.motelId,
    this.ownerId,
  }) : remote =
           remote ??
           FirestoreRoomStore(firestore ?? FirebaseFirestore.instance),
       _currentUserId =
           currentUserId ??
           (() => (auth ?? FirebaseAuth.instance).currentUser?.uid);

  final RoomDao dao;
  final RoomRemoteStore remote;
  final String? Function() _currentUserId;
  final String? motelId;
  final String? ownerId;
  Future<void>? _running;

  String _writer(String motel) {
    final uid = _currentUserId();
    if (uid == null) {
      throw StateError('Inicia sesión para modificar las habitaciones.');
    }
    if (uid != ownerId) {
      throw StateError(
        'La cuenta conectada no es la propietaria de este motel. '
        'Abre un motel de tu cuenta.',
      );
    }
    if (motel != motelId) {
      throw StateError('La habitación o el tipo pertenece a otro motel.');
    }
    return uid;
  }

  Future<void> saveType(RoomTypeData type) => _write(
    FirestoreCollections.roomTypes,
    type.id,
    type.toJson(),
    (dao) => dao.upsertRoomType(type),
  );

  Future<void> saveRoom(RoomVisualData room) => _write(
    FirestoreCollections.rooms,
    room.id,
    room.toJson(),
    (dao) => dao.upsertRoom(room),
  );

  Future<void> deleteRoom(RoomVisualData room) => _write(
    FirestoreCollections.rooms,
    room.id,
    room.toJson(),
    (dao) => dao.deleteRoom(room.id),
    deleted: true,
  );

  Future<void> deleteType(RoomTypeData type) => _write(
    FirestoreCollections.roomTypes,
    type.id,
    type.toJson(),
    (dao) => dao.deleteRoomType(type.id),
    deleted: true,
  );

  Future<void> _write(
    String collection,
    String id,
    Map<String, dynamic> data,
    Future<void> Function(RoomDao) mutate, {
    bool deleted = false,
  }) async {
    final uid = _writer(data['motelId'] as String);
    await dao.mutateAndEnqueue(
      uid: uid,
      collection: collection,
      id: id,
      payload: {...data, 'ownerId': uid, 'deleted': deleted},
      mutate: mutate,
    );
  }

  Future<void> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<void> _sync() async {
    final uid = _currentUserId();
    if (uid == null) return;
    // Procesar en orden mantiene tipos antes de habitaciones y borrados después.
    for (final event in await dao.pendingChanges(uid)) {
      if (_currentUserId() != uid) return;
      final data =
          jsonDecode(event['payload']! as String) as Map<String, dynamic>;
      await remote
          .write(
            event['collection_name']! as String,
            event['document_id']! as String,
            data,
          )
          .timeout(const Duration(seconds: 12));
      await dao.acknowledgeChange(event['sequence']! as int);
    }
    // Exigir servidor evita interpretar un caché vacío como una base remota vacía.
    final remoteTypes = await remote
        .read(FirestoreCollections.roomTypes)
        .timeout(const Duration(seconds: 12));
    final remoteRooms = await remote
        .read(FirestoreCollections.rooms)
        .timeout(const Duration(seconds: 12));
    if (_currentUserId() != uid) return;
    // Importación inicial de los datos SQLite existentes del motel del propietario.
    // Los tombstones también cuentan como existentes: nunca se resucitan.
    if (uid == ownerId && motelId != null) {
      final typeIds = remoteTypes.map((doc) => doc['id'] as String).toSet();
      final roomIds = remoteRooms.map((doc) => doc['id'] as String).toSet();
      for (final type in await dao.getRoomTypes()) {
        if (type.motelId == motelId && !typeIds.contains(type.id)) {
          await saveType(type);
        }
      }
      for (final room in await dao.getRooms()) {
        if (room.motelId == motelId && !roomIds.contains(room.id)) {
          await saveRoom(room);
        }
      }
    }
    await dao.mergeRemote(
      remoteTypes
          .where((d) => d['deleted'] != true)
          .map(RoomTypeData.fromJson)
          .toList(),
      remoteRooms
          .where((d) => d['deleted'] != true)
          .map(RoomVisualData.fromJson)
          .toList(),
      remoteRooms
          .where((d) => d['deleted'] == true)
          .map((d) => d['id'] as String)
          .toList(),
      remoteTypes
          .where((d) => d['deleted'] == true)
          .map((d) => d['id'] as String)
          .toList(),
    );
  }
}

abstract interface class RoomRemoteStore {
  Future<void> write(String collection, String id, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> read(String collection);
}

class FirestoreRoomStore implements RoomRemoteStore {
  FirestoreRoomStore(this.firestore);
  final FirebaseFirestore firestore;

  @override
  Future<void> write(String collection, String id, Map<String, dynamic> data) =>
      firestore.collection(collection).doc(id).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<List<Map<String, dynamic>>> read(String collection) async {
    final snapshot = await firestore
        .collection(collection)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }
}
