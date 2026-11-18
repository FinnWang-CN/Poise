import 'package:bodylog/main.dart';
import 'package:bodylog/language.dart';
import 'package:bodylog/store.dart';
import 'package:bodylog/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('catalog interpolates summaries and leaves user content intact', () {
    expect(english('本地 12 条 · 健康 3 条'), 'Local: 12 · Health: 3');
    expect(english('2026-11-18 · 全天'), '2026-11-18 · All day');
    expect(
      english('导入完成：新增 2 条，更新 1 条，重复 3 条。'),
      'Import complete: 2 added, 1 updated, 3 duplicates.',
    );
    expect(english('肌肉量'), 'Muscle mass');
    expect(english('我的备注保持原样'), '我的备注保持原样');
  });
  testWidgets(
    'language switches immediately and persists without changing records',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final initial =
          BodyData(
            records: [
              Measurement(
                id: 'private-note',
                time: DateTime.now(),
                kg: 68,
                note: '我的备注保持原样',
              ),
            ],
          ).encode();
      SharedPreferences.setMockInitialValues({BodyStore.key: initial});
      await tester.pumpWidget(const BodyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Import Fitdays file'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(LanguageStore.key),
        'en',
      );
      expect(
        (await SharedPreferences.getInstance()).getString(BodyStore.key),
        initial,
      );
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      expect(find.text('Poise'), findsOneWidget);
      expect(find.text('我的备注保持原样'), findsOneWidget);
      await tester.tap(find.text('Add entry'));
      await tester.pumpAndSettle();
      expect(find.text('Add measurement'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const BodyApp());
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(tester.element(find.byType(Home))).languageCode,
        'en',
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      expect(find.text('个人设置'), findsOneWidget);
      expect(find.text('语言'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('system language tracks supported platform locale', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({LanguageStore.key: 'system'});
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const BodyApp());
    await tester.pumpAndSettle();
    expect(find.text('Poise'), findsOneWidget);
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    await tester.pumpAndSettle();
    expect(find.text('轻衡'), findsOneWidget);
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('English calendar and editor fit $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({LanguageStore.key: 'en'});
      await tester.pumpWidget(const BodyApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'English empty calendar');
      expect(find.text('No entries for this day'), findsOneWidget);
      await tester.tap(find.text('Add entry'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'English editor');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter 10–500 kg'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'English trends and data-source pages remain usable on narrow screens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        LanguageStore.key: 'en',
        BodyStore.key:
            BodyData(
              records: [
                Measurement(
                  id: 'today',
                  time: now,
                  kg: 68,
                  fat: 20,
                  extras: {'肌肉量': '48kg'},
                ),
                Measurement(
                  id: 'yesterday',
                  time: now.subtract(const Duration(days: 1)),
                  kg: 69,
                  fat: 21,
                ),
              ],
            ).encode(),
      });
      await tester.pumpWidget(const BodyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trends'));
      await tester.pumpAndSettle();
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Body fat'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Import Fitdays file'));
      await tester.tap(find.text('Import Fitdays file'));
      await tester.pumpAndSettle();
      expect(find.text('Import history'), findsOneWidget);
      expect(find.text('Choose .xlsx file'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Health data'));
      await tester.tap(find.text('Health data'));
      await tester.pumpAndSettle();
      expect(find.text('Connect health data'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('How your data is used'), 250, scrollable: find.byType(Scrollable).last);
      expect(find.text('How your data is used'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
