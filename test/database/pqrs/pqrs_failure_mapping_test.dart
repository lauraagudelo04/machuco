import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/repository/pqrs/firestore_pqrs_repository.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';

PqrsFailure _map(String code) => pqrsFailureFromError(
  FirebaseException(plugin: 'cloud_firestore', code: code),
);

void main() {
  group('pqrsFailureFromError', () {
    test('network and timeout errors are retryable connection failures', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        final failure = _map(code);
        expect(failure.kind, PqrsFailureKind.connection);
        expect(failure.isRetryable, isTrue);
      }
      final timeout = pqrsFailureFromError(TimeoutException('x'));
      expect(timeout.kind, PqrsFailureKind.connection);
    });

    test('permission-denied is a permission failure, not retryable', () {
      final failure = _map('permission-denied');
      expect(failure.kind, PqrsFailureKind.permission);
      expect(failure.isRetryable, isFalse);
    });

    test('failed-precondition is told apart from connection and permission', () {
      final failure = _map('failed-precondition');
      expect(failure.kind, PqrsFailureKind.validation);
      expect(failure.isRetryable, isFalse);
      expect(failure.message, isNot(contains('conexión')));
    });

    test('not-found, unknown codes and odd errors are classified', () {
      expect(_map('not-found').kind, PqrsFailureKind.notFound);
      expect(_map('internal').kind, PqrsFailureKind.unknown);
      expect(
        pqrsFailureFromError(const FormatException('x')).kind,
        PqrsFailureKind.unknown,
      );
      expect(
        pqrsFailureFromError(StateError('x')).kind,
        PqrsFailureKind.unknown,
      );
    });

    test('an existing PqrsFailure is returned unchanged', () {
      const original = PqrsFailure(PqrsFailureKind.validation, 'x');
      expect(identical(pqrsFailureFromError(original), original), isTrue);
    });

    test('messages never echo the Firebase message', () {
      final failure = pqrsFailureFromError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'pqrs/secret-id leaked',
        ),
      );
      expect(failure.message, isNot(contains('secret')));
    });
  });
}
