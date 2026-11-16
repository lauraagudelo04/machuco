import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/service/owner/owner_sync_scheduler.dart';

void main() {
  test(
    'respeta el retroceso y se detiene cuando la sincronización va bien',
    () {
      fakeAsync((async) {
        var attempts = 0;
        final scheduler = OwnerSyncRetryScheduler(
          attempt: () async => attempts++,
        );

        expect(scheduler.isScheduled, isFalse);

        scheduler.notifyNetworkFailure();
        expect(scheduler.isScheduled, isTrue);
        expect(scheduler.attempt, 1);

        async.elapse(const Duration(seconds: 2));
        expect(attempts, 1);
        expect(scheduler.isScheduled, isFalse);

        scheduler.notifyNetworkFailure();
        expect(scheduler.attempt, 2);
        async.elapse(const Duration(seconds: 5));
        expect(attempts, 2);

        scheduler.notifySuccess();
        expect(scheduler.attempt, 0);
        expect(scheduler.isScheduled, isFalse);

        scheduler.dispose();
      });
    },
  );

  test('se rinde tras ocho intentos y deja el botón manual', () {
    fakeAsync((async) {
      var attempts = 0;
      final scheduler = OwnerSyncRetryScheduler(
        attempt: () async => attempts++,
      );

      for (var i = 0; i < 8; i++) {
        scheduler.notifyNetworkFailure();
        expect(scheduler.isScheduled, isTrue);
        async.elapse(scheduler.delays[i]);
      }

      expect(attempts, 8);
      expect(scheduler.isExhausted, isTrue);

      scheduler.notifyNetworkFailure();
      expect(scheduler.isScheduled, isFalse);

      scheduler.dispose();
    });
  });

  test('retryNow ejecuta el intento sin esperar al temporizador', () {
    fakeAsync((async) {
      var attempts = 0;
      final scheduler = OwnerSyncRetryScheduler(
        attempt: () async => attempts++,
      );

      scheduler.notifyNetworkFailure();
      scheduler.retryNow();
      async.flushMicrotasks();

      expect(attempts, 1);

      scheduler.dispose();
    });
  });

  test('dispose cancela el reintento pendiente', () {
    fakeAsync((async) {
      var attempts = 0;
      final scheduler = OwnerSyncRetryScheduler(
        attempt: () async => attempts++,
      );

      scheduler.notifyNetworkFailure();
      scheduler.dispose();
      async.elapse(const Duration(minutes: 5));

      expect(attempts, 0);
      expect(scheduler.isScheduled, isFalse);
    });
  });

  test('avisa a la vista cuando cambia el estado', () {
    fakeAsync((async) {
      var changes = 0;
      final scheduler = OwnerSyncRetryScheduler(
        attempt: () async {},
        onStateChanged: () => changes++,
      );

      scheduler.notifyNetworkFailure();
      expect(changes, 1);
      async.elapse(const Duration(seconds: 2));
      scheduler.notifySuccess();
      expect(changes, greaterThanOrEqualTo(2));

      scheduler.dispose();
    });
  });
}
