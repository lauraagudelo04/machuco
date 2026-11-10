import 'dart:convert';

import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/repository/motel/motel_sql_connect_gateway.dart';

void main() {
  const fallback = 'No fue posible crear el motel';

  test(
    'reads the nested GraphQL constraint error instead of the generic SDK message',
    () {
      final error = DataConnectOperationError<Object?>(
        DataConnectErrorCode.other,
        'Failed to invoke operation: ',
        DataConnectOperationFailureResponse<Object?>(
          [
            DataConnectOperationFailureResponseErrorInfo(
              const [],
              'duplicate key value violates unique constraint "motels_nit_key"',
            ),
          ],
          null,
          null,
        ),
      );
      expect(
        sqlConnectErrorMessage(error, fallback: fallback),
        'Ya existe un motel con ese NIT',
      );
    },
  );

  test('recognizes a permission error inside the REST envelope', () {
    final body = jsonEncode({
      'error': {
        'status': 'PERMISSION_DENIED',
        'message': 'Operation is not permitted',
      },
    });
    final error = DataConnectError(
      DataConnectErrorCode.other,
      "Received a status code of 403 with a message '$body'",
    );
    expect(
      sqlConnectErrorMessage(error, fallback: fallback),
      'SQL Connect no permitió la operación. Revisa los permisos de la sesión.',
    );
  });

  test('network failures are not reported as a generic save failure', () {
    final error = DataConnectError(
      DataConnectErrorCode.unavailable,
      'SocketException: Failed host lookup',
    );
    expect(
      sqlConnectErrorMessage(error, fallback: fallback),
      'No se pudo conectar con SQL Connect. Comprueba la conexión e inténtalo nuevamente.',
    );
  });

  test('unknown failures keep the safe user message', () {
    expect(
      sqlConnectErrorMessage(Exception('unknown'), fallback: fallback),
      fallback,
    );
  });

  test('diagnostics redact credentials and quoted form values', () {
    final original = debugPrint;
    final logs = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
    try {
      logSqlConnectMotelError(
        DataConnectError(
          DataConnectErrorCode.other,
          'duplicate "Motel Confidencial" user@example.com 1234567890123 '
          'Bearer private-token eyJheader.payload.signature sb_publishable_sensitive',
        ),
      );
    } finally {
      debugPrint = original;
    }
    final text = logs.join('\n');
    expect(text, contains('duplicate'));
    for (final value in [
      'Motel Confidencial',
      'user@example.com',
      '1234567890123',
      'private-token',
      'eyJheader.payload.signature',
      'sb_publishable_sensitive',
    ]) {
      expect(text, isNot(contains(value)));
    }
  });
}
