import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/invoice/invoice_model.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';

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

  Future<InvoiceModel?> findById(int id);

  /// Facturas de un cliente, de la más reciente a la más antigua.
  Future<List<InvoiceModel>> findByClient(String clientId);

  /// Facturas de uno o varios moteles (consulta del Propietario).
  Future<List<InvoiceModel>> findByMotels(List<String> motelIds);

  /// Emite la factura de [reservation]. Si ya existía una para esa reserva,
  /// devuelve la existente sin duplicarla.
  Future<InvoiceModel> issue(
    Reservation reservation,
    PaymentMethodModel? paymentMethod,
  );
}

/// [InvoiceRepository] sobre la API REST de Supabase (PostgREST):
///
/// - `GET  /rest/v1/invoices`            consultas filtradas.
/// - `POST /rest/v1/rpc/issue_invoice`   emisión idempotente; el total lo
///   calcula el backend.
///
/// La tabla y la función están descritas en `docs/invoice_supabase.sql`.
class SupabaseInvoiceRepository implements InvoiceRepository {
  SupabaseInvoiceRepository({
    http.Client? client,
    String? supabaseUrl,
    String? publishableKey,
  }) : _client = client ?? http.Client(),
       _supabaseUrl =
           supabaseUrl ??
           const String.fromEnvironment(
             'SUPABASE_URL',
             defaultValue: 'https://ogrbbuwtsyezegkpwtsl.supabase.co',
           ),
       _publishableKey =
           publishableKey ??
           const String.fromEnvironment(
             'SUPABASE_PUBLISHABLE_KEY',
             defaultValue: 'sb_publishable_Wv16MVxsTzA89lBeocarLQ_YL33Ya_E',
           );

  final http.Client _client;
  final String _supabaseUrl;
  final String _publishableKey;

  static const _timeout = Duration(seconds: 15);

  @override
  Future<InvoiceModel?> findByReservation(String reservationId) async {
    final rows = await _select({
      'reservation_id': 'eq.$reservationId',
      'limit': '1',
    });
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<InvoiceModel?> findById(int id) async {
    final rows = await _select({'id': 'eq.$id', 'limit': '1'});
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<List<InvoiceModel>> findByClient(String clientId) =>
      _select({'client_id': 'eq.$clientId', 'order': 'issued_at.desc'});

  @override
  Future<List<InvoiceModel>> findByMotels(List<String> motelIds) async {
    if (motelIds.isEmpty) return const [];
    final quoted = motelIds.map((id) => '"${id.replaceAll('"', '')}"');
    return _select({
      'motel_id': 'in.(${quoted.join(',')})',
      'order': 'issued_at.desc',
    });
  }

  @override
  Future<InvoiceModel> issue(
    Reservation reservation,
    PaymentMethodModel? paymentMethod,
  ) async {
    final response = await _send(
      () => _client.post(
        _uri('/rest/v1/rpc/issue_invoice'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'p_invoice': InvoiceModel.issuePayload(reservation, paymentMethod),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw const InvoiceRepositoryException(
        'No se pudo emitir la factura en Supabase.',
      );
    }
    return _decode(
      (body) => InvoiceModel.fromJson(body as Map<String, dynamic>),
      response,
    );
  }

  Future<List<InvoiceModel>> _select(Map<String, String> filters) async {
    final response = await _send(
      () => _client.get(
        _uri('/rest/v1/invoices', {'select': '*', ...filters}),
        headers: _headers,
      ),
    );
    if (response.statusCode != 200) {
      throw const InvoiceRepositoryException(
        'No se pudieron consultar las facturas en Supabase.',
      );
    }
    return _decode((body) {
      if (body is! List) throw const FormatException('Respuesta inválida');
      return body
          .map((row) => InvoiceModel.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    }, response);
  }

  Map<String, String> get _headers => {
    'apikey': _publishableKey,
    'Accept': 'application/json',
  };

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.tryParse(_supabaseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        _publishableKey.isEmpty) {
      throw const InvoiceRepositoryException(
        'La consulta de facturas no está configurada.',
      );
    }
    return base.replace(path: path, queryParameters: queryParameters);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on InvoiceRepositoryException {
      rethrow;
    } catch (_) {
      throw const InvoiceRepositoryException(
        'No se pudo conectar con el servicio de facturas.',
      );
    }
  }

  T _decode<T>(T Function(Object? body) parse, http.Response response) {
    try {
      return parse(jsonDecode(utf8.decode(response.bodyBytes)));
    } on FormatException {
      throw const InvoiceRepositoryException(
        'El servicio de facturas devolvió datos inválidos.',
      );
    } on TypeError {
      throw const InvoiceRepositoryException(
        'El servicio de facturas devolvió datos inválidos.',
      );
    }
  }
}
