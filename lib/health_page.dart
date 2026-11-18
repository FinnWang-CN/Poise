import 'health_sync.dart';
import 'language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'design.dart';
import 'health_service.dart';
import 'model.dart';

class HealthPage extends StatefulWidget {
  final BodyData initial;
  final HealthService? service;
  final Future<bool> Function(BodyData) onSave;
  const HealthPage({
    super.key,
    required this.initial,
    required this.onSave,
    this.service,
  });
  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  late final service = widget.service ?? HealthService();
  late BodyData data = widget.initial;
  bool busy = false, height = false;
  int days = 30;
  bool autoSync = true, syncSettingsReady = false;
  String status = '授权后可在打开 App 时自动同步，不会修改系统健康记录。';
  bool? available;
  @override
  void initState() {
    super.initState();
    check();
    loadSyncSettings();
  }

  Future<void> loadSyncSettings() async {
    try {
      final prefs = await HealthSyncSettings.load();
      if (mounted) {
        setState(() {
          autoSync = prefs.enabled;
          height = prefs.includeHeight;
          days =
              service.android
                  ? (prefs.days > 30 ? 30 : prefs.days)
                  : prefs.days;
          syncSettingsReady = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => status = '自动同步设置读取失败，请重新打开页面。');
    }
  }

  Future<bool> rememberConnection() async {
    try {
      await HealthSyncSettings.rememberConnection(
        includeHeight: height,
        days: days,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setAutoSync(bool value) async {
    setState(() => busy = true);
    try {
      await HealthSyncSettings.setEnabled(value);
      if (mounted) setState(() => autoSync = value);
    } catch (_) {
      if (mounted) setState(() => status = '自动同步设置保存失败，请重试。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> check() async {
    try {
      final ok = await service.available();
      if (mounted) setState(() => available = ok);
    } catch (_) {
      if (mounted) {
        setState(() {
          available = false;
          status = '无法检查系统健康服务，请确认系统和服务版本后重试。';
        });
      }
    }
  }

  Future<void> sync() async {
    setState(() {
      busy = true;
      status = '正在请求授权并读取数据…';
    });
    try {
      final now = DateTime.now();
      final result = await service.read(
        start: now.subtract(Duration(days: days)),
        end: now,
        includeHeight: height,
      );
      if (!mounted) return;
      final latestHeight =
          result.samples.where((s) => s.kind == SampleKind.height).toList()
            ..sort((a, b) => a.time.compareTo(b.time));
      final heights = latestHeight.isNotEmpty ? latestHeight.last.value : null;
      if (result.samples.isEmpty) {
        await rememberConnection();
        if (!mounted) return;
        setState(
          () =>
              status = [
                '没有读到可导入的数据。请检查授权，以及体脂秤 App 是否已向系统健康服务写入数据。',
                ...result.notices,
              ].join('\n'),
        );
        return;
      }
      final approved = await showDialog<bool>(
        context: context,
        builder:
            (c) => AlertDialog(
              title: Text(tr(context, '导入读取结果')),
              content: Text(
                tr(
                  context,
                  [
                    ...SampleKind.values.map(
                      (kind) =>
                          '${kind.label}：${result.samples.where((s) => s.kind == kind).length} 条',
                    ),
                    if (heights != null)
                      '当前身高将更新为 ${heights.toStringAsFixed(1)} cm，历史 BMI 会随之重新计算。',
                    '已有来源和 ID 相同的记录会更新，不会重复新增。',
                    ...result.notices,
                  ].join('\n'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(tr(context, '取消')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(tr(context, '导入')),
                ),
              ],
            ),
      );
      if (approved != true || !mounted) {
        if (mounted) setState(() => status = '已取消导入，本地数据未改变。');
        return;
      }
      final next = data.copyWith(
        healthSamples: mergeSamples(data.healthSamples, result.samples),
        height: heights,
      );
      if (await widget.onSave(next) && mounted) {
        final remembered = await rememberConnection();
        if (!mounted) return;
        setState(() {
          data = next;
          status =
              '已导入或更新 ${result.samples.length} 条健康数据。\n${result.notices.join('\n')}';
          if (!remembered) status += '\n自动同步设置保存失败，请重试。';
        });
      } else if (mounted) {
        setState(() => status = '保存失败，原有本地数据未改变。');
      }
    } catch (_) {
      if (mounted) setState(() => status = '读取失败，本地数据未改变。请检查系统健康服务和读取权限后重试。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> clear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(tr(context, '移除健康数据副本？')),
            content: Text(
              tr(context, '移除本地健康数据并关闭自动同步。手动记录和系统原始数据会保留，需要时可重新导入。'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(tr(context, '取消')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(tr(context, '移除')),
              ),
            ],
          ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await HealthSyncSettings.setEnabled(false);
      if (!mounted) return;
      setState(() => autoSync = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          status = '自动同步设置保存失败，请重试。';
        });
      }
      return;
    }
    final next = data.copyWith(healthSamples: []);
    if (await widget.onSave(next) && mounted) {
      setState(() {
        data = next;
        status = '已移除本地健康数据副本。';
      });
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, service.supported ? service.name : '健康数据')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: settingIcon(
                  CupertinoIcons.heart_fill,
                  Color(0xFFDE6D85),
                ),
              ),
              SizedBox(height: 12),
              sectionHeading('连接健康数据', '让你的记录，在这里汇合。'),
              Text(
                tr(
                  context,
                  service.supported
                      ? '从 ${service.name} 读取体重和体脂率；身高可选。需要其他健康 App 已向系统写入相应数据。'
                      : '系统健康数据接入仅支持 Android / iOS 原生 App，网页预览不支持。',
                ),
              ),
              SizedBox(height: 14),
              if (service.supported) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(context, '打开 App 自动同步')),
                  subtitle: Text(
                    tr(context, '首次需点“授权并读取”；之后启动或回到 App 时按上次范围同步，不会再次弹出授权。'),
                  ),
                  value: autoSync,
                  onChanged: busy || !syncSettingsReady ? null : setAutoSync,
                ),
                DropdownButtonFormField<int>(
                  value: days,
                  decoration: InputDecoration(labelText: tr(context, '读取范围')),
                  items:
                      (service.android ? [7, 30] : [7, 30, 90, 365])
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(tr(context, '最近 $d 天')),
                            ),
                          )
                          .toList(),
                  onChanged: busy ? null : (v) => setState(() => days = v!),
                ),
                if (service.android)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      tr(context, '此版本不申请额外历史权限，Android 读取范围最多选择近 30 天。'),
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(context, '同时读取并使用最新身高')),
                  subtitle: Text(tr(context, '选中后会额外请求身高读取权限')),
                  value: height,
                  onChanged: busy ? null : (v) => setState(() => height = v!),
                ),
                FilledButton.icon(
                  onPressed:
                      busy || !syncSettingsReady || available != true
                          ? null
                          : sync,
                  icon:
                      busy
                          ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(Icons.sync),
                  label: Text(tr(context, busy ? '正在处理…' : '授权并读取')),
                ),
                if (available == false && service.android)
                  OutlinedButton(
                    onPressed:
                        busy
                            ? null
                            : () async {
                              try {
                                await service.install();
                              } catch (_) {
                                if (mounted) {
                                  setState(
                                    () =>
                                        status =
                                            '无法打开安装页面，请在应用商店或系统设置中安装、更新 Health Connect。',
                                  );
                                }
                              }
                            },
                    child: Text(tr(context, '安装或更新 Health Connect')),
                  ),
                TextButton(
                  onPressed: busy ? null : check,
                  child: Text(tr(context, '重新检查服务')),
                ),
              ],
              SizedBox(height: 12),
              Text(tr(context, status)),
              Divider(height: 24),
              Text(
                tr(context, '已保存 ${data.healthSamples.length} 条系统健康数据'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: busy || data.healthSamples.isEmpty ? null : clear,
                child: Text(tr(context, '移除导入的本地副本')),
              ),
              SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.only(bottom: 8),
                shape: Border(),
                collapsedShape: Border(),
                title: Text(
                  tr(context, '数据使用说明'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                children: [
                  Text(
                    tr(
                      context,
                      '• 数据只保存在本机，不上传服务器、不用于广告。\n• 开启自动同步后，启动或回到 App 时读取上次选择的范围；可用上方开关关闭。\n• 只申请读取权限，不写入或删除系统记录。\n• 体脂可独立显示趋势；同一来源、相差不超过 5 分钟的体脂才会关联到体重卡片。\n• 重复同步按来源和原始 ID 更新。系统删除记录不会自动删除已导入副本，可使用上方按钮移除后重新导入。\n• 可在 Health Connect 或苹果健康的 App 权限设置中撤回授权。撤权不等于删除本地副本。\n• iOS 出于隐私不披露读取权限状态，空结果可能是无数据或未授权。\n• 导出备份会将健康数据写入剪贴板，请妥善保管。',
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
