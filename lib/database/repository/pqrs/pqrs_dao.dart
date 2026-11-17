import 'package:floor/floor.dart';
import 'package:machuco/database/model/pqrs/pqrs_cache_entry.dart';
import 'package:machuco/database/model/pqrs/pqrs_outbox_entry.dart';

/// Local access for the PQRS cache and the queue of pending actions.
@dao
abstract class PqrsDao {
  // --- Cache of pqrs and traces (Firestore copy) ---------------------------

  @Query('SELECT * FROM pqrs_cache ORDER BY createdAt DESC')
  Future<List<PqrsCacheEntry>> findAllCached();

  @Query('SELECT * FROM pqrs_cache WHERE id = :id')
  Future<PqrsCacheEntry?> findCachedById(String id);

  @Query(
    'SELECT * FROM pqrs_cache WHERE clientId = :clientId '
    'ORDER BY createdAt DESC',
  )
  Future<List<PqrsCacheEntry>> findCachedByClient(String clientId);

  @Query(
    'SELECT * FROM pqrs_cache WHERE ownerId = :ownerId '
    'ORDER BY createdAt DESC',
  )
  Future<List<PqrsCacheEntry>> findCachedByOwner(String ownerId);

  @Query(
    'SELECT * FROM pqrs_trace_cache WHERE pqrsId = :pqrsId '
    'ORDER BY createdAt ASC',
  )
  Future<List<PqrsTraceCacheEntry>> findCachedTraces(String pqrsId);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> upsertAllCached(List<PqrsCacheEntry> requests);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> upsertAllTraces(List<PqrsTraceCacheEntry> traces);

  @Query('DELETE FROM pqrs_cache')
  Future<void> deleteAllCached();

  @Query('DELETE FROM pqrs_trace_cache')
  Future<void> deleteAllTraces();

  @Query('DELETE FROM pqrs_trace_cache WHERE pqrsId = :pqrsId')
  Future<void> deleteTracesOf(String pqrsId);

  /// Replaces the whole cache with the last full read (like `MotelDao`). The
  /// outbox is not touched.
  @transaction
  Future<void> replaceAll(
    List<PqrsCacheEntry> requests,
    List<PqrsTraceCacheEntry> traces,
  ) async {
    await deleteAllCached();
    await deleteAllTraces();
    await upsertAllCached(requests);
    await upsertAllTraces(traces);
  }

  /// Replaces only the traces of one request (after reading its detail).
  @transaction
  Future<void> replaceTracesOf(
    String pqrsId,
    List<PqrsTraceCacheEntry> traces,
  ) async {
    await deleteTracesOf(pqrsId);
    await upsertAllTraces(traces);
  }

  // --- Outbox (pending actions) -------------------------------------------

  @Query('SELECT * FROM pqrs_outbox ORDER BY createdAt ASC')
  Future<List<PqrsOutboxEntry>> findOutbox();

  @Query(
    'SELECT * FROM pqrs_outbox WHERE syncStatus = :status '
    'ORDER BY createdAt ASC',
  )
  Future<List<PqrsOutboxEntry>> findOutboxByStatus(String status);

  @Query(
    'SELECT * FROM pqrs_outbox WHERE pqrsId = :pqrsId ORDER BY createdAt ASC',
  )
  Future<List<PqrsOutboxEntry>> findOutboxOf(String pqrsId);

  @Query('SELECT * FROM pqrs_outbox WHERE id = :id')
  Future<PqrsOutboxEntry?> findOutboxById(String id);

  @Query(
    'SELECT * FROM pqrs_outbox_photo WHERE outboxId = :outboxId ORDER BY id',
  )
  Future<List<PqrsOutboxPhotoEntry>> findOutboxPhotos(String outboxId);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertOutbox(PqrsOutboxEntry entry);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertOutboxPhotos(List<PqrsOutboxPhotoEntry> photos);

  @Query('DELETE FROM pqrs_outbox_photo WHERE outboxId = :outboxId')
  Future<void> deleteOutboxPhotos(String outboxId);

  @Query('DELETE FROM pqrs_outbox WHERE id = :id')
  Future<void> deleteOutboxRow(String id);

  /// A server rejection: the action stays visible with its reason and one
  /// more attempt counted. A network failure must NOT call this.
  @Query(
    'UPDATE pqrs_outbox SET syncStatus = :status, errorMessage = :message, '
    'attempts = attempts + 1 WHERE id = :id',
  )
  Future<void> markOutboxStatus(String id, String status, String message);

  /// Counts one more attempt without changing the status (network failure).
  @Query('UPDATE pqrs_outbox SET attempts = attempts + 1 WHERE id = :id')
  Future<void> countOutboxAttempt(String id);

  /// Puts a failed action back in the queue to retry it.
  @Query(
    'UPDATE pqrs_outbox SET syncStatus = :status, errorMessage = NULL '
    'WHERE id = :id',
  )
  Future<void> resetOutboxStatus(String id, String status);

  /// Saves an action and its photos together, so a photo never lacks its
  /// action nor the other way around.
  @transaction
  Future<void> enqueue(
    PqrsOutboxEntry entry,
    List<PqrsOutboxPhotoEntry> photos,
  ) async {
    await insertOutbox(entry);
    await deleteOutboxPhotos(entry.id);
    if (photos.isNotEmpty) await insertOutboxPhotos(photos);
  }

  /// Removes an action and its photos (confirmed by Firestore or discarded).
  @transaction
  Future<void> removeOutbox(String id) async {
    await deleteOutboxPhotos(id);
    await deleteOutboxRow(id);
  }
}
