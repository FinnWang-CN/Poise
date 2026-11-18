import 'language.dart';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'design.dart';
import 'model.dart';

/// A stable-height record slot remains pinned above the main navigation.
class DailyRecordsPane extends StatefulWidget {
  final DateTime day;
  final Period period;
  final List<Measurement> records;
  final String unit;
  final double maxHeight;
  final Widget Function(Measurement) recordBuilder;
  final double Function(double) measureRecord;
  const DailyRecordsPane({
    super.key,
    required this.day,
    required this.period,
    required this.records,
    required this.unit,
    required this.maxHeight,
    required this.recordBuilder,
    required this.measureRecord,
  });
  @override
  State<DailyRecordsPane> createState() => _DailyRecordsPaneState();
}

class _DailyRecordsPaneState extends State<DailyRecordsPane> {
  final controller = PageController(keepPage: false);
  int index = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final count = widget.records.length;
      final current = count == 0 ? 0 : min(index, count - 1);
      double textHeight(String text, double fontSize) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(fontSize: fontSize),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        return painter.height;
      }

      final headerHeight = max(textHeight('日期', 13), textHeight('1 / 5', 11));
      // Reserve the same card slot even on days without records.
      final contentHeight = widget.measureRecord(max(1, box.maxWidth - 40));
      final height = min(
        widget.maxHeight,
        10 + headerHeight + 8 + contentHeight,
      );
      return SizedBox(
        key: ValueKey('day-records'),
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: paletteOf(context).background,
            border: Border(
              top: BorderSide(color: paletteOf(context).line, width: .6),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          tr(
                            context,
                            '${dateLabel(widget.day)} · ${widget.period.label}',
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Semantics(
                      excludeSemantics: true,
                      label:
                          count > 1
                              ? tr(
                                context,
                                '第 ${current + 1} 条，共 $count 条。左右滑动切换。',
                              )
                              : tr(context, '$count 次记录，${widget.unit}'),
                      onIncrease:
                          count > 1 && current < count - 1
                              ? () => controller.nextPage(
                                duration: Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              )
                              : null,
                      onDecrease:
                          count > 1 && current > 0
                              ? () => controller.previousPage(
                                duration: Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              )
                              : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (count > 1) ...[
                            Icon(
                              CupertinoIcons.arrow_left_right,
                              size: 12,
                              color: paletteOf(context).secondary,
                            ),
                            SizedBox(width: 5),
                          ],
                          Text(
                            tr(
                              context,
                              count > 1
                                  ? '${current + 1} / $count · ${widget.unit}'
                                  : '$count 次记录 · ${widget.unit}',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: paletteOf(context).secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Expanded(
                  child:
                      count == 0
                          ? SingleChildScrollView(
                            primary: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.heart,
                                  color: paletteOf(context).accentColor,
                                  size: 23,
                                ),
                                SizedBox(height: 7),
                                Text(
                                  tr(context, '这一天还没有记录'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  tr(context, '点击顶部“记一笔”添加记录'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: paletteOf(context).secondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : PageView.builder(
                            key: ValueKey('record-pager'),
                            controller: controller,
                            itemCount: count,
                            allowImplicitScrolling: true,
                            onPageChanged: (i) => setState(() => index = i),
                            itemBuilder:
                                (c, i) => SingleChildScrollView(
                                  primary: false,
                                  physics:
                                      widget.measureRecord(
                                                max(1, box.maxWidth - 40),
                                              ) >
                                              height - 10 - headerHeight - 8
                                          ? ClampingScrollPhysics()
                                          : NeverScrollableScrollPhysics(),
                                  child: widget.recordBuilder(
                                    widget.records[i],
                                  ),
                                ),
                          ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
