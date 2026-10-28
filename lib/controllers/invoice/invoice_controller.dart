import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:machuco/database/repository/invoice/invoice_repository.dart';
import 'package:machuco/models/invoice/invoice_model.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/service/invoice/invoice_pdf_service.dart';
import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

/// Estado de la factura que muestra la pantalla.
enum InvoiceLoadStatus {
  initial,
  loading,
  available,

  /// El pago se hizo en efectivo y la factura todavía no se ha emitido.
  pending,

  /// La reserva no tiene factura (pendiente de pago o cancelada).
  notAvailable,
  error,
}

/// Conecta la pantalla de factura con [InvoiceRepository] (Supabase).
///
/// Además recuerda entre sesiones (vía [LocalPreferencesService], namespace
/// `invoices`) qué reservas ya tienen su factura descargada y cuándo. Solo se
/// guardan identificadores y marcas de tiempo: nunca datos de pago.
class InvoiceController extends ChangeNotifier {
  InvoiceController({
    InvoiceRepository? repository,
    LocalPreferencesService? preferences,
    InvoicePdfService? pdfService,
  }) : _repository = repository ?? SupabaseInvoiceRepository(),
       _preferences =
           preferences ?? SharedPreferencesLocalService(namespace: 'invoices'),
       _pdfService = pdfService ?? const PrintingInvoicePdfService();

  final InvoiceRepository _repository;
  final LocalPreferencesService _preferences;
  final InvoicePdfService _pdfService;

  // Claves del módulo: se guardan como 'invoices.<clave>'.
  static const _downloadedReservationIdsKey = 'downloadedReservationIds';
  static const _lastDownloadedAtEpochKey = 'lastDownloadedAtEpoch';

  /// Máximo de reservas recordadas, para no hacer crecer la lista sin límite.
  static const _maxRememberedDownloads = 50;

  InvoiceLoadStatus _status = InvoiceLoadStatus.initial;
  InvoiceModel? _invoice;
  String? _errorMessage;
  List<String> _downloadedReservationIds = const [];
  DateTime? _lastDownloadedAt;

  InvoiceLoadStatus get status => _status;
  InvoiceModel? get invoice => _invoice;
  String? get errorMessage => _errorMessage;
  DateTime? get lastDownloadedAt => _lastDownloadedAt;

  bool isDownloaded(String reservationId) =>
      _downloadedReservationIds.contains(reservationId);

  /// Carga las preferencias guardadas en el dispositivo.
  Future<void> loadPreferences() async {
    _downloadedReservationIds =
        await _preferences.getStringList(_downloadedReservationIdsKey) ??
        const [];
    final epoch = await _preferences.getInt(_lastDownloadedAtEpochKey);
    _lastDownloadedAt = epoch == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(epoch);
    notifyListeners();
  }

  /// Consulta la factura de [reservation] en Supabase y, si aún no existe y
  /// la reserva ya está pagada, la emite.
  ///
  /// [paymentMethod] llega cuando se viene directamente del flujo de pago.
  Future<void> loadForReservation(
    Reservation reservation, {
    PaymentMethodModel? paymentMethod,
  }) async {
    _status = InvoiceLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final existing = await _repository.findByReservation(reservation.id);
      if (existing != null) {
        _invoice = existing;
        _status = InvoiceLoadStatus.available;
      } else if (reservation.invoiceAccessStatus ==
          InvoiceAccessStatus.pending) {
        _status = InvoiceLoadStatus.pending;
      } else if (!_canIssue(reservation, paymentMethod)) {
        _status = InvoiceLoadStatus.notAvailable;
      } else {
        _invoice = await _repository.issue(reservation, paymentMethod);
        _status = InvoiceLoadStatus.available;
      }
    } on InvoiceRepositoryException catch (error) {
      _errorMessage = error.message;
      _status = InvoiceLoadStatus.error;
    } finally {
      notifyListeners();
    }
  }

  /// Una reserva cancelada nunca se factura; una pendiente solo cuando se
  /// viene del flujo de pago (acaba de pagarse).
  bool _canIssue(Reservation reservation, PaymentMethodModel? paymentMethod) =>
      switch (reservation.status) {
        ReservationStatus.cancelled => false,
        ReservationStatus.pending => paymentMethod != null,
        ReservationStatus.active ||
        ReservationStatus.upcoming ||
        ReservationStatus.completed => true,
      };

  /// Genera el PDF de [invoice].
  Future<Uint8List> generatePdfBytes(InvoiceModel invoice) =>
      _pdfService.build(invoice);

  /// Genera el PDF de la factura cargada, lo entrega al dispositivo y, si
  /// tuvo éxito, la recuerda como descargada. Devuelve false si no hay
  /// factura disponible o si falla la generación/guardado.
  Future<bool> downloadCurrent() async {
    final invoice = _invoice;
    if (invoice == null) return false;
    try {
      final bytes = await generatePdfBytes(invoice);
      await _pdfService.save(bytes, 'factura_${invoice.invoiceNumber}.pdf');
    } catch (error) {
      debugPrint('No se pudo descargar la factura: $error');
      return false;
    }
    await _markDownloaded(invoice.reservationId);
    return true;
  }

  Future<void> _markDownloaded(String reservationId) async {
    final ids = [
      ..._downloadedReservationIds.where((id) => id != reservationId),
      reservationId,
    ];
    _downloadedReservationIds = ids.length > _maxRememberedDownloads
        ? ids.sublist(ids.length - _maxRememberedDownloads)
        : ids;
    _lastDownloadedAt = DateTime.now();
    await _preferences.setStringList(
      _downloadedReservationIdsKey,
      _downloadedReservationIds,
    );
    await _preferences.setInt(
      _lastDownloadedAtEpochKey,
      _lastDownloadedAt!.millisecondsSinceEpoch,
    );
    notifyListeners();
  }
}
