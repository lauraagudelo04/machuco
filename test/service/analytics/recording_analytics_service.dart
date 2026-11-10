import 'package:machuco/service/analytics/analytics_service.dart';

/// One reported call, kept in order for assertions.
typedef RecordedEvent = ({String name, Map<String, Object> parameters});

/// Test double that records every call instead of sending it.
class RecordingAnalyticsService implements AnalyticsService {
  final List<RecordedEvent> events = [];
  final List<String> screens = [];
  final List<({String? id, String? role})> users = [];

  List<String> get eventNames => [for (final event in events) event.name];

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    events.add((name: name, parameters: parameters ?? const {}));
  }

  @override
  Future<void> logScreenView(String screenName) async {
    screens.add(screenName);
  }

  @override
  Future<void> logLogin(String method) async {
    events.add((name: 'login', parameters: {'method': method}));
  }

  @override
  Future<void> logSignUp(String method) async {
    events.add((name: 'sign_up', parameters: {'method': method}));
  }

  @override
  Future<void> setUser({String? id, String? role}) async {
    users.add((id: id, role: role));
  }
}
