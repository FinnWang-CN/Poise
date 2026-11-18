import 'package:bodylog/comparison.dart';
import 'package:bodylog/comparison_page.dart';
import 'package:bodylog/design.dart';
import 'package:bodylog/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final a = Measurement(
    id: 'a',
    time: DateTime(2026, 11, 17, 6),
    kg: 67.75,
    fat: 19.6,
    extras: {'肌肉量': '52 kg', 'BMI': '24.0', '体型': '标准', '含水量': '55 %'},
  );
  final b = Measurement(
    id: 'b',
    time: DateTime(2026, 11, 18, 20),
    kg: 69.15,
    extras: {
      '肌肉量': '106 斤',
      'BMI': '24.5',
      '体型': '健壮',
      '含水量': '30 kg',
      '骨量': '2.8 kg',
    },
  );
  final data = BodyData(records: [a, b], jin: true);
  test(
    'normalize mass units; use imported BMI; missing and mismatched units never become zero',
    () {
      final rows = compareRecords(data, a, b);
      expect(rows.first.difference, closeTo(2.8, .0001));
      expect(rows.first.left, '135.50 斤');
      expect(rows.firstWhere((r) => r.name == 'BMI').difference, .5);
      expect(rows.firstWhere((r) => r.name == '肌肉量').difference, 2);
      expect(rows.firstWhere((r) => r.name == '体脂率').right, '—');
      expect(rows.firstWhere((r) => r.name == '体脂率').difference, isNull);
      expect(rows.firstWhere((r) => r.name == '含水量').difference, isNull);
      expect(rows.firstWhere((r) => r.name == '骨量').left, '—');
      expect(rows.firstWhere((r) => r.name == '体型').right, '健壮');
      expect(compareRecords(data, b, a).first.difference, closeTo(-2.8, .0001));
    },
  );
  for (final locale in ['zh', 'en']) {
    testWidgets('comparison and record picker fit narrow $locale screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: appleTheme(),
          locale: Locale(locale),
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ComparisonPage(data: data),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byTooltip(locale == 'zh' ? '交换记录' : 'Swap records'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.text(locale == 'zh' ? '点击更换' : 'Tap to change').first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(locale == 'zh' ? '选择基准记录' : 'Choose baseline'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
