import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_firestore_document.dart';
import 'package:machuco/models/invoice/invoice_firestore_document.dart';
import 'package:machuco/models/invoice/invoice_model.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

class InvoiceRepositoryException implements Exception {
  const InvoiceRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Acceso a las facturas, independiente del origen de datos concreto.
abstract interface class InvoiceRepository {
  /// Factura de una reserva, o `null` si todavía no se ha emitido.
  Future<InvoiceModel?> findByReservation(String reservationId);

  /// Facturas de un cliente, de la más reciente a la más antigua.
  Future<List<InvoiceModel>> findByClient(String clientId);

  /// Facturas de los moteles de un propietario, de la más reciente a la más
  /// antigua.
  Future<List<InvoiceModel>> findByOwner(String ownerId);

  /// Emite la factura de [reservation]. Si ya existía una para esa reserva,
  /// devuelve la existente sin duplicarla.
  Future<InvoiceModel> issue(
    Reservation reservation,
    PaymentMethodModel? paymentMethod,
  );
}

/// [InvoiceRepository] sobre Cloud Firestore (`invoices/{reservationId}`).
///
/// - Una factura por reserva: el id del documento es el id de la reserva, así
///   la emisión es idempotente.
/// - Los importes, el cliente y el propietario se copian de la reserva que ya
///   está en Firestore (`reservations/{id}`), no de lo que tenga la app en
///   memoria; las reglas de seguridad comprueban que coincidan.
/// - `issuedAt` lo pone el servidor.
class FirestoreInvoiceRepository implements InvoiceRepository {
  FirestoreInvoiceRepository({
    FirebaseFirestore? firestore,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Nombre de la colección. Pendiente de mover a `FirestoreCollections`
  /// (archivo compartido) cuando el equipo lo apruebe.
  static const collection = 'invoices';

  final FirebaseFirestore _firestore;
  final Duration requestTimeout;

  CollectionReference<Map<String, dynamic>> get _invoices =>
      _firestore.collection(collection);

  CollectionReference<Map<String, dynamic>> get _reservations =>
      _firestore.collection(FirestoreCollections.reservations);

  @override
  Future<InvoiceModel?> findByReservation(String reservationId) async {
    _validateId(reservationId);
    try {
      final snapshot = await _invoices
          .doc(reservationId)
          .get()
          .timeout(requestTimeout);
      final data = snapshot.data();
      return data == null ? null : _parse(snapshot.id, data);
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw _offline;
    }
  }

  @override
  Future<List<InvoiceModel>> findByClient(String clientId) {
    _validateId(clientId);
    return _list(
      _invoices.where('clientId', isEqualTo: clientId),
      (document) => document.invoice.clientId == clientId,
    );
  }

  @override
  Future<List<InvoiceModel>> findByOwner(String ownerId) {
    _validateId(ownerId);
    return _list(
      _invoices.where('ownerId', isEqualTo: ownerId),
      (document) => document.ownerId == ownerId,
    );
  }

  @override
  Future<InvoiceModel> issue(
    Reservation reservation,
    PaymentMethodModel? paymentMethod,
  ) async {
    _validateId(reservation.id);
    final invoiceRef = _invoices.doc(reservation.id);
    final reservationRef = _reservations.doc(reservation.id);
    try {
      await _firestore
          .runTransaction((transaction) async {
            final existing = await transaction.get(invoiceRef);
            if (existing.exists) return;

            final remote = await transaction.get(reservationRef);
            final remoteData = remote.data();
            if (remoteData == null) throw _notSynced;
            final ReservationFirestoreDocument source;
            try {
              source = ReservationFirestoreDocument.fromFirestore(
                remote.id,
                remoteData,
              );
            } on FormatException {
              throw _invalidData;
            }
            if (source.reservation.status == ReservationStatus.cancelled) {
              throw const InvoiceRepositoryException(
                'Una reserva cancelada no se puede facturar.',
              );
            }

            transaction.set(
              invoiceRef,
              InvoiceFirestoreDocument(
                ownerId: source.ownerId,
                invoice: InvoiceModel.fromReservation(
                  source.reservation,
                  paymentMethod: paymentMethod,
                ),
              ).toFirestore(),
            );
          })
          .timeout(requestTimeout);

      final saved = await invoiceRef.get().timeout(requestTimeout);
      final data = saved.data();
      if (data == null) throw _invalidData;
      return _parse(saved.id, data);
    } on InvoiceRepositoryException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw _offline;
    }
  }

  Future<List<InvoiceModel>> _list(
    Query<Map<String, dynamic>> query,
    bool Function(InvoiceFirestoreDocument document) inScope,
  ) async {
    try {
      final snapshot = await query.get().timeout(requestTimeout);
      final invoices = snapshot.docs.map((snapshotDocument) {
        final document = InvoiceFirestoreDocument.fromFirestore(
          snapshotDocument.id,
          snapshotDocument.data(),
        );
        if (!inScope(document)) {
          throw const FormatException('Factura fuera del alcance solicitado.');
        }
        return document.invoice;
      }).toList();
      // Se ordena en el cliente para no requerir un índice compuesto.
      invoices.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
      return List.unmodifiable(invoices);
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw _offline;
    } on FormatException {
      throw _invalidData;
    }
  }

  InvoiceModel _parse(String documentId, Map<String, dynamic> data) {
    try {
      return InvoiceFirestoreDocument.fromFirestore(documentId, data).invoice;
    } on FormatException {
      throw _invalidData;
    }
  }

  static const _offline = InvoiceRepositoryException(
    'No se pudo conectar con el servicio de facturas.',
  );

  static const _invalidData = InvoiceRepositoryException(
    'El servicio de facturas devolvió datos inválidos.',
  );

  static const _notSynced = InvoiceRepositoryException(
    'La reserva aún no está sincronizada. Inténtalo de nuevo en unos minutos.',
  );

  void _validateId(String value) {
    if (value.trim().isEmpty || value != value.trim() || value.contains('/')) {
      throw const InvoiceRepositoryException(
        'Se requiere un identificador válido para consultar facturas.',
      );
    }
  }

  InvoiceRepositoryException _map(FirebaseException error) {
    debugPrint('Firestore invoices error: ${error.code}');
    return switch (error.code) {
      'permission-denied' ||
      'unauthenticated' => const InvoiceRepositoryException(
        'No tienes permisos para ver o emitir esta factura.',
      ),
      'unavailable' || 'deadline-exceeded' => _offline,
      _ => const InvoiceRepositoryException(
        'No se pudo consultar la factura en Firebase.',
      ),
    };
  }
}
