import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'model.dart';

class TableImport {
  final List<Measurement> records;
  final List<String> warnings;
  final int invalidRows;
  const TableImport(this.records, this.warnings, this.invalidRows);
}

class ImportMerge {
  final List<Measurement> records;
  final int added, updated, duplicates;
  const ImportMerge(this.records, this.added, this.updated, this.duplicates);
}

String cellText(Data? cell) => cell?.value?.toString().trim() ?? '';
String normalizedHeader(String s) =>
    s.trim().replaceAll(RegExp(r'[（(].*?[）)]'), '').trim();
DateTime? importDate(CellValue? cell) {
  if (cell is DateTimeCellValue) return cell.asDateTimeLocal();
  if (cell is DateCellValue) return DateTime(cell.year, cell.month, cell.day);
  final raw = cell?.toString().trim() ?? '';
  final match = RegExp(
    r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
  ).firstMatch(raw);
  if (match == null) return null;
  final p = List.generate(6, (i) => int.parse(match.group(i + 1) ?? '0'));
  final d = DateTime(p[0], p[1], p[2], p[3], p[4], p[5]);
  if (d.year != p[0] ||
      d.month != p[1] ||
      d.day != p[2] ||
      d.hour != p[3] ||
      d.minute != p[4] ||
      d.second != p[5]) {
    return null;
  }
  return d;
}

TableImport parseBodyFile(Uint8List bytes) {
  if (bytes.length > 10 * 1024 * 1024) {
    throw const FormatException('文件不能超过 10 MB');
  }
  final book = Excel.decodeBytes(bytes);
  final records = <Measurement>[];
  final warnings = <String>[];
  int invalid = 0;
  bool matched = false;
  for (final sheet in book.tables.values) {
    int header = -1;
    List<String> labels = [];
    List<String> rawLabels = [];
    for (var i = 0; i < sheet.rows.length && i < 20; i++) {
      final cells = sheet.rows[i].map(cellText).toList();
      final keys = cells.map(normalizedHeader).toList();
      if (keys.contains('时间') && keys.contains('体重')) {
        header = i;
        labels = keys;
        rawLabels = cells;
        break;
      }
    }
    if (header < 0) continue;
    matched = true;
    final ti = labels.indexOf('时间'),
        wi = labels.indexOf('体重'),
        fi = labels.indexOf('体脂率');
    for (var i = header + 1; i < sheet.rows.length; i++) {
      if (i > 20000) throw const FormatException('单个工作表最多支持 20000 行');
      final row = sheet.rows[i];
      String at(int c) => c >= 0 && c < row.length ? cellText(row[c]) : '';
      if (row.every((c) => cellText(c).isEmpty)) continue;
      final time = ti < row.length ? importDate(row[ti]?.value) : null;
      var weight = numericReading(at(wi));
      if (weight != null && weight.unit.isEmpty) {
        final headerUnit =
            RegExp(
              r'斤|kg|公斤|千克|lbs?',
              caseSensitive: false,
            ).firstMatch(rawLabels[wi])?.group(0) ??
            'kg';
        weight = numericReading('${weight.value}$headerUnit');
      }
      final fatText = at(fi);
      final fatReading = numericReading(fatText);
      final missingFat = ['', '--', '—', '-'].contains(fatText);
      final fat = missingFat ? null : fatReading?.value;
      if (time == null ||
          time.year < 1900 ||
          time.year > 2200 ||
          weight == null ||
          weight.unit != 'kg' ||
          weight.value < 10 ||
          weight.value > 500 ||
          (!missingFat &&
              (fat == null ||
                  fat <= 0 ||
                  fat >= 100 ||
                  !['', '%'].contains(fatReading!.unit)))) {
        invalid++;
        if (warnings.length < 20) {
          warnings.add('${sheet.sheetName} 第 ${i + 1} 行：日期、体重或体脂格式无效，已跳过');
        }
        continue;
      }
      final extras = <String, String>{};
      for (var c = 0; c < labels.length; c++) {
        if (labels[c].isNotEmpty) extras[labels[c]] = at(c);
      }
      // Preserve distinct measurements recorded within the same minute.
      records.add(
        Measurement(
          id: 'fitdays:${time.toIso8601String()}:${weight.value}:$fat',
          time: time,
          kg: weight.value,
          fat: fat,
          note: 'Fitdays 文件导入',
          extras: extras,
        ),
      );
    }
  }
  if (!matched) {
    throw const FormatException('未找到“时间”和“体重”列，请选择 Fitdays 导出的 .xlsx 文件');
  }
  if (records.isEmpty) throw const FormatException('没有可导入的有效记录，请检查日期和体重列');
  records.sort((a, b) => a.time.compareTo(b.time));
  return TableImport(records, warnings, invalid);
}

ImportMerge mergeFileRecords(BodyData current, List<Measurement> incoming) {
  final out = current.records.toList();
  int added = 0, updated = 0, duplicates = 0;
  for (final r in incoming) {
    final own = out.indexWhere((x) => x.id == r.id);
    if (own >= 0) {
      final old = out[own];
      if (old.kg == r.kg &&
          old.fat == r.fat &&
          _sameExtras(old.extras, r.extras)) {
        duplicates++;
        continue;
      }
      out[own] = r;
      updated++;
      continue;
    }
    final all = [
      ...out,
      ...current.allRecords.where((x) => x.healthKey != null),
    ];
    if (all.any(
      (x) =>
          x.time.difference(r.time).inSeconds.abs() < 60 &&
          (x.kg - r.kg).abs() < .005 &&
          ((x.fat == null && r.fat == null) ||
              (x.fat != null &&
                  r.fat != null &&
                  (x.fat! - r.fat!).abs() < .005)) &&
          x.extras.isNotEmpty,
    )) {
      duplicates++;
      continue;
    }
    out.add(r);
    added++;
  }
  return ImportMerge(out, added, updated, duplicates);
}

bool _sameExtras(Map<String, String> a, Map<String, String> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
