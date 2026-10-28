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

  /// Solo para la carga explícita de ejemplos: nunca reemplaza pagos guardados.
  @Insert(onConflict: OnConflictStrategy.ignore)
  Future<void> insertMissingDemoPayments(List<PaymentRecord> payments);

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
}
