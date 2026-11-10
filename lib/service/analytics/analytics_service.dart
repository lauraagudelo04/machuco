import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Single entry point for usage analytics (Firebase Analytics).
///
/// Controllers and services report events through this interface; views never
/// call Firebase directly. Analytics is best effort: implementations must
/// never throw, so a failed report can not break a user flow.
abstract interface class AnalyticsService {
  /// Custom event. [name] must be snake_case (at most 40 characters) and the
  /// parameter values strings or numbers. Never send personal data
  /// (names, emails, phone numbers).
  Future<void> logEvent(String name, [Map<String, Object>? parameters]);

  /// A screen became visible.
  Future<void> logScreenView(String screenName);

  /// Recommended `login` event; [method] is one of [AnalyticsLoginMethod].
  Future<void> logLogin(String method);

  /// Recommended `sign_up` event; [method] is one of [AnalyticsLoginMethod].
  Future<void> logSignUp(String method);

  /// Associates the next events with the Firebase uid and the role
  /// (`client`, `owner`, `admin`). `null` clears them (logout).
  Future<void> setUser({String? id, String? role});
}

/// Names of the custom events. Every new event goes here so the whole team
/// reports the same name.
abstract final class AnalyticsEvents {
  static const reservationCreated = 'reservation_created';
  static const reservationPaid = 'reservation_paid';
  static const reservationCancelled = 'reservation_cancelled';
}

/// Values of the `method` parameter of `login` and `sign_up`.
abstract final class AnalyticsLoginMethod {
  static const password = 'password';
  static const google = 'google';
  static const github = 'github';
}

/// User property that holds the role, to segment reports by role.
const analyticsRoleProperty = 'user_role';

/// Default implementation: discards every event. Used by tests and until
/// `main` calls [AnalyticsServiceProvider.useFirebase].
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {}

  @override
  Future<void> logScreenView(String screenName) async {}

  @override
  Future<void> logLogin(String method) async {}

  @override
  Future<void> logSignUp(String method) async {}

  @override
  Future<void> setUser({String? id, String? role}) async {}
}

/// Sends the events to Firebase Analytics. Errors are logged and swallowed.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService([FirebaseAnalytics? analytics])
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) =>
      _guard(
        name,
        () => _analytics.logEvent(name: name, parameters: parameters),
      );

  @override
  Future<void> logScreenView(String screenName) => _guard(
    'screen_view',
    () => _analytics.logScreenView(screenName: screenName),
  );

  @override
  Future<void> logLogin(String method) =>
      _guard('login', () => _analytics.logLogin(loginMethod: method));

  @override
  Future<void> logSignUp(String method) =>
      _guard('sign_up', () => _analytics.logSignUp(signUpMethod: method));

  @override
  Future<void> setUser({String? id, String? role}) =>
      _guard('set_user', () async {
        await _analytics.setUserId(id: id);
        await _analytics.setUserProperty(
          name: analyticsRoleProperty,
          value: role,
        );
      });

  Future<void> _guard(String label, Future<void> Function() report) async {
    try {
      await report();
    } catch (error) {
      debugPrint('No se pudo registrar el evento de analítica $label: $error');
    }
  }
}

/// Holds the active [AnalyticsService], following the provider pattern of the
/// repositories: a no-op default for tests, switched to Firebase in `main`.
class AnalyticsServiceProvider {
  const AnalyticsServiceProvider._();

  static AnalyticsService instance = const NoopAnalyticsService();

  /// Called once from `main` after `Firebase.initializeApp`.
  static void useFirebase() {
    instance = FirebaseAnalyticsService();
  }
}

/// Reports a `screen_view` with the route name every time a named route
/// becomes visible (push, replace or returning with "back"). Unnamed routes
/// (dialogs, bottom sheets, `MaterialPageRoute` without settings) are
/// ignored. The root route (`/`, the `home` of `MaterialApp`) is reported as
/// [rootScreenName].
class AnalyticsRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  AnalyticsRouteObserver({
    this.rootScreenName = Navigator.defaultRouteName,
    AnalyticsService? analytics,
  }) : _analytics = analytics;

  final String rootScreenName;
  final AnalyticsService? _analytics;

  AnalyticsService get _service =>
      _analytics ?? AnalyticsServiceProvider.instance;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _report(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _report(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _report(previousRoute);
  }

  void _report(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    unawaited(
      _service.logScreenView(
        name == Navigator.defaultRouteName ? rootScreenName : name,
      ),
    );
  }
}
