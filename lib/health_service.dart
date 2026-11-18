import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'model.dart';

class HealthImport {
  final List<HealthSample> samples;
  final List<String> notices;
  const HealthImport(this.samples, this.notices);
}

class HealthService {
  final Health _health;
  HealthService({Health? health}) : _health = health ?? Health();
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  bool get android => defaultTargetPlatform == TargetPlatform.android;
  String get name => android ? 'Health Connect' : 'HealthKit';
  Future<bool> available() async {
    if (!supported) return false;
    await _health.configure();
    return !android || await _health.isHealthConnectAvailable();
  }

  Future<void> install() => _health.installHealthConnect();
  static const kinds = {
    HealthDataType.WEIGHT: SampleKind.weight,
    HealthDataType.BODY_FAT_PERCENTAGE: SampleKind.fat,
    HealthDataType.HEIGHT: SampleKind.height,
  };
  Future<HealthImport> read({
    required DateTime start,
    required DateTime end,
    required bool includeHeight,
  }) async {
    return _read(
      start: start,
      end: end,
      includeHeight: includeHeight,
      requestAccess: true,
    );
  }

  /// A foreground refresh must never open a permission dialog.
  Future<HealthImport> readAuthorized({
    required DateTime start,
    required DateTime end,
    required bool includeHeight,
  }) => _read(
    start: start,
    end: end,
    includeHeight: includeHeight,
    requestAccess: false,
  );

  Future<HealthImport> _read({
    required DateTime start,
    required DateTime end,
    required bool includeHeight,
    required bool requestAccess,
  }) async {
    if (!await available()) {
      throw StateError('系统健康服务不可用，请安装或更新 Health Connect。');
    }
    final types = [
      HealthDataType.WEIGHT,
      HealthDataType.BODY_FAT_PERCENTAGE,
      if (includeHeight) HealthDataType.HEIGHT,
    ];
    final permissions = List.filled(types.length, HealthDataAccess.READ);
    if (requestAccess &&
        await _health.hasPermissions(types, permissions: permissions) != true) {
      await _health.requestAuthorization(types, permissions: permissions);
    }
    final samples = <HealthSample>[];
    final notices = <String>[];
    for (final type in types) {
      if (android &&
          await _health.hasPermissions(
                [type],
                permissions: [HealthDataAccess.READ],
              ) !=
              true) {
        notices.add('${kinds[type]!.label}未获读取授权');
        continue;
      }
      // Fail the import on query errors; never replace local data with a partial failed query.
      final points = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: start,
        endTime: end,
      );
      for (final p in points) {
        if (p.value is! NumericHealthValue) continue;
        var value = (p.value as NumericHealthValue).numericValue.toDouble();
        if (type == HealthDataType.BODY_FAT_PERCENTAGE && !android) {
          value *= 100;
        }
        if (type == HealthDataType.HEIGHT) value *= 100;
        final sample = HealthSample(
          platform: name,
          sourceId: p.sourceId,
          sourceName: p.sourceName,
          uuid:
              p.uuid.isNotEmpty
                  ? p.uuid
                  : '${p.dateFrom.toUtc().toIso8601String()}:$value',
          kind: kinds[type]!,
          time: p.dateFrom.toLocal(),
          value: value,
        );
        try {
          HealthSample.fromJson(sample.toJson());
          samples.add(sample);
        } on FormatException {
          notices.add('跳过超出支持范围的${sample.kind.label}');
        }
      }
    }
    if (!android) notices.add('Apple 不披露读取权限状态；空结果可能表示无数据或未授权。');
    return HealthImport(mergeSamples([], samples), notices.toSet().toList());
  }
}

extension SampleLabel on SampleKind {
  String get label => switch (this) {
    SampleKind.weight => '体重',
    SampleKind.fat => '体脂率',
    SampleKind.height => '身高',
  };
}
