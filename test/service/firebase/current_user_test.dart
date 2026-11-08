import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/controllers/booking/owner_view/owner_booking_controller.dart';
import 'package:machuco/service/firebase/current_user.dart';

void main() {
  group('without Firebase initialized', () {
    test('CurrentUser safe getters return null instead of throwing', () {
      expect(CurrentUser.uidOrNull, isNull);
      expect(CurrentUser.emailOrNull, isNull);
    });

    test('booking controllers fall back to the demo ids', () {
      final client = ClientBookingController();
      final owner = OwnerBookingController();
      addTearDown(client.dispose);
      addTearDown(owner.dispose);

      expect(client.userId, ClientBookingController.demoUserId);
      expect(owner.ownerId, OwnerBookingController.demoOwnerId);
    });

    test('an explicit id still wins over the session', () {
      final client = ClientBookingController(userId: 'uid-client');
      final owner = OwnerBookingController(ownerId: 'uid-owner');
      addTearDown(client.dispose);
      addTearDown(owner.dispose);

      expect(client.userId, 'uid-client');
      expect(owner.ownerId, 'uid-owner');
    });
  });
}
