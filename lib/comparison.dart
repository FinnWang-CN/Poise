import 'model.dart';

class ComparisonMetric {
  final String name;
  final String left, right;
  final double? difference;
  final String unit;
  final int decimals;
  const ComparisonMetric(
    this.name,
    this.left,
    this.right,
    this.difference,
    this.unit,
    this.decimals,
  );
}

/// Never substitutes zero for missing values or subtracts incompatible units.
List<ComparisonMetric> compareRecords(
  BodyData data,
  Measurement a,
  Measurement b,
) {
  final result = <ComparisonMetric>[];
  void add(
    String name,
    NumericReading? x,
    NumericReading? y, {
    int decimals = 1,
    String? rawLeft,
    String? rawRight,
  }) {
    double display(NumericReading v) =>
        v.unit == 'kg' ? data.displayWeight(v.value) : v.value;
    String displayUnit(NumericReading v) => v.unit == 'kg' ? data.unit : v.unit;
    String text(NumericReading? v, String? raw) =>
        v == null
            ? (raw == null || raw.trim().isEmpty ? '—' : raw)
            : '${display(v).toStringAsFixed(decimals)}${displayUnit(v).isEmpty ? '' : ' ${displayUnit(v)}'}';
    final compatible = x != null && y != null && x.unit == y.unit;
    result.add(
      ComparisonMetric(
        name,
        text(x, rawLeft),
        text(y, rawRight),
        compatible ? display(y) - display(x) : null,
        compatible ? displayUnit(x) : '',
        decimals,
      ),
    );
  }

  add(
    '体重',
    NumericReading(a.kg, 'kg'),
    NumericReading(b.kg, 'kg'),
    decimals: 2,
  );
  NumericReading bmi(Measurement r) =>
      numericReading(r.extras['BMI'] ?? '') ??
      NumericReading(r.bmi(data.height), '');
  add('BMI', bmi(a), bmi(b));
  add(
    '体脂率',
    a.fat == null ? null : NumericReading(a.fat!, '%'),
    b.fat == null ? null : NumericReading(b.fat!, '%'),
  );
  final keys = {...a.extras.keys, ...b.extras.keys}
    ..removeAll({'时间', '体重', '体脂率', 'BMI'});
  for (final key in keys) {
    final x = a.extras[key], y = b.extras[key];
    add(
      key,
      numericReading(x ?? ''),
      numericReading(y ?? ''),
      rawLeft: x,
      rawRight: y,
      decimals: key == '腰臀比' ? 2 : 1,
    );
  }
  return result;
}
