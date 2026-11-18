import 'package:bodylog/health_page.dart';
import 'package:bodylog/health_service.dart';
import 'package:bodylog/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeService extends HealthService {
  @override
  bool get supported => true;
  @override
  bool get android => true;
  @override
  String get name => 'Health Connect';
  @override
  Future<bool> available() async => true;
  @override
  Future<HealthImport> read({
    required DateTime start,
    required DateTime end,
    required bool includeHeight,
  }) async => HealthImport([
    HealthSample(
      platform: 'Health Connect',
      sourceId: 'scale',
      sourceName: 'scale',
      uuid: 'w',
      kind: SampleKind.weight,
      time: DateTime(2026, 11, 17),
      value: 68,
    ),
    HealthSample(
      platform: 'Health Connect',
      sourceId: 'scale',
      sourceName: 'scale',
      uuid: 'f',
      kind: SampleKind.fat,
      time: DateTime(2026, 11, 17),
      value: 22,
    ),
  ], []);
}

void main() {
  testWidgets(
    'health import previews, deduplicates, persists and clears only local copies',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      BodyData saved = BodyData(
        records: [
          Measurement(id: 'manual', time: DateTime(2026, 11, 17), kg: 69),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: HealthPage(
            initial: saved,
            service: FakeService(),
            onSave: (next) async {
              saved = next;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('授权并读取'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(saved.healthSamples, isEmpty);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(saved.healthSamples, isEmpty);
      await tester.tap(find.text('授权并读取'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();
      expect(saved.healthSamples, hasLength(2));
      expect(saved.records.single.id, 'manual');
      await tester.tap(find.text('授权并读取'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();
      expect(saved.healthSamples, hasLength(2));
      await tester.tap(find.text('移除导入的本地副本'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('移除'));
      await tester.pumpAndSettle();
      expect(saved.healthSamples, isEmpty);
      expect(saved.records.single.id, 'manual');
    },
  );
}
