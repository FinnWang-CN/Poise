import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodylog/model.dart';

Measurement record(String id, int day, int hour, double kg, {double? fat}) =>
    Measurement(id: id, time: DateTime(2026, 11, day, hour), kg: kg, fat: fat);
void main() {
  test('same-day measurements, period boundaries and daily last value', () {
    final d = BodyData(
      records: [
        record('c', 2, 18, 72),
        record('a', 2, 11, 70),
        record('b', 2, 12, 71),
        record('d', 4, 7, 69),
      ],
    );
    expect(d.onDay(DateTime(2026, 11, 2), Period.morning).single.id, 'a');
    expect(d.onDay(DateTime(2026, 11, 2), Period.afternoon).single.id, 'b');
    expect(d.onDay(DateTime(2026, 11, 2), Period.evening).single.id, 'c');
    expect(
      d.daily(DateTime(2026, 11, 2), DateTime(2026, 11, 4)).map((r) => r.id),
      ['c', 'd'],
    );
    expect(d.onDay(DateTime(2026, 11, 3), Period.all), isEmpty);
  });
  test('unit conversion preserves stored kilograms and BMI', () {
    final r = record('a', 1, 8, 68);
    final d = BodyData(records: [r], height: 170, jin: true);
    expect(d.displayWeight(r.kg), 136);
    expect(r.bmi(d.height), closeTo(23.5294, .0001));
    expect(d.copyWith(jin: false).records.single.kg, 68);
  });
  test(
    'backup round trip preserves optional fat, notes, time and settings',
    () {
      final r = Measurement(
        id: 'a',
        time: DateTime(2026, 11, 17, 8, 32),
        kg: 65.25,
        note: '早上',
      );
      final original = BodyData(records: [r], height: 175, goal: 64, jin: true);
      final restored = BodyData.decode(original.encode());
      expect(restored.encode(), original.encode());
      expect(restored.records.single.fat, isNull);
    },
  );
  test('invalid backups and duplicate IDs are rejected', () {
    final valid =
        jsonDecode(BodyData(records: [record('a', 1, 8, 68)]).encode())
            as Map<String, dynamic>;
    for (final bad in [
      {...valid, 'version': 999},
      {...valid, 'heightCm': 0},
      {...valid, 'unit': 'lb'},
      {
        ...valid,
        'records': [valid['records'][0], valid['records'][0]],
      },
      {
        ...valid,
        'records': [
          {...valid['records'][0] as Map<String, dynamic>, 'kg': -1},
        ],
      },
      {
        ...valid,
        'records': [
          {...valid['records'][0] as Map<String, dynamic>, 'fat': 100},
        ],
      },
    ]) {
      expect(() => BodyData.decode(jsonEncode(bad)), throwsFormatException);
    }
  });
}
