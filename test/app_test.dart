import 'package:bodylog/main.dart';
import 'package:bodylog/store.dart';
import 'package:bodylog/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'create, persist and edit a measurement; show trend and switch units',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const BodyApp());
      await tester.pumpAndSettle();
      expect(find.text('这一天还没有记录'), findsOneWidget);
      await tester.tap(find.text('记一笔'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '68.5');
      await tester.enterText(find.byType(TextFormField).at(1), '22.3');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect((await BodyStore().load()).records.single.kg, 68.5);
      expect(find.text('68.50'), findsOneWidget);
      await tester.tap(find.text('68.50'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '68.2');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect((await BodyStore().load()).records.single.kg, 68.2);
      await tester.tap(find.text('趋势'));
      await tester.pumpAndSettle();
      expect(find.text('68.2 kg'), findsWidgets);
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect((await BodyStore().load()).jin, isTrue);
      await tester.pump(const Duration(seconds: 2));
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets('narrow layout $width, missing fat and delete confirmation', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      final initial = BodyData(
        records: [Measurement(id: 'one', time: now, kg: 68)],
      );
      SharedPreferences.setMockInitialValues({BodyStore.key: initial.encode()});
      await tester.pumpWidget(const BodyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('趋势'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('体脂率'));
      await tester.pumpAndSettle();
      expect(find.text('这个区间还没有数据'), findsOneWidget);
      await tester.tap(find.text('近一年'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BMI').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('日历'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('68.00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect((await BodyStore().load()).records, hasLength(1));
      await tester.tap(find.text('68.00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect((await BodyStore().load()).records, isEmpty);
      await tester.pump(const Duration(seconds: 2));
    });
  }
  testWidgets('corrupt storage is preserved and writes are blocked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({BodyStore.key: 'broken json'});
    await tester.pumpWidget(const BodyApp());
    await tester.pumpAndSettle();
    expect(find.text('重新读取'), findsOneWidget);
    expect(find.text('记一笔'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString(BodyStore.key),
      'broken json',
    );
  });
  test('store reload preserves data', () async {
    SharedPreferences.setMockInitialValues({});
    await BodyStore().save(
      BodyData(
        records: [
          Measurement(
            id: 'test',
            time: DateTime(2026, 11, 17),
            kg: 70,
            fat: 20,
          ),
        ],
      ),
    );
    final restored = await BodyStore().load();
    expect(restored.records.single.fat, 20);
  });
}
