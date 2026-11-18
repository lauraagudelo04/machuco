import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_payment_terms.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/service/invoice/invoice_payment_method_source.dart';

Reservation _reservation({String? paymentMethod}) => Reservation(
  id: 'res-1',
  requestId: 'req-1',
  motelId: 'motel-1',
  motelName: 'Motel Prueba',
  roomId: 'room-1',
  roomName: 'Suite',
  roomNumber: '101',
  checkIn: DateTime.utc(2026, 10, 19, 20),
  checkOut: DateTime.utc(2026, 10, 19, 23),
  stayMode: StayMode.dateWithHourBlock,
  guestCount: 2,
  services: const [],
  products: const [],
  roomTotal: 100000,
  total: 100000,
  status: ReservationStatus.upcoming,
  createdAt: DateTime(2026, 10, 19),
  paymentMethod: paymentMethod,
);

void main() {
  group('SupabaseInvoicePaymentMethodSource', () {
    test('consulta el maestro por REST y devuelve los nombres', () async {
      late http.Request sent;
      final source = SupabaseInvoicePaymentMethodSource(
        baseUrl: 'https://demo.supabase.co/',
        apiKey: 'clave-publica',
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([
                {'id': 1, 'nombre': 'Efectivo'},
                {'id': 2, 'nombre': 'Tarjeta de crédito'},
              ]),
            ),
            200,
          );
        }),
      );

      expect(await source.fetchNames(), ['Efectivo', 'Tarjeta de crédito']);
      expect(sent.method, 'GET');
      expect(sent.url.path, '/rest/v1/payment_method');
      expect(sent.url.queryParameters['select'], 'id,nombre');
      expect(sent.headers['apikey'], 'clave-publica');
    });

    test('respuesta distinta de 200: lanza excepción del maestro', () async {
      final source = SupabaseInvoicePaymentMethodSource(
        baseUrl: 'https://demo.supabase.co',
        apiKey: 'clave-publica',
        httpClient: MockClient((_) async => http.Response('[]', 401)),
      );

      expect(
        source.fetchNames(),
        throwsA(isA<InvoicePaymentMethodSourceException>()),
      );
    });

    test('sin conexión: lanza excepción del maestro', () async {
      final source = SupabaseInvoicePaymentMethodSource(
        baseUrl: 'https://demo.supabase.co',
        apiKey: 'clave-publica',
        httpClient: MockClient((_) async => throw http.ClientException('x')),
      );

      expect(
        source.fetchNames(),
        throwsA(isA<InvoicePaymentMethodSourceException>()),
      );
    });
  });

  group('invoicePaymentMethodHint', () {
    test('pago con tarjeta: usa el tipo de tarjeta elegido', () {
      final card = PaymentMethodModel(amount: 1, concept: 'Reserva')
        ..cardNumber = '4111111111111111'
        ..cardKind = CardPaymentKind.credit;

      expect(
        invoicePaymentMethodHint(_reservation(), card),
        'Tarjeta de crédito',
      );
    });

    test('sin tarjeta: usa el método registrado en la reserva', () {
      expect(
        invoicePaymentMethodHint(_reservation(paymentMethod: 'Efectivo'), null),
        'Efectivo',
      );
    });

    test('"En el Local" es un lugar, no un método del maestro', () {
      expect(
        invoicePaymentMethodHint(
          _reservation(paymentMethod: ReservationPaymentTerms.payAtProperty),
          null,
        ),
        isNull,
      );
    });
  });
}
