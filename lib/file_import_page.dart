import 'language.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'design.dart';
import 'file_import.dart';
import 'model.dart';

class FileImportPage extends StatefulWidget {
  final BodyData initial;
  final Future<bool> Function(BodyData) onSave;
  final Future<(String, Uint8List)?> Function()? selectFile;
  const FileImportPage({
    super.key,
    required this.initial,
    required this.onSave,
    this.selectFile,
  });
  @override
  State<FileImportPage> createState() => _FileImportPageState();
}

class _FileImportPageState extends State<FileImportPage> {
  late BodyData data = widget.initial;
  bool busy = false;
  TableImport? preview;
  ImportMerge? merge;
  String filename = '', status = '';
  Future<(String, Uint8List)?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > 10 * 1024 * 1024) {
      throw FormatException('文件不能超过 10 MB');
    }
    if (file.bytes == null) {
      throw FormatException('无法读取文件，请将文件下载到手机后重新选择');
    }
    return (file.name, file.bytes!);
  }

  Future<void> choose() async {
    setState(() => busy = true);
    try {
      final picked = await (widget.selectFile?.call() ?? pick());
      if (picked == null || !mounted) return;
      if (!picked.$1.toLowerCase().endsWith('.xlsx')) {
        throw FormatException('请选择 .xlsx 文件');
      }
      final parsed = await compute(parseBodyFile, picked.$2);
      if (!mounted) return;
      setState(() {
        preview = parsed;
        merge = mergeFileRecords(data, parsed.records);
        filename = picked.$1;
        status = '';
      });
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          preview = null;
          merge = null;
          status = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          preview = null;
          merge = null;
          status = '无法解析文件，请确认它是未加密的 Fitdays .xlsx 导出表格。';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> commit() async {
    final result = merge;
    if (result == null) return;
    setState(() => busy = true);
    final next = data.copyWith(records: result.records);
    final ok = await widget.onSave(next);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (ok) {
        data = next;
        status =
            '导入完成：新增 ${result.added} 条，更新 ${result.updated} 条，重复 ${result.duplicates} 条。';
        merge = null;
        preview = null;
      } else {
        status = '保存失败，原有数据未改变，请重试。';
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, '导入 Fitdays 文件'))),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: settingIcon(CupertinoIcons.doc_text, Color(0xFF4D7DD9)),
              ),
              SizedBox(height: 12),
              sectionHeading('导入历史记录', '从 Fitdays 接回完整的身体数据。'),
              Text(
                tr(
                  context,
                  '支持 Fitdays 导出的 .xlsx 文件（最大 10 MB）。自动识别时间、体重和体脂率，保留表内其他字段。斤自动换算为 kg，不修改身高设置。\n\n请确认文件属于当前使用者，本版本不区分多个人的档案。',
                ),
              ),
              SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: busy ? null : choose,
                icon: Icon(Icons.folder_open),
                label: Text(tr(context, '选择 .xlsx 文件')),
              ),
              if (busy)
                Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
              if (status.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(tr(context, status)),
                ),
              if (preview != null && merge != null) ...[
                SizedBox(height: 16),
                Text(filename, style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  tr(
                    context,
                    '${dateLabel(preview!.records.first.time)} 至 ${dateLabel(preview!.records.last.time)}\n识别 ${preview!.records.length} 条有效记录 · 跳过 ${preview!.invalidRows} 条无效行\n新增 ${merge!.added} 条 · 更新 ${merge!.updated} 条 · 重复 ${merge!.duplicates} 条',
                  ),
                ),
                SizedBox(height: 12),
                Text(tr(context, '预览（最近 5 条，体重以 kg 显示）')),
                ...preview!.records.reversed
                    .take(5)
                    .map(
                      (r) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          tr(
                            context,
                            '${dateLabel(r.time)} ${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}',
                          ),
                        ),
                        subtitle: Text(
                          tr(
                            context,
                            '${r.kg.toStringAsFixed(2)} kg · 体脂 ${r.fat?.toStringAsFixed(1) ?? '—'}% · ${r.extras.length} 个原始字段',
                          ),
                        ),
                      ),
                    ),
                if (preview!.warnings.isNotEmpty)
                  ExpansionTile(
                    title: Text(tr(context, '查看跳过原因')),
                    children:
                        preview!.warnings
                            .map((w) => ListTile(title: Text(tr(context, w))))
                            .toList(),
                  ),
                FilledButton(
                  onPressed:
                      busy || merge!.added + merge!.updated == 0
                          ? null
                          : commit,
                  child: Text(tr(context, '确认导入')),
                ),
              ],
              SizedBox(height: 14),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.only(bottom: 8),
                shape: Border(),
                collapsedShape: Border(),
                title: Text(
                  tr(context, '导入规则'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                children: [
                  Text(
                    tr(
                      context,
                      '• 追加到现有数据，不清空健康数据或手动记录。\n• 相同时间、体重、体脂的记录可更新其他字段；不同测量会保留，同一文件重复导入会跳过。\n• 日历仍只显示体重；点开记录查看原始全部字段，在趋势页选择其他数值指标。\n• 文字类字段只在详情显示。BMI 主图使用当前身高计算，也可选择“BMI（文件原值）”。\n• 文件在本机解析，不上传服务器；关闭预览不会导入数据。',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
