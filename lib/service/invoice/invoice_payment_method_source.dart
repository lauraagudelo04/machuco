import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_payment_terms.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/service/supabase/supabase_config.dart';

/// El maestro de métodos de pago no se pudo consultar.
class InvoicePaymentMethodSourceException implements Exception {
  const InvoicePaymentMethodSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Maestro de métodos de pago que usa la factura (solo lectura).
abstract interface class InvoicePaymentMethodSource {
  /// Nombres oficiales de los métodos de pago, en el orden del maestro.
  Future<List<String>> fetchNames();
}

/// Lee el maestro `payment_method` de Supabase por su API REST
/// (`/rest/v1/payment_method`). Supabase solo aporta datos maestros: la app
/// nunca escribe en él.
class SupabaseInvoicePaymentMethodSource implements InvoicePaymentMethodSource {
  SupabaseInvoicePaymentMethodSource({
    String? baseUrl,
    String? apiKey,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _baseUrl = baseUrl ?? SupabaseConfig.baseUrl,
       _apiKey = apiKey ?? SupabaseConfig.apiKey,
       _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final String _apiKey;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<List<String>> fetchNames() async {
    if (_baseUrl.trim().isEmpty || _apiKey.trim().isEmpty) {
      throw const InvoicePaymentMethodSourceException(
        'Supabase no está configurado.',
      );
    }
    final uri = Uri.parse(
      '${_baseUrl.trim().replaceFirst(RegExp(r'/$'), '')}/rest/v1/payment_method',
    ).replace(queryParameters: {'select': 'id,nombre', 'order': 'id.asc'});

    final http.Response response;
    try {
      response = await _httpClient
          .get(
            uri,
            headers: {'apikey': _apiKey.trim(), 'Accept': 'application/json'},
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const InvoicePaymentMethodSourceException(
        'Supabase no respondió a tiempo.',
      );
    } on Exception {
      throw const InvoicePaymentMethodSourceException(
        'No se pudo conectar con Supabase.',
      );
    }
    if (response.statusCode != 200) {
      throw InvoicePaymentMethodSourceException(
        'Supabase respondió ${response.statusCode} al leer los métodos de pago.',
      );
    }

    final Object? rows;
    try {
      rows = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const InvoicePaymentMethodSourceException(
        'Respuesta inválida al leer los métodos de pago.',
      );
    }
    if (rows is! List) {
      throw const InvoicePaymentMethodSourceException(
        'Respuesta inválida al leer los métodos de pago.',
      );
    }
    return List.unmodifiable([
      for (final row in rows)
        if (row is Map && row['nombre'] is String)
          if ((row['nombre'] as String).trim().isNotEmpty)
            (row['nombre'] as String).trim(),
    ]);
  }
}

/// Método de pago que la factura debe buscar en el maestro.
///
/// - Si se viene del pago con tarjeta, el tipo de tarjeta elegido.
/// - Si no, el método registrado en la reserva (por ejemplo "Efectivo" cuando
///   el propietario recibió el pago en el local).
///
/// "En el Local" es el lugar de pago, no un método del maestro: se ignora.
String? invoicePaymentMethodHint(
  Reservation reservation,
  PaymentMethodModel? paymentMethod,
) {
  if (paymentMethod != null &&
      paymentMethod.cardNumber.replaceAll(RegExp(r'\D'), '').length >= 4) {
    return switch (paymentMethod.cardKind) {
      CardPaymentKind.credit => 'Tarjeta de crédito',
      CardPaymentKind.debit => 'Tarjeta de débito',
    };
  }
  final method = reservation.paymentMethod?.trim();
  if (method == null ||
      method.isEmpty ||
      method == ReservationPaymentTerms.payAtProperty) {
    return null;
  }
  return method;
}
