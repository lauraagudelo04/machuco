import 'package:floor/floor.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_catalog_entry.dart';

@dao
abstract class PaymentDao {
  @Query('SELECT * FROM payments ORDER BY reservationDate DESC, id DESC')
  Future<List<PaymentRecord>> findAll();

  @Query('SELECT * FROM payments WHERE id = :id LIMIT 1')
  Future<PaymentRecord?> findById(String id);

  @Query(
    'SELECT * FROM payments WHERE clientId = :clientId '
    'ORDER BY reservationDate DESC, id DESC',
  )
  Future<List<PaymentRecord>> findByClient(String clientId);

  @Query(
    'SELECT * FROM payments WHERE motelId = :motelId '
    'ORDER BY reservationDate DESC, id DESC',
  )
  Future<List<PaymentRecord>> findByMotel(String motelId);

  /// Un ID repetido es un error; insertar no debe sobrescribir un pago pagado.
  @insert
  Future<void> insertPayment(PaymentRecord payment);

  @update
  Future<void> updatePayment(PaymentRecord payment);

  /// Retira fixtures históricos que llegaron a SQLite antes de habilitar la
  /// sincronización real. No coincide con IDs UUID de pagos reales.
  @Query(
    "DELETE FROM payments WHERE id IN ('pay-001', 'pay-002', 'pay-003', "
    "'owner-pay-001', 'owner-pay-002', 'owner-pay-003')",
  )
  Future<void> deleteLegacyDemoPayments();

  @Query('SELECT * FROM payment_method_catalog ORDER BY id')
  Future<List<PaymentCatalogEntry>> findCatalogEntries();

  @Insert(onConflict: OnConflictStrategy.ignore)
  Future<void> insertCatalogEntries(List<PaymentCatalogEntry> entries);

  @update
  Future<void> updateCatalogEntries(List<PaymentCatalogEntry> entries);

  /// Actualiza nombres sin REPLACE ni borrar métodos referenciados por pagos.
  @transaction
  Future<void> saveCatalogEntries(List<PaymentCatalogEntry> entries) async {
    await insertCatalogEntries(entries);
    await updateCatalogEntries(entries);
  }

  /// Confirma la recepción, no procesa un cobro bancario.
  /// Una sola sentencia impide que dos confirmaciones modifiquen el mismo pago.
  @Query(
    "UPDATE payments SET status = 'paid', method = NULL, "
    'paymentMethodId = :paymentMethodId, paidAt = :paidAt, '
    'receiptNumber = :receiptNumber '
    "WHERE id = :id AND motelId = :motelId AND status = 'pending' "
    'AND EXISTS (SELECT 1 FROM payment_method_catalog '
    'WHERE id = :paymentMethodId)',
  )
  Future<void> updatePendingPayment(
    String id,
    String motelId,
    int paymentMethodId,
    DateTime paidAt,
    String receiptNumber,
  );

  @Query('SELECT changes()')
  Future<int?> findAffectedRows();

  /// Lee changes() en la misma transacción que el UPDATE para obtener un
  /// resultado fiable incluso si llegan dos confirmaciones simultáneas.
  @transaction
  Future<int> registerLocalPayment(
    String id,
    String motelId,
    int paymentMethodId,
    DateTime paidAt,
    String receiptNumber,
  ) async {
    await updatePendingPayment(
      id,
      motelId,
      paymentMethodId,
      paidAt,
      receiptNumber,
    );
    return await findAffectedRows() ?? 0;
  }

  /// Imports cloud records without letting an older pending copy regress a
  /// payment that was already processed on this device.
  @transaction
  Future<void> mergeRemotePayments(List<PaymentRecord> payments) async {
    for (final remote in payments) {
      final local = await findById(remote.id);
      if (local == null) {
        await insertPayment(remote);
        continue;
      }
      if (_acceptRemoteStatus(local.status, remote.status)) {
        await updatePayment(remote);
      }
    }
  }

  bool _acceptRemoteStatus(PaymentStatus local, PaymentStatus remote) {
    if (local == remote) return true;
    if (local == PaymentStatus.pending) return true;
    return local == PaymentStatus.paid && remote == PaymentStatus.refunded;
  }
}
