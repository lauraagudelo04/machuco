import 'package:flutter/foundation.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/invoice/invoice_entry.dart';
import 'package:machuco/database/repository/invoice/invoice_dao.dart';
import 'package:machuco/database/repository/invoice/invoice_repository.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/invoice/invoice_firestore_document.dart';
import 'package:machuco/models/invoice/invoice_model.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/service/invoice/invoice_payment_method_source.dart';

/// Facturas con Firestore como fuente de verdad y SQLite como copia local.
///
/// - Cada factura que devuelve Firebase se guarda en la tabla `invoices`.
/// - Si Firebase no responde (sin conexión), se lee la copia local.
/// - Una factura nunca se emite solo en SQLite: emitir exige Firebase.
/// - El nombre del método de pago se valida contra el maestro de Supabase
///   (REST) y, una vez resuelto, se conserva en la copia local.
class CachedInvoiceRepository implements InvoiceRepository {
  CachedInvoiceRepository({
    FirestoreInvoiceRepository? remote,
    Future<InvoiceDao> Function()? dao,
    InvoicePaymentMethodSource? paymentMethods,
  }) : _remote = remote ?? FirestoreInvoiceRepository(),
       _dao = dao ?? _defaultDao,
       _paymentMethods = paymentMethods ?? SupabaseInvoicePaymentMethodSource();

  final FirestoreInvoiceRepository _remote;
  final Future<InvoiceDao> Function() _dao;
  final InvoicePaymentMethodSource _paymentMethods;

  static Future<InvoiceDao> _defaultDao() async =>
      (await AppDatabaseProvider.database).invoiceDao;

  @override
  Future<InvoiceModel?> findByReservation(
    String reservationId, {
    String? paymentMethodHint,
  }) async {
    final InvoiceFirestoreDocument? document;
    try {
      document = await _remote.findDocument(reservationId);
    } on InvoiceRepositoryException catch (error) {
      if (!error.offline) rethrow;
      final cached = await _readLocal((dao) => dao.findById(reservationId));
      if (cached == null) rethrow;
      return cached.toModel();
    }
    if (document == null) return null;
    return _store(document, paymentMethodHint);
  }

  @override
  Future<InvoiceModel> issue(
    Reservation reservation,
    PaymentMethodModel? paymentMethod,
  ) async {
    final document = await _remote.issueDocument(reservation, paymentMethod);
    return _store(
      document,
      invoicePaymentMethodHint(reservation, paymentMethod),
    );
  }

  @override
  Future<List<InvoiceModel>> findByClient(String clientId) => _findAll(
    () => _remote.findDocumentsByClient(clientId),
    (dao) => dao.findByClient(clientId),
  );

  @override
  Future<List<InvoiceModel>> findByOwner(String ownerId) => _findAll(
    () => _remote.findDocumentsByOwner(ownerId),
    (dao) => dao.findByOwner(ownerId),
  );

  Future<List<InvoiceModel>> _findAll(
    Future<List<InvoiceFirestoreDocument>> Function() remote,
    Future<List<InvoiceEntry>> Function(InvoiceDao dao) local,
  ) async {
    final List<InvoiceFirestoreDocument> documents;
    try {
      documents = await remote();
    } on InvoiceRepositoryException catch (error) {
      if (!error.offline) rethrow;
      final cached = await _readLocal(local) ?? const <InvoiceEntry>[];
      return List.unmodifiable(cached.map((entry) => entry.toModel()));
    }
    final invoices = <InvoiceModel>[];
    for (final document in documents) {
      // En listas no se consulta el maestro: se conserva el nombre ya resuelto.
      invoices.add(await _store(document, null));
    }
    return List.unmodifiable(invoices);
  }

  /// Guarda en SQLite lo que devolvió Firestore, conservando el nombre del
  /// método de pago si ya se había resuelto antes.
  Future<InvoiceModel> _store(
    InvoiceFirestoreDocument document,
    String? paymentMethodHint,
  ) async {
    final invoice = document.invoice;
    final cached = await _readLocal((dao) => dao.findById(invoice.id));
    final name =
        cached?.paymentMethodName ??
        await _resolvePaymentMethod(paymentMethodHint);
    final resolved = invoice.withPaymentMethodName(name);
    try {
      await (await _dao()).upsert(
        InvoiceEntry.fromModel(resolved, ownerId: document.ownerId),
      );
    } catch (error) {
      // La copia local es una ayuda; si falla, la factura de Firebase sigue
      // siendo válida y se muestra igual.
      debugPrint('No se pudo guardar la factura en SQLite: $error');
    }
    return resolved;
  }

  /// Busca [hint] en el maestro de Supabase y devuelve su nombre oficial, o
  /// `null` si no está en el maestro o no se pudo consultar.
  Future<String?> _resolvePaymentMethod(String? hint) async {
    final wanted = hint?.trim().toLowerCase();
    if (wanted == null || wanted.isEmpty) return null;
    try {
      final names = await _paymentMethods.fetchNames();
      for (final name in names) {
        if (name.trim().toLowerCase() == wanted) return name;
      }
      return null;
    } on InvoicePaymentMethodSourceException catch (error) {
      debugPrint('Maestro de métodos de pago no disponible: $error');
      return null;
    }
  }

  Future<T?> _readLocal<T>(Future<T?> Function(InvoiceDao dao) read) async {
    try {
      return await read(await _dao());
    } catch (error) {
      debugPrint('No se pudo leer la copia local de facturas: $error');
      return null;
    }
  }
}
