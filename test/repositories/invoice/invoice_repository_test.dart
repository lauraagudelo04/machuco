import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/repository/invoice/invoice_repository.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';

const _url = 'https://example.supabase.co';
const _key = 'test-key';

final _reservation = Reservation(
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
  services: const [
    ReservationLineItem(id: 's1', name: 'Jacuzzi', unitPrice: 30000),
  ],
  products: const [
    ReservationLineItem(
      id: 'p1',
      name: 'Gaseosa',
      unitPrice: 5000,
      quantity: 2,
    ),
  ],
  roomTotal: 100000,
  total: 140000,
  status: ReservationStatus.completed,
  createdAt: DateTime(2026, 10, 19),
);

Map<String, dynamic> _row() => {
  'id': 7,
  'invoice_number': 'FAC-000007',
  'reservation_id': 'res-1',
  'client_id': null,
  'client_name': null,
  'motel_id': 'motel-1',
  'motel_name': 'Motel Prueba',
  'room_name': 'Suite',
  'room_number': '101',
  'check_in': '2026-10-19T20:00:00+00:00',
  'check_out': '2026-10-19T23:00:00+00:00',
  'guest_count': 2,
  'items': [
    {'name': 'Jacuzzi', 'unit_price': 30000, 'quantity': 1},
    {'name': 'Gaseosa', 'unit_price': 5000, 'quantity': 2},
  ],
  'room_total': 100000,
  'total': 140000,
  'payment_concept': 'Reserva',
  'payment_amount': 140000,
  'card_holder': 'Ana Pérez',
  'card_last4': '4242',
  'installments': 1,
  'issued_at': '2026-10-19T23:05:00+00:00',
};

SupabaseInvoiceRepository _repository(MockClientHandler handler) =>
    SupabaseInvoiceRepository(
      client: MockClient(handler),
      supabaseUrl: _url,
      publishableKey: _key,
    );

void main() {
  group('SupabaseInvoiceRepository', () {
    test('consulta por reserva con filtros de PostgREST', () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return _json([_row()]);
      });

      final invoice = await repository.findByReservation('res-1');

      expect(sent.method, 'GET');
      expect(sent.url.path, '/rest/v1/invoices');
      expect(sent.url.queryParameters['reservation_id'], 'eq.res-1');
      expect(sent.headers['apikey'], _key);
      expect(invoice?.invoiceNumber, 'FAC-000007');
      expect(invoice?.items, hasLength(2));
      expect(invoice?.payment?.cardLast4, '4242');
    });

    test('devuelve null si la reserva no tiene factura', () async {
      final repository = _repository((_) async => http.Response('[]', 200));

      expect(await repository.findByReservation('res-1'), isNull);
    });

    test('emite por RPC sin enviar el número completo de tarjeta', () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return _json(_row());
      });
      final paymentMethod =
          PaymentMethodModel(amount: 140000, concept: 'Reserva')
            ..cardHolder = 'Ana Pérez'
            ..cardNumber = '4111 1111 1111 4242'
            ..expiry = '12/30'
            ..cvv = '123';

      final invoice = await repository.issue(_reservation, paymentMethod);

      expect(sent.method, 'POST');
      expect(sent.url.path, '/rest/v1/rpc/issue_invoice');
      final payload =
          (jsonDecode(sent.body) as Map<String, dynamic>)['p_invoice']
              as Map<String, dynamic>;
      expect(payload['card_last4'], '4242');
      expect(payload.containsKey('total'), isFalse);
      expect(sent.body, isNot(contains('4111')));
      expect(sent.body, isNot(contains('12/30')));
      expect(sent.body, isNot(contains('"123"')));
      expect(payload['items'], hasLength(2));
      expect(invoice.total, 140000);
    });

    test('filtra por varios moteles con in.()', () async {
      late http.Request sent;
      final repository = _repository((request) async {
        sent = request;
        return http.Response('[]', 200);
      });

      await repository.findByMotels(['m1', 'm2']);

      expect(sent.url.queryParameters['motel_id'], 'in.("m1","m2")');
    });

    test('estado HTTP de error lanza InvoiceRepositoryException', () {
      final repository = _repository((_) async => http.Response('{}', 500));

      expect(
        repository.findByReservation('res-1'),
        throwsA(isA<InvoiceRepositoryException>()),
      );
    });

    test('respuesta inválida lanza InvoiceRepositoryException', () {
      final repository = _repository((_) async => http.Response('{}', 200));

      expect(
        repository.findByReservation('res-1'),
        throwsA(isA<InvoiceRepositoryException>()),
      );
    });

    test('sin configuración lanza InvoiceRepositoryException', () {
      final repository = SupabaseInvoiceRepository(
        client: MockClient((_) async => http.Response('[]', 200)),
        supabaseUrl: '',
        publishableKey: '',
      );

      expect(
        repository.findByReservation('res-1'),
        throwsA(isA<InvoiceRepositoryException>()),
      );
    });
  });
}

/// Supabase responde en UTF-8; `http.Response(String)` usaría Latin-1.
http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
