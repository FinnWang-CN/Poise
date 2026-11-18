import 'package:bodylog/main.dart';
import 'package:bodylog/design.dart';
import 'package:bodylog/model.dart';
import 'package:bodylog/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets(
      'day summary stays above navigation at $size, including six-week months',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          BodyStore.key:
              BodyData(
                records: [
                  Measurement(
                    id: 'pinned',
                    time: now,
                    kg: 68.5,
                    fat: 22,
                    note: '当天测量',
                  ),
                ],
              ).encode(),
        });
        await tester.pumpWidget(const BodyApp());
        await tester.pumpAndSettle();
        final navTop = tester.getTopLeft(find.byType(FrostedTabs)).dy;
        final before = tester.getRect(find.text('68.50'));
        expect(before.top, greaterThan(0));
        expect(before.bottom, lessThan(navTop));
        // Reach a six-row month without selecting another day; current day's summary remains pinned.
        var month = DateTime(now.year, now.month);
        bool reached = false;
        for (var i = 0; i < 12; i++) {
          final weeks =
              ((DateTime(month.year, month.month, 1).weekday % 7 +
                          DateTime(month.year, month.month + 1, 0).day) /
                      7)
                  .ceil();
          if (weeks == 6) {
            reached = true;
            break;
          }
          await tester.tap(find.byTooltip('上个月'));
          await tester.pumpAndSettle();
          month = DateTime(month.year, month.month - 1);
        }
        expect(reached, isTrue);
        expect(tester.getRect(find.text('68.50')).bottom, lessThan(navTop));
        await tester.drag(
          find.byKey(const ValueKey('calendar-scroll')),
          const Offset(0, -180),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('68.50')), before);
      },
    );
  }
  testWidgets(
    'multiple daily records swipe horizontally without moving the calendar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final n = DateTime.now();
      final records = List.generate(
        5,
        (i) => Measurement(
          id: 'r$i',
          time: DateTime(n.year, n.month, n.day, 6 + i),
          kg: 68 + i * .1,
          fat: 20 + i * .1,
        ),
      );
      SharedPreferences.setMockInitialValues({
        BodyStore.key: BodyData(records: records).encode(),
      });
      await tester.pumpWidget(const BodyApp());
      await tester.pumpAndSettle();
      final dayPanel = find.byKey(const ValueKey('day-records'));
      expect(find.text('68.40'), findsOneWidget);
      expect(find.textContaining('1 / 5'), findsOneWidget);
      await tester.drag(dayPanel, const Offset(-340, 0));
      await tester.pumpAndSettle();
      expect(find.text('68.30'), findsOneWidget);
      expect(find.textContaining('2 / 5'), findsOneWidget);
      expect(
        tester.getRect(find.text('68.30')).bottom,
        lessThan(tester.getTopLeft(find.byType(FrostedTabs)).dy),
      );
    },
  );
  testWidgets(
    'one record hugs the navigation with no reserved multi-record space',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        BodyStore.key:
            BodyData(
              records: [
                Measurement(
                  id: 'one',
                  time: DateTime.now(),
                  kg: 68.5,
                  fat: 22,
                  note: '单条测量',
                ),
              ],
            ).encode(),
      });
      await tester.pumpWidget(const BodyApp());
      await tester.pumpAndSettle();
      final noteBottom = tester.getRect(find.text('单条测量')).bottom;
      final navTop = tester.getTopLeft(find.byType(FrostedTabs)).dy;
      expect(navTop - noteBottom, lessThanOrEqualTo(36));
      expect(navTop - noteBottom, greaterThanOrEqualTo(12));
    },
  );
  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets('date changes and empty days keep calendar geometry at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      final otherDay = now.day == 1 ? 2 : 1;
      SharedPreferences.setMockInitialValues({
        BodyStore.key:
            BodyData(
              records: [
                Measurement(
                  id: 'with-note',
                  time: now,
                  kg: 69,
                  fat: 20,
                  note: 'Fitdays 文件导入',
                ),
                Measurement(
                  id: 'without-note',
                  time: now.subtract(const Duration(minutes: 1)),
                  kg: 68,
                ),
              ],
            ).encode(),
      });
      await tester.pumpWidget(const BodyApp());
      await tester.pumpAndSettle();
      final pane = find.byKey(const ValueKey('day-records'));
      final calendar = find.byType(GridView);
      final paneRect = tester.getRect(pane);
      final calendarRect = tester.getRect(calendar);
      await tester.drag(pane, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(pane), paneRect);
      expect(tester.getRect(calendar), calendarRect);
      await tester.tap(
        find.descendant(of: calendar, matching: find.text('$otherDay')).first,
      );
      await tester.pump();
      expect(tester.getRect(pane), paneRect);
      expect(tester.getRect(calendar), calendarRect);
      await tester.pumpAndSettle();
      expect(find.text('这一天还没有记录'), findsOneWidget);
      expect(tester.getRect(pane), paneRect);
      expect(tester.getRect(calendar), calendarRect);
      await tester.tap(
        find.descendant(of: calendar, matching: find.text('${now.day}')).first,
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(pane), paneRect);
      expect(tester.getRect(calendar), calendarRect);
      expect(tester.takeException(), isNull);
    });
  }
}
