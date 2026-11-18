import 'dart:async';
import 'package:bodylog/keep_page.dart';
import 'package:bodylog/keep_service.dart';
import 'package:bodylog/main.dart';
import 'package:bodylog/model.dart';
import 'package:bodylog/store.dart';
import 'package:bodylog/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeKeep extends KeepService {
  KeepCredentials? c = const KeepCredentials(
    token: 'fixture-secret',
    userId: 'fixture',
    username: 'Example',
  );
  bool support = true, fail = false;
  int accepted = 0, reads = 0;
  Completer<KeepCredentials?>? pending;
  @override
  bool get supported => support;
  @override
  KeepCredentials? get credentials => c;
  @override
  Future<KeepCredentials?> restore() async => c;
  @override
  Future<KeepLogin> startLogin() async => KeepLogin(
    'qr',
    Uri.parse('https://api.gotokeep.com/image/fixture'),
    Uri.parse('https://show.gotokeep.com/auth'),
  );
  @override
  Future<KeepCredentials?> checkLogin(KeepLogin login) async =>
      pending == null ? c : pending!.future;
  @override
  Future<void> acceptLogin(KeepCredentials value) async {
    accepted++;
    c = value;
  }

  @override
  Future<bool> disconnect() async {
    c = null;
    return true;
  }

  @override
  Future<KeepImport> read({required int days, DateTime? now}) async {
    reads++;
    if (fail) throw const KeepException('Keep 服务暂不可用，请稍后重试。');
    return KeepImport(
      samples: [
        KeepSample(
          account: 'fixture',
          date: DateTime(2026, 11, 17),
          kg: 70.2,
          fat: 22.4,
        ),
      ],
      height: 168,
      bmi: 24.9,
      raw: 'Synthetic fixture',
    );
  }
}

Widget host(Widget child, String locale) => MaterialApp(
  locale: Locale(locale),
  supportedLocales: const [Locale('zh'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: appleTheme(),
  home: child,
);
void main() {
  for (final locale in ['zh', 'en']) {
    testWidgets(
      '$locale previews before saving, preserves other data, deduplicates and disconnects without deleting records',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final api = FakeKeep();
        BodyData saved = BodyData(
          records: [
            Measurement(id: 'manual', time: DateTime(2026, 11, 17, 8), kg: 71),
          ],
        );
        var writes = 0;
        await tester.pumpWidget(
          host(
            KeepPage(
              initial: saved,
              service: api,
              onSave: (d) async {
                writes++;
                saved = d;
                return true;
              },
            ),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        final read = locale == 'zh' ? '读取 Keep 数据' : 'Read Keep data',
            confirm = locale == 'zh' ? '确认导入' : 'Confirm import';
        await tester.tap(find.text(read));
        await tester.pumpAndSettle();
        expect(writes, 0);
        expect(saved.keepSamples, isEmpty);
        final height = find.text(
          locale == 'zh' ? '使用 Keep 身高更新身体档案' : 'Use Keep height in my profile',
        );
        await tester.ensureVisible(height);
        await tester.tap(height);
        await tester.pumpAndSettle();
        expect(saved.height, 170);
        await tester.ensureVisible(find.text(confirm));
        await tester.tap(find.text(confirm));
        await tester.pumpAndSettle();
        expect(saved.keepSamples, hasLength(1));
        expect(saved.height, 168);
        expect(saved.records.single.id, 'manual');
        await tester.ensureVisible(find.text(read));
        await tester.tap(find.text(read));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(confirm));
        await tester.tap(find.text(confirm));
        await tester.pumpAndSettle();
        expect(saved.keepSamples, hasLength(1));
        final disconnect = find.text(locale == 'zh' ? '断开连接' : 'Disconnect');
        await tester.ensureVisible(disconnect);
        await tester.tap(disconnect);
        await tester.pumpAndSettle();
        expect(api.c, isNull);
        expect(saved.keepSamples, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'cancelling pending authorization does not save the late login result',
    (tester) async {
      final api =
          FakeKeep()
            ..c = null
            ..pending = Completer<KeepCredentials?>();
      await tester.pumpWidget(
        host(
          KeepPage(
            initial: BodyData(),
            service: api,
            onSave: (d) async => true,
          ),
          'zh',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('授权连接 Keep'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('取消连接'));
      await tester.tap(find.text('取消连接'));
      await tester.pumpAndSettle();
      api.pending!.complete(
        const KeepCredentials(token: 'late-secret', userId: 'a', username: 'A'),
      );
      await tester.pumpAndSettle();
      expect(api.accepted, 0);
      expect(api.reads, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Keep query failures preserve data and show no import preview', (
    tester,
  ) async {
    final api = FakeKeep()..fail = true;
    var writes = 0;
    await tester.pumpWidget(
      host(
        KeepPage(
          initial: BodyData(),
          service: api,
          onSave: (d) async {
            writes++;
            return true;
          },
        ),
        'zh',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('读取 Keep 数据'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('Keep 服务暂不可用，请稍后重试。'), findsOneWidget);
    expect(find.text('确认导入'), findsNothing);
  });
  testWidgets(
    'Keep date-only summary is visible on small screens and does not move for period changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        BodyStore.key:
            BodyData(
              keepSamples: [
                KeepSample(account: 'a', date: dayOf(DateTime.now()), kg: 70),
              ],
            ).encode(),
      });
      await tester.pumpWidget(const BodyApp());
      await tester.pumpAndSettle();
      expect(find.text('仅日期'), findsOneWidget);
      expect(find.text('00:00'), findsNothing);
      final pane = find.byKey(const ValueKey('day-records'));
      final rect = tester.getRect(pane);
      expect(
        tester.getRect(find.text('70.00')).bottom,
        lessThan(tester.getTopLeft(find.byType(FrostedTabs)).dy),
      );
      await tester.tap(find.text('早上'));
      await tester.pumpAndSettle();
      expect(find.text('70.00'), findsNothing);
      expect(tester.getRect(pane), rect);
      expect(tester.takeException(), isNull);
    },
  );
}
