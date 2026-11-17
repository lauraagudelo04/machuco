import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/utils/pqrs_response_date.dart';

void main() {
  // 2026-11-09 is a Monday.
  test('starting on Monday skips the weekend after five days', () {
    expect(addBusinessDays(DateTime(2026, 11, 9), 3), DateTime(2026, 11, 12));
    expect(addBusinessDays(DateTime(2026, 11, 9), 5), DateTime(2026, 11, 16));
  });

  test('starting on Friday the first business day is Monday', () {
    expect(addBusinessDays(DateTime(2026, 11, 13), 1), DateTime(2026, 11, 16));
  });

  test('starting on Saturday or Sunday counts from Monday', () {
    expect(addBusinessDays(DateTime(2026, 11, 14), 1), DateTime(2026, 11, 16));
    expect(addBusinessDays(DateTime(2026, 11, 15), 1), DateTime(2026, 11, 16));
  });

  test('zero days returns the same date', () {
    expect(addBusinessDays(DateTime(2026, 11, 14), 0), DateTime(2026, 11, 14));
  });
}
