import 'dart:typed_data';
import 'package:bodylog/file_import_page.dart';
import 'package:bodylog/model.dart';
import 'package:bodylog/main.dart';
import 'package:bodylog/store.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List sampleBytes() {
  final e = Excel.createExcel();
  e['Sheet1'].appendRow(
    ['时间', '体重', '体脂率', '肌肉量', '体型'].map(TextCellValue.new).toList(),
  );
  e['Sheet1'].appendRow(
    [
      '2026/10/01 07:00',
      '140斤',
      '20%',
      '100斤',
      '匀称型',
    ].map(TextCellValue.new).toList(),
  );
  return Uint8List.fromList(e.encode()!);
}

void main() {
  testWidgets(
    'select file, preview before save, confirm, reimport skips duplicate',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      BodyData saved = BodyData();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: FileImportPage(
            initial: saved,
            onSave: (d) async {
              saved = d;
              return true;
            },
            selectFile: () async => ('Fitdays-test.xlsx', sampleBytes()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> choose() async {
        await tester.tap(find.text('选择 .xlsx 文件'));
        await tester.pump();
        for (var i = 0; i < 80; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump();
          if (find.text('确认导入').evaluate().isNotEmpty) break;
        }
        await tester.pumpAndSettle();
      }

      await choose();
      expect(saved.records, isEmpty);
      expect(find.text('确认导入'), findsOneWidget);
      await tester.ensureVisible(find.text('确认导入'));
      await tester.tap(find.text('确认导入'));
      await tester.pumpAndSettle();
      expect(saved.records.single.kg, 70);
      expect(saved.records.single.extras['体型'], '匀称型');
      await tester.ensureVisible(find.text('选择 .xlsx 文件'));
      await choose();
      expect(find.textContaining('新增 0 条 · 更新 0 条 · 重复 1 条'), findsOneWidget);
    },
  );
  testWidgets(
    'all original fields are visible; extra numeric trend switches; calendar weight stays',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final d = BodyData(
        records: [
          Measurement(
            id: 'imported',
            time: DateTime.now(),
            kg: 68.05,
            fat: 20,
            extras: {'肌肉量': '104.6斤', '体型': '匀称型', '基础代谢率': '1557kcal'},
          ),
        ],
      );
      SharedPreferences.setMockInitialValues({BodyStore.key: d.encode()});
      await tester.pumpWidget(const BodyApp());
      await tester.pumpAndSettle();
      expect(find.text('68.0'), findsOneWidget);
      await tester.tap(find.text('68.05'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看表格全部数据'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is SelectableText && w.data == '匀称型'),
        findsOneWidget,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('趋势'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('肌肉量').last);
      await tester.pumpAndSettle();
      expect(find.text('52.3 kg'), findsWidgets);
      expect(find.text('体型'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
