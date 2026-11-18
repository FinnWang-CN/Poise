import 'dart:io';
import 'dart:typed_data';
import 'package:bodylog/file_import.dart';
import 'package:bodylog/model.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List workbook(List<List<CellValue?>> rows) {
  final x = Excel.createExcel();
  for (final r in rows) {
    x['Sheet1'].appendRow(r);
  }
  return Uint8List.fromList(x.encode()!);
}

List<CellValue?> textRow(List<String> row) =>
    row.map(TextCellValue.new).toList();
void main() {
  test('Fitdays units, all fields, invalid rows and repeat imports', () {
    final b = workbook([
      textRow(['时间', '体重', 'BMI', '体脂率', '肌肉量', '体水分', '基础代谢率', '体型']),
      textRow([
        '2026/10/02 06:42',
        '136.10斤',
        '24.1',
        '19.7%',
        '104.6斤',
        '56.3%',
        '1557kcal',
        '匀称型',
      ]),
      textRow([
        '2026/10/01 07:30',
        '68kg',
        '24',
        '--',
        '50kg',
        '55%',
        '1550kcal',
        '标准',
      ]),
      textRow(['2026/02/30 06:00', '70kg', '24', '20%', '', '', '', '']),
      textRow(['2026/10/03 06:00', 'bad', '24', '20%', '', '', '', '']),
    ]);
    final p = parseBodyFile(b);
    expect(p.records, hasLength(2));
    expect(p.invalidRows, 2);
    final r = p.records.last;
    expect(r.kg, 68.05);
    expect(r.fat, 19.7);
    expect(r.extras['体型'], '匀称型');
    expect(r.extras, hasLength(8));
    final first = mergeFileRecords(BodyData(), p.records);
    expect(first.added, 2);
    final data = BodyData(records: first.records);
    final repeat = mergeFileRecords(data, p.records);
    expect(repeat.added, 0);
    expect(repeat.duplicates, 2);
    final restored = BodyData.decode(data.encode());
    expect(restored.records.last.extras['基础代谢率'], '1557kcal');
    expect(data.extraMetricKeys, containsAll(['BMI', '肌肉量', '体水分', '基础代谢率']));
    expect(data.extraMetricKeys, isNot(contains('体型')));
    final points = data.extraTrend('肌肉量', DateTime(2026), DateTime(2027));
    expect(points.last.value, 52.3);
    expect(data.extraUnit('肌肉量'), 'kg');
    expect(
      data
          .copyWith(jin: true)
          .extraTrend('肌肉量', DateTime(2026), DateTime(2027))
          .last
          .value,
      104.6,
    );
    expect(
      data.extraTrend('基础代谢率', DateTime(2026), DateTime(2027)).last.value,
      1557,
    );
  });
  test('Excel typed date and numeric kg plus header units', () {
    final b = workbook([
      textRow(['时间', '体重(斤)', '体脂率']),
      [
        DateTimeCellValue(year: 2026, month: 10, day: 1, hour: 8, minute: 10),
        DoubleCellValue(140),
        DoubleCellValue(22),
      ],
    ]);
    final r = parseBodyFile(b).records.single;
    expect(r.kg, 70);
    expect(r.fat, 22);
    expect(r.time, DateTime(2026, 10, 1, 8, 10));
  });
  test(
    'distinct same-minute measurements are preserved without removing manual records',
    () {
      final old = parseBodyFile(
        workbook([
          textRow(['时间', '体重', '体脂率']),
          textRow(['2026/10/01 08:00', '70kg', '20%']),
        ]),
      );
      final updated = parseBodyFile(
        workbook([
          textRow(['时间', '体重', '体脂率']),
          textRow(['2026/10/01 08:00', '69kg', '21%']),
        ]),
      );
      final manual = Measurement(id: 'manual', time: DateTime(2026), kg: 75);
      final m = mergeFileRecords(
        BodyData(records: [manual, ...old.records]),
        updated.records,
      );
      expect(m.records, hasLength(3));
      expect(m.added, 1);
      expect(m.records.first.id, 'manual');
    },
  );
  test(
    'missing schema, invalid date and unknown weight units are rejected',
    () {
      expect(
        () => parseBodyFile(
          workbook([
            textRow(['姓名', '数字']),
            textRow(['A', '1']),
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => parseBodyFile(
          workbook([
            textRow(['时间', '体重']),
            textRow(['2026/99/01', '70kg']),
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => parseBodyFile(
          workbook([
            textRow(['时间', '体重']),
            textRow(['2026/10/01', '70stone']),
          ]),
        ),
        throwsFormatException,
      );
    },
  );
  final sample = Platform.environment['FITDAYS_SAMPLE'];
  test(
    'supplied workbook parses all rows and preserves all columns',
    () {
      final p = parseBodyFile(File(sample!).readAsBytesSync());
      expect(p.records, hasLength(186));
      expect(p.invalidRows, 0);
      expect(p.records.first.extras, hasLength(22));
      final data = BodyData(records: p.records);
      expect(data.extraMetricKeys, hasLength(17));
      expect(mergeFileRecords(data, p.records).duplicates, 186);
    },
    skip:
        sample == null
            ? 'Set FITDAYS_SAMPLE for the private uploaded workbook'
            : false,
  );
}
