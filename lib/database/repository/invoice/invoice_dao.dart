import 'package:floor/floor.dart';
import 'package:machuco/database/model/invoice/invoice_entry.dart';

/// Acceso a la copia local de las facturas (tabla `invoices`).
@dao
abstract class InvoiceDao {
  @Query('SELECT * FROM invoices WHERE id = :id')
  Future<InvoiceEntry?> findById(String id);

  @Query(
    'SELECT * FROM invoices WHERE clientId = :clientId ORDER BY issuedAt DESC',
  )
  Future<List<InvoiceEntry>> findByClient(String clientId);

  @Query(
    'SELECT * FROM invoices WHERE ownerId = :ownerId ORDER BY issuedAt DESC',
  )
  Future<List<InvoiceEntry>> findByOwner(String ownerId);

  /// Reemplaza la copia local con lo último que devolvió Firestore.
  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> upsert(InvoiceEntry entry);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> upsertAll(List<InvoiceEntry> entries);
}
