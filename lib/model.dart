import 'dart:convert';

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
String dateLabel(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum Period { all, morning, afternoon, evening }

extension PeriodInfo on Period {
  String get label => ['全天', '早上', '下午', '晚上'][index];
  bool includes(DateTime d) => switch (this) {
    Period.all => true,
    Period.morning => d.hour < 12,
    Period.afternoon => d.hour >= 12 && d.hour < 18,
    Period.evening => d.hour >= 18,
  };
}

class Measurement {
  final String id;
  final DateTime time;
  final double kg;
  final double? fat;
  final String note;
  final String? healthKey, keepKey;
  final bool dateOnly;
  final Map<String, String> extras;
  const Measurement({
    required this.id,
    required this.time,
    required this.kg,
    this.fat,
    this.note = '',
    this.healthKey,
    this.keepKey,
    this.dateOnly = false,
    this.extras = const {},
  });
  double bmi(double heightCm) => kg / ((heightCm / 100) * (heightCm / 100));
  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time.toIso8601String(),
    'kg': kg,
    'fat': fat,
    'note': note,
    if (extras.isNotEmpty) 'extras': extras,
    if (healthKey != null) 'healthKey': healthKey,
    if (keepKey != null) 'keepKey': keepKey,
    if (dateOnly) 'dateOnly': true,
  };
  factory Measurement.fromJson(Map<String, dynamic> j) {
    final r = Measurement(
      id: j['id'] as String,
      time: DateTime.parse(j['time'] as String).toLocal(),
      kg: (j['kg'] as num).toDouble(),
      fat: (j['fat'] as num?)?.toDouble(),
      note: j['note'] as String? ?? '',
      healthKey: j['healthKey'] as String?,
      keepKey: j['keepKey'] as String?,
      dateOnly: j['dateOnly'] as bool? ?? false,
      extras: Map<String, String>.from(j['extras'] as Map? ?? {}),
    );
    if (r.time.year < 1900 ||
        r.time.year > 2200 ||
        r.id.isEmpty ||
        !r.kg.isFinite ||
        r.kg < 10 ||
        r.kg > 500 ||
        (r.fat != null && (!r.fat!.isFinite || r.fat! <= 0 || r.fat! >= 100)) ||
        r.note.length > 500 ||
        r.extras.length > 100 ||
        r.extras.entries.any(
          (e) => e.key.length > 128 || e.value.length > 500,
        )) {
      throw const FormatException('记录数值或备注不合法');
    }
    return r;
  }
}

int compareMeasurements(Measurement a, Measurement b) {
  final c = a.time.compareTo(b.time);
  return c != 0 ? c : (a.dateOnly ? 0 : 1).compareTo(b.dateOnly ? 0 : 1);
}

/// Keep exposes daily values, not precise measurement timestamps or source IDs.
class KeepSample {
  final String account;
  final DateTime date;
  final double? kg, fat;
  const KeepSample({
    required this.account,
    required this.date,
    this.kg,
    this.fat,
  });
  String get key => jsonEncode([account, dateLabel(date)]);
  Measurement? get measurement =>
      kg == null
          ? null
          : Measurement(
            id: 'keep:$key',
            keepKey: key,
            dateOnly: true,
            time: dayOf(date),
            kg: kg!,
            fat: fat,
            note: 'Keep · 日期记录',
          );
  Map<String, dynamic> toJson() => {
    'account': account,
    'date': dateLabel(date),
    if (kg != null) 'kg': kg,
    if (fat != null) 'fat': fat,
  };
  factory KeepSample.fromJson(Map<String, dynamic> j) {
    final text = j['date'] as String;
    final d = DateTime.parse(text);
    final r = KeepSample(
      account: j['account'] as String,
      date: d,
      kg: (j['kg'] as num?)?.toDouble(),
      fat: (j['fat'] as num?)?.toDouble(),
    );
    if (dateLabel(d) != text ||
        d.year < 1900 ||
        d.year > 2200 ||
        r.account.isEmpty ||
        r.account.length > 128 ||
        (r.kg == null && r.fat == null) ||
        (r.kg != null && (!r.kg!.isFinite || r.kg! < 10 || r.kg! > 500)) ||
        (r.fat != null && (!r.fat!.isFinite || r.fat! <= 0 || r.fat! >= 100))) {
      throw const FormatException('Keep 数据不合法');
    }
    return r;
  }
}

List<KeepSample> mergeKeepSamples(
  List<KeepSample> old,
  List<KeepSample> incoming,
) {
  final rows = {for (final r in old) r.key: r};
  for (final r in incoming) {
    final before = rows[r.key];
    rows[r.key] = KeepSample(
      account: r.account,
      date: r.date,
      kg: r.kg ?? before?.kg,
      fat: r.fat ?? before?.fat,
    );
  }
  return rows.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}

class BodyData {
  final List<Measurement> records;
  final double height;
  final double goal;
  final bool jin;
  final List<HealthSample> healthSamples;
  final List<KeepSample> keepSamples;
  BodyData({
    List<Measurement>? records,
    this.height = 170,
    this.goal = 65,
    this.jin = false,
    List<KeepSample>? keepSamples,
    List<HealthSample>? healthSamples,
  }) : records = List.unmodifiable(records ?? []),
       healthSamples = List.unmodifiable(healthSamples ?? []),
       keepSamples = List.unmodifiable(keepSamples ?? []);
  BodyData copyWith({
    List<Measurement>? records,
    double? height,
    double? goal,
    bool? jin,
    List<KeepSample>? keepSamples,
    List<HealthSample>? healthSamples,
  }) => BodyData(
    records: records ?? this.records,
    height: height ?? this.height,
    goal: goal ?? this.goal,
    jin: jin ?? this.jin,
    healthSamples: healthSamples ?? this.healthSamples,
    keepSamples: keepSamples ?? this.keepSamples,
  );
  String get unit => jin ? '斤' : 'kg';
  double displayWeight(double kg) => jin ? kg * 2 : kg;
  String encode() => const JsonEncoder.withIndent('  ').convert({
    'version': 3,
    'keepSamples': keepSamples.map((s) => s.toJson()).toList(),
    'healthSamples': healthSamples.map((s) => s.toJson()).toList(),
    'heightCm': height,
    'goalKg': goal,
    'unit': jin ? 'jin' : 'kg',
    'records': records.map((r) => r.toJson()).toList(),
  });
  factory BodyData.decode(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    if (![1, 2, 3].contains(j['version'])) {
      throw const FormatException('不支持的备份版本');
    }
    final height = (j['heightCm'] as num).toDouble();
    final goal = (j['goalKg'] as num).toDouble();
    if (!height.isFinite ||
        height < 80 ||
        height > 250 ||
        !goal.isFinite ||
        goal < 10 ||
        goal > 500 ||
        !['kg', 'jin'].contains(j['unit'])) {
      throw const FormatException('设置数据不合法');
    }
    final records =
        (j['records'] as List)
            .map((r) => Measurement.fromJson(r as Map<String, dynamic>))
            .toList();
    if (records.map((r) => r.id).toSet().length != records.length) {
      throw const FormatException('记录 ID 重复');
    }
    final samples =
        (j['healthSamples'] as List? ?? [])
            .map((s) => HealthSample.fromJson(s as Map<String, dynamic>))
            .toList();
    if (samples.map((s) => s.key).toSet().length != samples.length) {
      throw const FormatException('健康数据 ID 重复');
    }
    final keep =
        (j['keepSamples'] as List? ?? [])
            .map((r) => KeepSample.fromJson(r as Map<String, dynamic>))
            .toList();
    if (keep.map((s) => s.key).toSet().length != keep.length) {
      throw const FormatException('Keep 记录重复');
    }
    return BodyData(
      keepSamples: keep,
      healthSamples: samples,
      records: records,
      height: height,
      goal: goal,
      jin: j['unit'] == 'jin',
    );
  }
  List<Measurement> get allRecords => [
    ...records,
    ...keepSamples.map((s) => s.measurement).whereType<Measurement>(),
    ...healthSamples.where((s) => s.kind == SampleKind.weight).map((w) {
      final fats =
          healthSamples
              .where(
                (f) =>
                    f.kind == SampleKind.fat &&
                    f.platform == w.platform &&
                    f.sourceId == w.sourceId &&
                    f.time.difference(w.time).inSeconds.abs() <= 300,
              )
              .toList()
            ..sort(
              (a, b) => a.time
                  .difference(w.time)
                  .inSeconds
                  .abs()
                  .compareTo(b.time.difference(w.time).inSeconds.abs()),
            );
      return Measurement(
        id: 'health:${w.key}',
        healthKey: w.key,
        time: w.time,
        kg: w.value,
        fat: fats.isEmpty ? null : fats.first.value,
        note: '${w.platform} · ${w.sourceName}（系统记录）',
      );
    }),
  ];
  List<TrendEntry> trend(int metric, DateTime start, DateTime end) {
    final points =
        metric == 1
            ? [
              ...records
                  .where((r) => r.fat != null)
                  .map(
                    (r) => TrendEntry(r.time, r.fat!, r, dateOnly: r.dateOnly),
                  ),
              ...keepSamples
                  .where((r) => r.fat != null)
                  .map(
                    (r) => TrendEntry(
                      r.date,
                      r.fat!,
                      r.measurement,
                      dateOnly: true,
                    ),
                  ),
              ...healthSamples
                  .where((s) => s.kind == SampleKind.fat)
                  .map((s) => TrendEntry(s.time, s.value, null)),
            ]
            : allRecords
                .map(
                  (r) => TrendEntry(
                    r.time,
                    metric == 0 ? displayWeight(r.kg) : r.bmi(height),
                    r,
                    dateOnly: r.dateOnly,
                  ),
                )
                .toList();
    points.sort((a, b) {
      final c = a.time.compareTo(b.time);
      return c != 0 ? c : (a.dateOnly ? 0 : 1).compareTo(b.dateOnly ? 0 : 1);
    });
    final days = <DateTime, TrendEntry>{};
    for (final p in points) {
      final d = dayOf(p.time);
      if (!d.isBefore(dayOf(start)) && !d.isAfter(dayOf(end))) days[d] = p;
    }
    return days.values.toList();
  }

  List<String> get extraMetricKeys {
    final keys = <String>{};
    for (final r in records) {
      for (final key in r.extras.keys) {
        if (!['时间', '体重', '体脂率', '体型', '肥胖等级'].contains(key) &&
            (knownNumericMetrics.contains(key) ||
                numericReading(r.extras[key]!) != null)) {
          keys.add(key);
        }
      }
    }
    return keys.toList();
  }

  String extraUnit(String key) {
    for (final r in records) {
      final v = numericReading(r.extras[key] ?? '');
      if (v != null) {
        return v.unit == 'kg' && jin
            ? '斤'
            : v.unit.isEmpty && key == '身体年龄'
            ? '岁'
            : v.unit;
      }
    }
    return '';
  }

  List<TrendEntry> extraTrend(String key, DateTime start, DateTime end) {
    final desiredUnit = extraUnit(key);
    final days = <DateTime, TrendEntry>{};
    final sorted = records.toList()..sort(compareMeasurements);
    for (final r in sorted) {
      final d = dayOf(r.time);
      final reading = numericReading(r.extras[key] ?? '');
      if (reading == null ||
          d.isBefore(dayOf(start)) ||
          d.isAfter(dayOf(end))) {
        continue;
      }
      final u =
          reading.unit == 'kg' && jin
              ? '斤'
              : reading.unit.isEmpty && key == '身体年龄'
              ? '岁'
              : reading.unit;
      if (u != desiredUnit) continue;
      days[d] = TrendEntry(
        r.time,
        reading.unit == 'kg' && jin ? reading.value * 2 : reading.value,
        r,
      );
    }
    return days.values.toList();
  }

  List<Measurement> onDay(DateTime day, Period period) =>
      allRecords
          .where(
            (r) =>
                dayOf(r.time) == dayOf(day) &&
                (r.dateOnly ? period == Period.all : period.includes(r.time)),
          )
          .toList()
        ..sort(compareMeasurements);
  List<Measurement> daily(DateTime start, DateTime end) {
    final days = <DateTime, Measurement>{};
    final sorted = allRecords.toList()..sort(compareMeasurements);
    for (final r in sorted) {
      final d = dayOf(r.time);
      if (!d.isBefore(dayOf(start)) && !d.isAfter(dayOf(end))) days[d] = r;
    }
    return days.values.toList();
  }
}

class TrendEntry {
  final DateTime time;
  final double value;
  final Measurement? record;
  final bool dateOnly;
  const TrendEntry(this.time, this.value, this.record, {this.dateOnly = false});
}

enum SampleKind { weight, fat, height }

class HealthSample {
  final String platform, sourceId, sourceName, uuid;
  final SampleKind kind;
  final DateTime time;
  final double value;
  const HealthSample({
    required this.platform,
    required this.sourceId,
    required this.sourceName,
    required this.uuid,
    required this.kind,
    required this.time,
    required this.value,
  });
  String get key => jsonEncode([platform, sourceId, kind.name, uuid]);
  Map<String, dynamic> toJson() => {
    'platform': platform,
    'sourceId': sourceId,
    'sourceName': sourceName,
    'uuid': uuid,
    'kind': kind.name,
    'time': time.toIso8601String(),
    'value': value,
  };
  factory HealthSample.fromJson(Map<String, dynamic> j) {
    final s = HealthSample(
      platform: j['platform'] as String,
      sourceId: j['sourceId'] as String,
      sourceName: j['sourceName'] as String,
      uuid: j['uuid'] as String,
      kind: SampleKind.values.byName(j['kind'] as String),
      time: DateTime.parse(j['time'] as String).toLocal(),
      value: (j['value'] as num).toDouble(),
    );
    final valid = switch (s.kind) {
      SampleKind.weight => s.value >= 10 && s.value <= 500,
      SampleKind.fat => s.value > 0 && s.value < 100,
      SampleKind.height => s.value >= 80 && s.value <= 250,
    };
    if (!valid ||
        !s.value.isFinite ||
        s.uuid.isEmpty ||
        !['Health Connect', 'HealthKit'].contains(s.platform) ||
        s.time.year < 1900 ||
        s.time.year > 2200) {
      throw const FormatException('健康数据不合法');
    }
    return s;
  }
}

List<HealthSample> mergeSamples(
  List<HealthSample> old,
  List<HealthSample> incoming,
) {
  final byKey = {for (final s in old) s.key: s};
  for (final s in incoming) {
    byKey[s.key] = s;
  }
  return byKey.values.toList()..sort((a, b) => a.time.compareTo(b.time));
}

const knownNumericMetrics = {
  'BMI',
  '脂肪量',
  '肌肉率',
  '肌肉量',
  '骨骼肌率',
  '骨量',
  '蛋白质',
  '蛋白量',
  '体水分',
  '含水量',
  '皮下脂肪',
  '内脏脂肪',
  '身体年龄',
  '腰臀比',
  '基础代谢率',
  '去脂体重',
  '标准体重',
};

class NumericReading {
  final double value;
  final String unit;
  const NumericReading(this.value, this.unit);
}

NumericReading? numericReading(String raw) {
  final match = RegExp(
    r'^\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+))\s*(kg|公斤|千克|斤|lb|lbs|%|％|kcal|千卡|岁|cm|厘米|m|米)?\s*$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  var n = double.tryParse(match.group(1)!);
  if (n == null || !n.isFinite) return null;
  var unit = (match.group(2) ?? '').toLowerCase();
  if (unit == '斤') {
    n /= 2;
    unit = 'kg';
  }
  if (unit == 'lb' || unit == 'lbs') {
    n *= .45359237;
    unit = 'kg';
  }
  if (unit == '公斤' || unit == '千克') unit = 'kg';
  if (unit == '％') unit = '%';
  if (unit == '千卡') unit = 'kcal';
  if (unit == '厘米') unit = 'cm';
  if (unit == '米') unit = 'm';
  return NumericReading(n, unit);
}
