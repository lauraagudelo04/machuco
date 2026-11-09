import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/database/repository/review/review_seed_data.dart';

void main() {
  test('cada reseña de ejemplo apunta a un motel de ejemplo existente', () async {
    final motelIds =
        (await MotelController().getAllMotels()).map((m) => m.id).toSet();

    for (final review in reviewSeedData()) {
      expect(motelIds, contains(review.motelId), reason: review.id);
    }
  });
}
