import 'dart:async';
import 'package:bodylog/main.dart';
import 'package:bodylog/health_service.dart';
import 'package:bodylog/health_sync.dart';
import 'package:bodylog/model.dart';
import 'package:bodylog/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

HealthSample reading(double value) => HealthSample(
  platform: 'Health Connect',
  sourceId: 'scale',
  sourceName: 'Scale',
  uuid: 'same-id',
  kind: SampleKind.weight,
  time: DateTime.now(),
  value: value,
);

class AutoService extends HealthService {
  int calls = 0;
  bool fail = false, platformSupported = true;
  bool? gotHeight;
  int? gotDays;
  Completer<HealthImport>? pending;
  @override
  bool get supported => platformSupported;
  @override
  bool get android => true;
  @override
  Future<HealthImport> readAuthorized({
    required DateTime start,
    required DateTime end,
    required bool includeHeight,
  }) async {
    calls++;
    gotHeight = includeHeight;
    gotDays = end.difference(start).inDays;
    if (fail) throw StateError('health unavailable');
    if (pending != null) return pending!.future;
    return HealthImport([reading(68)], []);
  }
}

void main() {
  Future<void> open(WidgetTester tester, AutoService service) async {
    await tester.pumpWidget(BodyApp(healthService: service));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'startup migrates connected users and upserts without changing manual records',
    (tester) async {
      final manual = Measurement(
        id: 'manual',
        time: DateTime.now(),
        kg: 70,
        note: 'keep me',
      );
      SharedPreferences.setMockInitialValues({
        BodyStore.key:
            BodyData(records: [manual], healthSamples: [reading(69)]).encode(),
      });
      final service = AutoService();
      await open(tester, service);
      final saved = await BodyStore().load();
      expect(service.calls, 1);
      expect(service.gotDays, 30);
      expect(service.gotHeight, false);
      expect(saved.healthSamples, hasLength(1));
      expect(saved.healthSamples.single.value, 68);
      expect(saved.records.single.note, 'keep me');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(service.calls, 1); // rapid resumes do not duplicate a launch sync
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await open(tester, service);
      expect(service.calls, 2);
      expect((await BodyStore().load()).healthSamples, hasLength(1));
    },
  );
  for (final scenario in ['unconnected', 'disabled', 'unsupported', 'failed']) {
    testWidgets('$scenario automatic sync preserves local data', (
      tester,
    ) async {
      final data =
          BodyData(
            records: [Measurement(id: 'manual', time: DateTime.now(), kg: 70)],
          ).encode();
      SharedPreferences.setMockInitialValues({
        BodyStore.key: data,
        if (scenario != 'unconnected') HealthSyncSettings.connectedKey: true,
        if (scenario == 'disabled') HealthSyncSettings.enabledKey: false,
      });
      final service =
          AutoService()
            ..fail = scenario == 'failed'
            ..platformSupported = scenario != 'unsupported';
      await open(tester, service);
      expect(service.calls, scenario == 'failed' ? 1 : 0);
      expect(
        (await SharedPreferences.getInstance()).getString(BodyStore.key),
        data,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('an in-flight sync cannot overwrite a manual save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      HealthSyncSettings.connectedKey: true,
      HealthSyncSettings.heightKey: true,
      HealthSyncSettings.daysKey: 365,
    });
    final service = AutoService()..pending = Completer<HealthImport>();
    await open(tester, service);
    expect(service.calls, 1);
    expect(service.gotDays, 30);
    expect(service.gotHeight, true);
    await tester.tap(find.text('记一笔'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '71');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    service.pending!.complete(HealthImport([reading(68)], []));
    await tester.pumpAndSettle();
    final saved = await BodyStore().load();
    expect(saved.records.single.kg, 71);
    expect(saved.healthSamples, isEmpty);
  });
  testWidgets('turning auto-sync off cancels an in-flight result', (
    tester,
  ) async {
    final data = BodyData(healthSamples: [reading(69)]).encode();
    SharedPreferences.setMockInitialValues({BodyStore.key: data});
    final service = AutoService()..pending = Completer<HealthImport>();
    await open(tester, service);
    await HealthSyncSettings.setEnabled(false);
    service.pending!.complete(HealthImport([reading(68)], []));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString(BodyStore.key),
      data,
    );
  });
  testWidgets('empty authorized results never delete imported samples', (
    tester,
  ) async {
    final data = BodyData(healthSamples: [reading(69)]).encode();
    SharedPreferences.setMockInitialValues({BodyStore.key: data});
    final service = AutoService()..pending = Completer<HealthImport>();
    await open(tester, service);
    service.pending!.complete(const HealthImport([], []));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString(BodyStore.key),
      data,
    );
  });
}
