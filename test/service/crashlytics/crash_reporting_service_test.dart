import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/service/crashlytics/crash_reporting_service.dart';

class _RecordingReporter implements CrashReporter {
  final flutterErrors = <FlutterErrorDetails>[];
  final errors = <({Object error, bool fatal})>[];

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {
    flutterErrors.add(details);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    errors.add((error: error, fatal: fatal));
  }
}

void main() {
  late FlutterExceptionHandler? previousFlutterHandler;
  late ErrorCallback? previousPlatformHandler;

  setUp(() {
    previousFlutterHandler = FlutterError.onError;
    previousPlatformHandler = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = previousFlutterHandler;
    PlatformDispatcher.instance.onError = previousPlatformHandler;
  });

  test('framework errors are sent as fatal Flutter errors', () {
    final reporter = _RecordingReporter();
    CrashReporting.install(reporter);

    final details = FlutterErrorDetails(exception: StateError('boom'));
    FlutterError.onError!(details);

    expect(reporter.flutterErrors, [details]);
    expect(reporter.errors, isEmpty);
  });

  test('uncaught async errors are sent as fatal and marked as handled', () {
    final reporter = _RecordingReporter();
    CrashReporting.install(reporter);

    final error = StateError('async boom');
    final handled = PlatformDispatcher.instance.onError!(
      error,
      StackTrace.current,
    );

    expect(handled, isTrue);
    expect(reporter.errors.single.error, error);
    expect(reporter.errors.single.fatal, isTrue);
  });

  test('install exposes the reporter for already handled errors', () {
    final reporter = _RecordingReporter();
    CrashReporting.install(reporter);

    CrashReporting.reporter.recordError(StateError('handled'), null);

    expect(reporter.errors.single.fatal, isFalse);
  });

  test('a reporter that throws does not break the error hooks', () {
    CrashReporting.install(_ThrowingReporter());

    expect(
      () => FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('boom')),
      ),
      returnsNormally,
    );
    expect(
      PlatformDispatcher.instance.onError!(
        StateError('boom'),
        StackTrace.empty,
      ),
      isTrue,
    );
  });
}

class _ThrowingReporter implements CrashReporter {
  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) =>
      throw StateError('sync failure');

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async => throw StateError('async failure');
}
