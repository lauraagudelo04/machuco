
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Single entry point for crash reports (Firebase Crashlytics).
///
/// Views and controllers never call Firebase directly. Implementations must
/// never throw, so a failed report can not break a user flow.
abstract interface class CrashReporter {
  /// An error thrown inside the Flutter framework (build, layout, gestures).
  Future<void> recordFlutterFatalError(FlutterErrorDetails details);

  /// An error that nobody caught (async code, platform channels) or one the
  /// app handled but wants to see in the console ([fatal] false).
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal});
}

/// Default implementation: discards every report. Used by tests.
class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {}
}

/// Sends the reports to Firebase Crashlytics.
class FirebaseCrashReporter implements CrashReporter {
  FirebaseCrashReporter({FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {
    try {
      await _crashlytics.recordFlutterFatalError(details);
    } catch (_) {
      // Best effort: reporting must not fail the app.
    }
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    try {
      await _crashlytics.recordError(error, stack, fatal: fatal);
    } catch (_) {
      // Best effort: reporting must not fail the app.
    }
  }
}

/// Connects the two global error hooks of Flutter to a [CrashReporter].
///
/// Call once from `main`, after `Firebase.initializeApp`.
abstract final class CrashReporting {
  static void install(CrashReporter reporter) {
    FlutterError.onError = reporter.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      reporter.recordError(error, stack, fatal: true);
      return true;
    };
  }
}
