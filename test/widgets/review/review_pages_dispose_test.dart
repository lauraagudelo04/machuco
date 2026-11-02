import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/controllers/review/owner_review_controller.dart';
import 'package:machuco/controllers/review/review_administration_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/repositories/review/review_repository.dart';
import 'package:machuco/views/review/owner_view/owner_review_page.dart';
import 'package:machuco/views/review/review_administration_page.dart';

Motel _motel(String id, String name) => Motel(
  id: id,
  ownerId: 'owner-test',
  name: name,
  email: '$id@test.com',
  roomCount: 1,
  nit: '900',
  address: 'Calle 1',
  phone: '300',
  paymentMethods: const [],
  imageUrls: const [],
);

class _FakeMotelController extends MotelController {
  _FakeMotelController(this.motels);

  final List<Motel> motels;

  @override
  Future<List<Motel>> getMyMotels() async => motels;
}

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

/// Un controller ya dispuesto lanza al escuchar o al notificar; por eso basta
/// con usarlo después de retirar la página para demostrar que sigue vivo.
void _expectStillAlive(ChangeNotifier controller, VoidCallback notify) {
  var notified = 0;
  controller.addListener(() => notified++);
  expect(notify, returnsNormally);
  controller.notifyListeners();
  expect(notified, 2);
}

void main() {
  testWidgets('OwnerReviewPage no dispone el controller inyectado', (
    tester,
  ) async {
    final controller = OwnerReviewController(
      motelController: _FakeMotelController([
        _motel('motel-eclipse', 'Motel Eclipse'),
      ]),
      repository: InMemoryReviewRepository(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(OwnerReviewPage(controller: controller)));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());

    _expectStillAlive(controller, () => controller.selectMotel(null));
    expect(controller.isLoading, isFalse);
  });

  testWidgets('ReviewAdministrationPage no dispone el controller inyectado', (
    tester,
  ) async {
    final controller = ReviewAdministrationController(
      repository: InMemoryReviewRepository(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(ReviewAdministrationPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());

    _expectStillAlive(controller, () => controller.setQuery('motel'));
    expect(controller.isLoading, isFalse);
  });
}
