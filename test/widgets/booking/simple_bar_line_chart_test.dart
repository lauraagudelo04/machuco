import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/booking/simple_bar_line_chart.dart';

void main() {
  testWidgets('bars have non-zero width and are proportional to the values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SimpleBarLineChart(
            points: [
              ChartDataPoint(label: 'Ene', value: 100),
              ChartDataPoint(label: 'Feb', value: 50),
            ],
          ),
        ),
      ),
    );

    final bars = find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(DecoratedBox),
    );
    expect(bars, findsNWidgets(2));
    final big = tester.getSize(bars.at(0));
    final small = tester.getSize(bars.at(1));
    expect(big.width, greaterThan(0));
    expect(small.width, greaterThan(0));
    expect(big.height, greaterThan(small.height));
  });
}
