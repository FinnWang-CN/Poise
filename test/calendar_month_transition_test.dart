import 'package:bodylog/calendar_month_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'grid enters from the correct side; rapid reversal settles on latest month',
    (tester) async {
      final month = ValueNotifier(DateTime(2026, 12));
      addTearDown(month.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 40, child: Text('Header')),
                SizedBox(
                  width: 300,
                  child: ValueListenableBuilder<DateTime>(
                    valueListenable: month,
                    builder:
                        (context, value, _) => CalendarMonthTransition(
                          month: value,
                          child: SizedBox(
                            key: ValueKey('${value.year}-${value.month}'),
                            height: value.month == 1 ? 240 : 200,
                            child: Text('${value.month}'),
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: 60, child: Text('Record card')),
              ],
            ),
          ),
        ),
      );
      final base = tester.getTopLeft(find.text('12')).dx;
      final header = tester.getRect(find.text('Header'));
      month.value = DateTime(2027, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(tester.getTopLeft(find.text('1')).dx, greaterThan(base));
      expect(tester.getRect(find.text('Header')), header);
      month.value = DateTime(2026, 12);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getTopLeft(find.text('12')).dx, lessThan(base));
      expect(find.text('12'), findsOneWidget);
      month.value = DateTime(2026, 11);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 230));
      await tester.pump();
      expect(find.text('11'), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(find.text('12'), findsNothing);
      expect(tester.getTopLeft(find.text('11')).dx, base);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reduced motion switches immediately', (tester) async {
    final month = ValueNotifier(DateTime(2026, 12));
    addTearDown(month.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ValueListenableBuilder<DateTime>(
            valueListenable: month,
            builder:
                (context, value, _) => CalendarMonthTransition(
                  month: value,
                  child: SizedBox(
                    width: 300,
                    height: 200,
                    child: Text('${value.month}'),
                  ),
                ),
          ),
        ),
      ),
    );
    month.value = DateTime(2027, 1);
    await tester.pump();
    expect(find.text('12'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
