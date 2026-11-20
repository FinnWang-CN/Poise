import 'package:bodylog/main.dart';
import 'package:bodylog/model.dart';
import 'package:bodylog/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'calendar swipe changes month across year at $width without changing selected records',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          BodyStore.key:
              BodyData(
                records: [
                  Measurement(
                    id: 'one',
                    time: DateTime(now.year, now.month, now.day, 6),
                    kg: 68,
                  ),
                  Measurement(
                    id: 'two',
                    time: DateTime(now.year, now.month, now.day, 9),
                    kg: 69,
                  ),
                ],
              ).encode(),
        });
        await tester.pumpWidget(const BodyApp());
        await tester.pumpAndSettle();
        final calendar = find.byKey(const ValueKey('calendar-month-swipe'));
        final grid = find.byType(GridView).first;
        final localizations = MaterialLocalizations.of(tester.element(grid));
        final initial = DateTime(now.year, now.month);
        void expectMonth(DateTime month) => expect(
          find.text(localizations.formatMonthYear(month)),
          findsOneWidget,
        );
        expectMonth(initial);
        final pane = find.byKey(const ValueKey('day-records'));
        final paneRect = tester.getRect(pane);
        // A short slow horizontal movement and a vertical scroll must not switch months.
        await tester.drag(grid, const Offset(-12, 0));
        await tester.pumpAndSettle();
        expectMonth(initial);
        await tester.drag(grid, const Offset(0, -70));
        await tester.pumpAndSettle();
        expectMonth(initial);
        // Advance far enough to cross a year boundary, then return.
        final count = 13 - now.month;
        for (var i = 1; i <= count; i++) {
          await tester.drag(grid, Offset(-width * .65, 0));
          await tester.pumpAndSettle();
          expectMonth(DateTime(now.year, now.month + i));
        }
        for (var i = count - 1; i >= 0; i--) {
          await tester.drag(grid, Offset(width * .65, 0));
          await tester.pumpAndSettle();
          expectMonth(DateTime(now.year, now.month + i));
        }
        expect(tester.getRect(pane), paneRect);
        // The separate daily-record pager must not trigger the month gesture.
        await tester.drag(pane, const Offset(-230, 0));
        await tester.pumpAndSettle();
        expectMonth(initial);
        expect(tester.getRect(pane), paneRect);
        // Header buttons continue to use the same month navigation.
        await tester.tap(find.byTooltip('上个月'));
        await tester.pumpAndSettle();
        expectMonth(DateTime(now.year, now.month - 1));
        await tester.tap(find.byTooltip('下个月'));
        await tester.pumpAndSettle();
        expectMonth(initial);
        expect(calendar, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
