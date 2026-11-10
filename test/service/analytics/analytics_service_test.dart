import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/service/analytics/analytics_service.dart';

import 'recording_analytics_service.dart';

void main() {
  test('the default provider discards events without Firebase', () async {
    expect(AnalyticsServiceProvider.instance, isA<NoopAnalyticsService>());
    await AnalyticsServiceProvider.instance.logEvent('any_event', {'a': 1});
  });

  group('AnalyticsRouteObserver', () {
    late RecordingAnalyticsService analytics;
    late GlobalKey<NavigatorState> navigator;

    Future<void> pumpApp(WidgetTester tester) async {
      analytics = RecordingAnalyticsService();
      navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [
            AnalyticsRouteObserver(
              rootScreenName: 'login',
              analytics: analytics,
            ),
          ],
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Text(settings.name ?? ''),
          ),
        ),
      );
    }

    testWidgets('reports the initial and every pushed named route', (
      tester,
    ) async {
      await pumpApp(tester);
      navigator.currentState!.pushNamed('/client/motels');
      await tester.pumpAndSettle();

      expect(analytics.screens, ['login', '/client/motels']);
    });

    testWidgets('reports the visible route again when going back', (
      tester,
    ) async {
      await pumpApp(tester);
      navigator.currentState!.pushNamed('/client/motels');
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(analytics.screens, ['login', '/client/motels', 'login']);
    });

    testWidgets('reports the new route of a replacement', (tester) async {
      await pumpApp(tester);
      navigator.currentState!.pushReplacementNamed('/owner/motels');
      await tester.pumpAndSettle();

      expect(analytics.screens, ['login', '/owner/motels']);
    });

    testWidgets('ignores unnamed routes and dialogs', (tester) async {
      await pumpApp(tester);
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('unnamed')),
      );
      await tester.pumpAndSettle();
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const Text('dialog'),
      );
      await tester.pumpAndSettle();

      expect(analytics.screens, ['login']);
    });
  });
}
