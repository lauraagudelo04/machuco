import 'dart:convert';

import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/service/sql_connect/motel_connector/motel.dart';
import 'package:machuco/service/sql_connect/sql_connect_config.dart';

/// Operaciones remotas de moteles en Firebase SQL Connect.
///
/// Aísla el código generado (`lib/service/sql_connect/motel_connector/`) para
/// que `SqlConnectMotelRepository` se pueda probar con un doble.
abstract interface class MotelSqlConnectGateway {
  Future<List<Motel>> listAll();
  Future<List<Motel>> listMine();
  Future<List<Motel>> listAvailable();
  Future<Motel?> getById(String id);

  /// Devuelve el id del motel creado.
  Future<String> createMine(Motel motel);

  /// Devuelve el id del motel creado.
  Future<String> createForOwner(Motel motel);

  /// Devuelve cuántas filas se actualizaron (0 si el motel no es del usuario).
  Future<int> updateMine(Motel motel);

  Future<void> updateAsAdmin(Motel motel);

  /// Devuelve cuántas filas se actualizaron (0 si el motel no es del usuario).
  Future<int> setMineAvailability(String id, bool isAvailable);
}

/// Implementación con el SDK generado del conector `motel`.
class GeneratedMotelSqlConnectGateway implements MotelSqlConnectGateway {
  GeneratedMotelSqlConnectGateway({MotelConnector? connector})
    : _connector = connector ?? _sharedConnector();

  final MotelConnector _connector;

  static MotelConnector? _shared;

  static MotelConnector _sharedConnector() {
    final existing = _shared;
    if (existing != null) return existing;
    final connector = MotelConnector.instance;
    if (SqlConnectConfig.useEmulator) {
      connector.dataConnect.useDataConnectEmulator(
        SqlConnectConfig.emulatorHost,
        SqlConnectConfig.emulatorPort,
      );
    }
    return _shared = connector;
  }

  @override
  Future<List<Motel>> listAll() async {
    final result = await _connector.listAllMotels().execute();
    return result.data.motels.map((m) => _toMotel(m.toJson())).toList();
  }

  @override
  Future<List<Motel>> listMine() async {
    final result = await _connector.listMyMotels().execute();
    return result.data.motels.map((m) => _toMotel(m.toJson())).toList();
  }

  @override
  Future<List<Motel>> listAvailable() async {
    final result = await _connector.listAvailableMotels().execute();
    return result.data.motels.map((m) => _toMotel(m.toJson())).toList();
  }

  @override
  Future<Motel?> getById(String id) async {
    final result = await _connector.getMotelById(id: id).execute();
    final motel = result.data.motel;
    return motel == null ? null : _toMotel(motel.toJson());
  }

  @override
  Future<String> createMine(Motel motel) async {
    final result = await _connector
        .createMyMotel(
          name: motel.name,
          email: motel.email,
          roomCount: motel.roomCount,
          nit: motel.nit,
          address: motel.address,
          phone: motel.phone,
          paymentMethods: motel.paymentMethods,
          imageUrls: motel.imageUrls,
        )
        .description(motel.description)
        .generalLocation(motel.generalLocation)
        .execute();
    return result.data.motel_insert.id;
  }

  @override
  Future<String> createForOwner(Motel motel) async {
    final result = await _connector
        .adminCreateMotel(
          ownerId: motel.ownerId,
          name: motel.name,
          email: motel.email,
          roomCount: motel.roomCount,
          nit: motel.nit,
          address: motel.address,
          phone: motel.phone,
          paymentMethods: motel.paymentMethods,
          imageUrls: motel.imageUrls,
        )
        .description(motel.description)
        .generalLocation(motel.generalLocation)
        .execute();
    return result.data.motel_insert.id;
  }

  @override
  Future<int> updateMine(Motel motel) async {
    final result = await _connector
        .updateMyMotel(
          id: motel.id,
          name: motel.name,
          email: motel.email,
          roomCount: motel.roomCount,
          nit: motel.nit,
          address: motel.address,
          phone: motel.phone,
          paymentMethods: motel.paymentMethods,
          imageUrls: motel.imageUrls,
        )
        .description(motel.description)
        .generalLocation(motel.generalLocation)
        .execute();
    return result.data.motel_updateMany;
  }

  @override
  Future<void> updateAsAdmin(Motel motel) async {
    await _connector
        .adminUpdateMotel(
          id: motel.id,
          name: motel.name,
          email: motel.email,
          roomCount: motel.roomCount,
          nit: motel.nit,
          address: motel.address,
          phone: motel.phone,
          paymentMethods: motel.paymentMethods,
          imageUrls: motel.imageUrls,
          isAvailable: motel.isAvailable,
        )
        .description(motel.description)
        .generalLocation(motel.generalLocation)
        .execute();
  }

  @override
  Future<int> setMineAvailability(String id, bool isAvailable) async {
    final result = await _connector
        .setMyMotelAvailability(id: id, isAvailable: isAvailable)
        .execute();
    return result.data.motel_updateMany;
  }

  /// Todas las consultas usan el mismo fragmento (`MotelFields`), así que se
  /// mapea desde el JSON común en vez de repetir el mapeo por clase generada.
  static Motel _toMotel(Map<String, dynamic> json) => Motel(
    id: json['id'] as String,
    ownerId: json['ownerId'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    roomCount: json['roomCount'] as int,
    nit: json['nit'] as String,
    address: json['address'] as String,
    phone: json['phone'] as String,
    description: json['description'] as String?,
    generalLocation: json['generalLocation'] as String?,
    paymentMethods: List<String>.from(json['paymentMethods'] as List),
    imageUrls: List<String>.from(json['imageUrls'] as List),
    isAvailable: json['isAvailable'] as bool,
  );
}

/// Traduce los errores de SQL Connect a mensajes para el usuario.
String sqlConnectErrorMessage(Object error, {required String fallback}) {
  final text = _sqlConnectErrorMessages(error).join(' ').toLowerCase();
  if (text.contains('motels_nit_uidx') ||
      (text.contains('duplicate') && text.contains('nit'))) {
    return 'Ya existe un motel con ese NIT';
  }
  if (error is DataConnectError &&
      error.dataConnectErrorCode == DataConnectErrorCode.unauthorized) {
    return 'Debes iniciar sesión para administrar moteles';
  }
  if (text.contains('unauthenticated') || text.contains('unauthorized')) {
    return 'Debes iniciar sesión para administrar moteles';
  }
  if (text.contains('permission_denied') ||
      text.contains('permission denied')) {
    return 'SQL Connect no permitió la operación. Revisa los permisos de la sesión.';
  }
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('timed out')) {
    return 'No se pudo conectar con SQL Connect. Comprueba la conexión e inténtalo nuevamente.';
  }
  return fallback;
}

/// Keep nested GraphQL failures: the SDK's top-level message can be empty.
List<String> _sqlConnectErrorMessages(Object error) {
  final messages = <String>[error.toString()];
  if (error is DataConnectOperationError) {
    messages.addAll(error.response.errors.map((entry) => entry.message));
  }
  if (error is DataConnectError && error.message != null) {
    final message = error.message!;
    final match = RegExp(r"with a message '([\s\S]*)'$").firstMatch(message);
    if (match != null) {
      try {
        final body = jsonDecode(match.group(1)!);
        if (body is Map && body['error'] is Map) {
          final details = body['error'] as Map;
          messages.add(
            '${details['status'] ?? ''}: ${details['message'] ?? ''}',
          );
        }
      } on FormatException {
        // Some proxies return text rather than a JSON error envelope.
      }
    }
  }
  return messages;
}

/// Debug diagnostics only; never print the request, credentials or form data.
void logSqlConnectMotelError(Object error) {
  if (!kDebugMode) return;
  String redact(String text) => text
      .replaceAll(
        RegExp(r'Bearer\s+\S+', caseSensitive: false),
        'Bearer [redacted]',
      )
      .replaceAll(RegExp(r'\beyJ[A-Za-z0-9_.-]+'), '[token]')
      .replaceAll(RegExp(r'sb_[A-Za-z0-9_-]+'), '[key]')
      .replaceAll(
        RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
        '[email]',
      )
      .replaceAll(RegExp(r'\d{7,}'), '[number]')
      .replaceAll(RegExp(r'''(["']).*?\1'''), '[quoted]');
  debugPrint('Motel SQL Connect: ${error.runtimeType}');
  for (final message in _sqlConnectErrorMessages(error)) {
    final safe = redact(message);
    debugPrint(safe.length > 1200 ? '${safe.substring(0, 1200)}…' : safe);
  }
}
