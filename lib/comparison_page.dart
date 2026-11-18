import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'comparison.dart';
import 'design.dart';
import 'language.dart';
import 'model.dart';

class ComparisonPage extends StatefulWidget {
  final BodyData data;
  final DateTime? initialDay;
  const ComparisonPage({super.key, required this.data, this.initialDay});
  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  late final records =
      widget.data.allRecords.toList()
        ..sort((a, b) => compareMeasurements(b, a));
  Measurement? left, right;
  @override
  void initState() {
    super.initState();
    final day =
        records
            .where(
              (r) =>
                  dayOf(r.time) == dayOf(widget.initialDay ?? DateTime.now()),
            )
            .toList();
    right = day.isNotEmpty ? day.first : records.firstOrNull;
    left = records.where((r) => r.id != right?.id).firstOrNull;
    if (left != null && right != null && left!.time.isAfter(right!.time)) {
      final old = left;
      left = right;
      right = old;
    }
  }

  String time(Measurement r) =>
      r.dateOnly
          ? tr(context, '仅日期')
          : '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}';
  String source(Measurement r) => tr(
    context,
    r.keepKey != null
        ? 'Keep 记录'
        : r.healthKey != null
        ? '系统记录'
        : r.extras.isNotEmpty
        ? '文件导入'
        : '手动记录',
  );

  Future<void> pick(bool baseline) async {
    if (records.isEmpty) return;
    final current = baseline ? left : right;
    final other = baseline ? right : left;
    final days = records.map((r) => dayOf(r.time)).toSet().toList()..sort();
    var day = current == null ? days.last : dayOf(current.time);
    final chosen = await showModalBottomSheet<Measurement>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (sheet) => StatefulBuilder(
            builder: (sheet, update) {
              final rows = records.where((r) => dayOf(r.time) == day).toList();
              final index = days.indexOf(day);
              return SizedBox(
                height: MediaQuery.sizeOf(sheet).height * .72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr(sheet, baseline ? '选择基准记录' : '选择对比记录'),
                              style: Theme.of(sheet).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: tr(sheet, '关闭'),
                            onPressed: () => Navigator.pop(sheet),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: tr(sheet, '上一个有记录的日期'),
                          onPressed:
                              index > 0
                                  ? () => update(() => day = days[index - 1])
                                  : null,
                          icon: const Icon(
                            CupertinoIcons.chevron_left,
                            size: 18,
                          ),
                        ),
                        Flexible(
                          child: TextButton.icon(
                            icon: const Icon(CupertinoIcons.calendar, size: 18),
                            label: Text(dateLabel(day)),
                            onPressed: () async {
                              final selected = await showDatePicker(
                                context: sheet,
                                initialDate: day,
                                firstDate: days.first,
                                lastDate: days.last,
                                selectableDayPredicate:
                                    (d) => days.contains(dayOf(d)),
                              );
                              if (selected != null && sheet.mounted) {
                                update(() => day = dayOf(selected));
                              }
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: tr(sheet, '下一个有记录的日期'),
                          onPressed:
                              index < days.length - 1
                                  ? () => update(() => day = days[index + 1])
                                  : null,
                          icon: const Icon(
                            CupertinoIcons.chevron_right,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          return ListTile(
                            enabled: r.id != other?.id,
                            selected: r.id == current?.id,
                            title: Text(
                              '${time(r)} · ${widget.data.displayWeight(r.kg).toStringAsFixed(2)} ${tr(context, widget.data.unit)}',
                            ),
                            subtitle: Text(
                              r.id == other?.id
                                  ? tr(context, '已用于另一组')
                                  : source(r),
                            ),
                            trailing:
                                r.id == current?.id
                                    ? const Icon(Icons.check, size: 20)
                                    : null,
                            onTap: () => Navigator.pop(sheet, r),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
    if (chosen != null && mounted) {
      setState(() {
        if (baseline) {
          left = chosen;
        } else {
          right = chosen;
        }
      });
    }
  }

  Widget selector(bool baseline) {
    final r = baseline ? left : right;
    final p = paletteOf(context);
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => pick(baseline),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, baseline ? '基准记录' : '对比记录'),
                style: TextStyle(fontSize: 12, color: p.secondary),
              ),
              const SizedBox(height: 7),
              Text(
                r == null ? tr(context, '选择记录') : dateLabel(r.time),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                r == null ? '—' : '${time(r)} · ${source(r)}',
                style: TextStyle(fontSize: 11, color: p.secondary),
              ),
              const SizedBox(height: 7),
              Text(
                tr(context, '点击更换'),
                style: TextStyle(fontSize: 11, color: p.accentColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget metricRow(ComparisonMetric m) {
    final p = paletteOf(context);
    final rounded =
        m.difference == null
            ? null
            : double.parse(m.difference!.toStringAsFixed(m.decimals));
    final up = rounded != null && rounded > 0,
        down = rounded != null && rounded < 0;
    final delta =
        rounded == null
            ? '—'
            : '${up ? '+' : ''}${rounded.toStringAsFixed(m.decimals)}${m.unit.isEmpty ? '' : ' ${m.unit == '%' ? tr(context, '百分点') : tr(context, m.unit)}'}';
    Widget value(String s) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        s.replaceAll('斤', tr(context, '斤')),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 19, horizontal: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: value(m.left)),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Text(
                  tr(context, m.name),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: p.secondary),
                ),
                const SizedBox(height: 6),
                Text(
                  '${up
                      ? '↑ '
                      : down
                      ? '↓ '
                      : ''}$delta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        up
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFB6A4FF)
                                : const Color(0xFF7960C5))
                            : p.accentColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 3, child: value(m.right)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = left != null && right != null;
    final p = paletteOf(context);
    final metrics =
        ready
            ? compareRecords(widget.data, left!, right!)
            : <ComparisonMetric>[];
    final days =
        ready
            ? (dayOf(right!.time).difference(dayOf(left!.time)).inHours / 24)
                .round()
                .abs()
            : 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, '数据对比')),
        actions: [
          IconButton(
            tooltip: tr(context, '交换记录'),
            onPressed:
                ready
                    ? () => setState(() {
                      final a = left;
                      left = right;
                      right = a;
                    })
                    : null,
            icon: const Icon(CupertinoIcons.arrow_right_arrow_left, size: 20),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: selector(true)),
                  const SizedBox(width: 10),
                  Expanded(child: selector(false)),
                ],
              ),
              const SizedBox(height: 16),
              if (!ready)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr(context, '至少需要两条体重记录才能对比。'),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (ready) ...[
                Text(
                  tr(context, '相隔 $days 天'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: p.secondary),
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < metrics.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: p.line),
                          ),
                        metricRow(metrics[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tr(
                    context,
                    '差值 = 对比记录 − 基准记录。缺失或单位不同的指标不计算差值；增减不代表健康评价。BMI 优先使用原始值，否则按当前身高计算。',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.6,
                    color: p.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
