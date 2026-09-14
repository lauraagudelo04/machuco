import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/invoice/invoice_model.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';

/// Controlador sencillo para crear y mantener facturas en memoria.
class InvoiceController extends ChangeNotifier {
  InvoiceController();

  final Map<String, InvoiceModel> _store = {};

  /// Crea una nueva factura a partir de una reserva y un método de pago opcional.
  InvoiceModel createFromReservation(
    Reservation reservation,
    PaymentMethodModel? paymentMethod,
  ) {
    final id = 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final invoice = InvoiceModel(
      id: id,
      reservation: reservation,
      paymentMethod: paymentMethod,
    );
    _store[id] = invoice;
    notifyListeners();
    return invoice;
  }

  InvoiceModel? getById(String id) => _store[id];

  List<InvoiceModel> get all => _store.values.toList(growable: false);

  /// Simula la descarga/guardado de la factura. Actualmente sólo espera un
  /// pequeño tiempo y devuelve bytes vacíos. Se puede extender para generar
  /// un PDF real usando `package:pdf` + `printing`.
  Future<Uint8List> generatePdfBytes(InvoiceModel invoice) async {
    // TODO: Implementar generación real de PDF si se añade dependencia.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return Uint8List(0);
  }

  /// Simulación de guardar/descargar la factura; devuelve true si la
  /// operación 'fue exitosa' (siempre true en el stub actual).
  Future<bool> simulateDownload(InvoiceModel invoice) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return true;
  }
}