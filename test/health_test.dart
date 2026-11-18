import 'package:bodylog/health_service.dart';
import 'package:bodylog/model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

HealthDataPoint point(HealthDataType type, double value, String uuid) =>
    HealthDataPoint(
      uuid: uuid,
      value: NumericHealthValue(numericValue: value),
      type: type,
      unit:
          type == HealthDataType.WEIGHT
              ? HealthDataUnit.KILOGRAM
              : type == HealthDataType.HEIGHT
              ? HealthDataUnit.METER
              : HealthDataUnit.PERCENT,
      dateFrom: DateTime(2026, 11, 17, 7),
      dateTo: DateTime(2026, 11, 17, 7),
      sourcePlatform: HealthPlatformType.appleHealth,
      sourceDeviceId: 'device',
      sourceId: 'scale',
      sourceName: 'Test Scale',
    );

class FakeHealth extends Health {
  List<HealthDataPoint> points = [];
  Set<HealthDataType> allowed = {
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.HEIGHT,
  };
  List<HealthDataType> queried = [];
  List<HealthDataAccess>? requested;
  bool fail = false;
  @override
  Future<void> configure() async {}
  @override
  Future<bool> isHealthConnectAvailable() async => true;
  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? null
          : types.every(allowed.contains);
  @override
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async {
    requested = permissions;
    return true;
  }

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    if (fail) throw StateError('read failed');
    queried.addAll(types);
    return points.where((p) => types.contains(p.type)).toList();
  }
}

HealthSample sample(
  String id,
  SampleKind kind,
  double value, {
  String source = 'scale',
  int minute = 0,
}) => HealthSample(
  platform: 'Health Connect',
  sourceId: source,
  sourceName: source,
  uuid: id,
  kind: kind,
  time: DateTime(2026, 11, 17, 7, minute),
  value: value,
);
void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test(
    'iOS fractions become percentages; meters become cm; only READ requested',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final fake =
          FakeHealth()
            ..points = [
              point(HealthDataType.WEIGHT, 68, 'w'),
              point(HealthDataType.BODY_FAT_PERCENTAGE, .23, 'f'),
              point(HealthDataType.HEIGHT, 1.72, 'h'),
            ];
      final r = await HealthService(
        health: fake,
      ).read(start: DateTime(2026), end: DateTime(2027), includeHeight: true);
      expect(r.samples.firstWhere((s) => s.kind == SampleKind.fat).value, 23);
      expect(
        r.samples.firstWhere((s) => s.kind == SampleKind.height).value,
        172,
      );
      expect(fake.requested, everyElement(HealthDataAccess.READ));
      expect(r.notices.join(), contains('不披露'));
    },
  );
  test(
    'Android percentages unchanged and partial permission skips denied type',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final fake =
          FakeHealth()
            ..points = [point(HealthDataType.BODY_FAT_PERCENTAGE, 23, 'f')]
            ..allowed = {HealthDataType.BODY_FAT_PERCENTAGE};
      final r = await HealthService(
        health: fake,
      ).read(start: DateTime(2026), end: DateTime(2027), includeHeight: false);
      expect(r.samples.single.value, 23);
      expect(fake.queried, [HealthDataType.BODY_FAT_PERCENTAGE]);
      expect(r.notices.join(), contains('体重未获'));
      expect(fake.requested, everyElement(HealthDataAccess.READ));
    },
  );
  test('query failure propagates; no partial import is returned', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final fake = FakeHealth()..fail = true;
    await expectLater(
      HealthService(
        health: fake,
      ).read(start: DateTime(2026), end: DateTime(2027), includeHeight: false),
      throwsStateError,
    );
  });
  test('sync upserts by source and UUID while preserving manual data', () {
    final old = sample('same', SampleKind.weight, 70);
    final incoming = sample('same', SampleKind.weight, 69);
    final other = sample('same', SampleKind.weight, 68, source: 'other');
    final merged = mergeSamples([old], [incoming, incoming, other]);
    expect(merged, hasLength(2));
    expect(merged.firstWhere((s) => s.sourceId == 'scale').value, 69);
    final d = BodyData(
      records: [
        Measurement(id: 'manual', time: DateTime(2026, 11, 17), kg: 72),
      ],
      healthSamples: merged,
    );
    expect(d.allRecords, hasLength(3));
    expect(BodyData.decode(d.encode()).healthSamples, hasLength(2));
  });
  test(
    'fat-only data charts independently and only close same-source fat links to weight',
    () {
      final d = BodyData(
        healthSamples: [
          sample('w', SampleKind.weight, 70),
          sample('f', SampleKind.fat, 22, source: 'other'),
          sample('late', SampleKind.fat, 23, minute: 20),
        ],
      );
      expect(d.allRecords.single.fat, isNull);
      expect(
        d.trend(1, DateTime(2026, 11, 1), DateTime(2026, 11, 30)).single.value,
        23,
      );
      final linked = d.copyWith(
        healthSamples: [
          ...d.healthSamples,
          sample('near', SampleKind.fat, 21, minute: 3),
        ],
      );
      expect(linked.allRecords.single.fat, 21);
      final fatOnly = BodyData(
        healthSamples: [sample('f', SampleKind.fat, 22)],
      );
      expect(fatOnly.allRecords, isEmpty);
      expect(fatOnly.trend(1, DateTime(2026), DateTime(2027)).single.value, 22);
    },
  );
  test('v1 backup migrates without losing records', () {
    final d = BodyData.decode(
      '{"version":1,"heightCm":170,"goalKg":65,"unit":"kg","records":[]}',
    );
    expect(d.healthSamples, isEmpty);
    expect(BodyData.decode(d.encode()).height, 170);
  });
}
