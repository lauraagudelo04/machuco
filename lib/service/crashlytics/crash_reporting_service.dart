import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Single entry point for crash reports (Firebase Crashlytics).
///
/// Views and controllers never call Firebase directly. Implementations must
/// never throw, so a failed report can not break a user flow.
///
/// Reports leave the device with the error message and stack trace: never put
/// personal data (names, emails, phone numbers) in an error message.
abstract interface class CrashReporter {
  /// An error thrown inside the Flutter framework (build, layout, gestures).
  Future<void> recordFlutterFatalError(FlutterErrorDetails details);

  /// An error that nobody caught (async code, platform channels) or one the
  /// app handled but wants to see in the console ([fatal] false).
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  });
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
/// Call once from `main`, after `Firebase.initializeApp`. Afterwards,
/// [reporter] is the entry point to report errors the app already handled.
abstract final class CrashReporting {
  static CrashReporter reporter = const NoopCrashReporter();

  static void install(CrashReporter newReporter) {
    reporter = newReporter;
    FlutterError.onError = (details) {
      // Crashlytics replaces the default handler, so keep the console dump
      // that developers rely on while debugging.
      if (kDebugMode) FlutterError.presentError(details);
      _safely(() => newReporter.recordFlutterFatalError(details));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _safely(() => newReporter.recordError(error, stack, fatal: true));
      return true;
    };
  }

  /// A reporter must never break the app, even if it breaks its own contract.
  static void _safely(Future<void> Function() report) {
    try {
      report().catchError((Object _) {});
    } catch (_) {
      // Best effort: reporting must not fail the app.
    }
  }
}
