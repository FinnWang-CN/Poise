import 'package:bodylog/main.dart';
import 'package:bodylog/model.dart';
import 'package:bodylog/store.dart';
import 'package:bodylog/language.dart';
import 'package:bodylog/appearance.dart';
import 'package:bodylog/form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final locale in ['zh', 'en']) {
    testWidgets(
      '$locale profile and backup forms fit above keyboard with large text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 1400);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({LanguageStore.key: locale});
        await tester.pumpWidget(const BodyApp());
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'zh' ? '设置' : 'Settings'));
        await tester.pumpAndSettle();
        final profile = find.text(
          locale == 'zh' ? '身高与目标体重' : 'Height and goal weight',
        );
        await tester.scrollUntilVisible(
          profile,
          160,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(profile);
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(320, 640);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        final save = find.descendant(
          of: find.byType(FormSheet),
          matching: find.text(locale == 'zh' ? '保存' : 'Save'),
        );
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(360));
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.first, '180');
        await tester.ensureVisible(fields.last);
        await tester.enterText(fields.last, '70');
        await tester.tap(save);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        expect((await BodyStore().load()).height, 180);
        tester.view.resetViewInsets();
        tester.view.physicalSize = const Size(320, 1400);
        await tester.pumpAndSettle();
        final backup = find.text(
          locale == 'zh' ? '导入 JSON 备份' : 'Import JSON backup',
        );
        await tester.scrollUntilVisible(
          backup,
          160,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(backup);
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(320, 640);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        final validate = find.text(locale == 'zh' ? '校验备份' : 'Validate backup');
        expect(tester.getRect(validate).bottom, lessThanOrEqualTo(360));
        await tester.enterText(find.byType(TextField), 'invalid');
        await tester.tap(validate);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(locale == 'zh' ? '取消' : 'Cancel'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        tester.view.resetViewInsets();
        tester.view.physicalSize = const Size(320, 1400);
        await tester.pumpAndSettle();
        final export = find.text(
          locale == 'zh' ? '导出 JSON 备份' : 'Export JSON backup',
        );
        await tester.scrollUntilVisible(
          export,
          -160,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(export);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(locale == 'zh' ? '关闭' : 'Close'));
        await tester.pumpAndSettle();
      },
    );
    testWidgets(
      '$locale editor labels and save stay visible above keyboard on 320px screen',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        SharedPreferences.setMockInitialValues({
          LanguageStore.key: locale,
          AppearanceStore.key: locale == 'en' ? 'dark' : 'light',
          BodyStore.key: BodyData().encode(),
        });
        await tester.pumpWidget(const BodyApp());
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'zh' ? '记一笔' : 'Add entry'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        final sheet = find.byType(FormSheet);
        final label = find.descendant(
          of: sheet,
          matching: find.text(locale == 'zh' ? '体重' : 'Weight'),
        );
        final save = find.descendant(
          of: sheet,
          matching: find.text(locale == 'zh' ? '保存' : 'Save'),
        );
        expect(label, findsOneWidget);
        expect(
          tester.getRect(label).top,
          greaterThanOrEqualTo(tester.getRect(sheet).top),
        );
        expect(tester.getRect(label).bottom, lessThan(360));
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(360));
        expect(
          tester
              .getSize(
                find.descendant(
                  of: sheet,
                  matching: find.byKey(const ValueKey('form-submit')),
                ),
              )
              .width,
          lessThan(160),
        );
        final weight = find.byKey(const ValueKey('manual-weight'));
        expect(
          tester
              .widget<TextField>(
                find.descendant(of: weight, matching: find.byType(TextField)),
              )
              .decoration
              ?.labelText,
          isNull,
        );
        await tester.enterText(weight, '70.5');
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect((await BodyStore().load()).records.single.kg, 70.5);
        expect(sheet, findsNothing);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
