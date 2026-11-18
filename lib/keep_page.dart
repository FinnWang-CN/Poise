import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'design.dart';
import 'language.dart';
import 'keep_service.dart';
import 'model.dart';
import 'keep_icon.dart';

class KeepPage extends StatefulWidget {
  final BodyData initial;
  final Future<bool> Function(BodyData) onSave;
  final KeepService? service;
  const KeepPage({
    super.key,
    required this.initial,
    required this.onSave,
    this.service,
  });
  @override
  State<KeepPage> createState() => _KeepPageState();
}

class _KeepPageState extends State<KeepPage> {
  late final api = widget.service ?? KeepService();
  late BodyData data = widget.initial;
  KeepCredentials? connection;
  KeepLogin? login;
  KeepImport? preview;
  bool loading = true,
      busy = false,
      polling = false,
      useHeight = false,
      imported = false;
  int days = 30, generation = 0;
  String status = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    generation++;
    if (widget.service == null) api.dispose();
    super.dispose();
  }

  String error(Object e) =>
      e is KeepException ? e.message : '连接 Keep 失败，请检查网络后重试。';
  Future<void> load() async {
    try {
      if (api.supported) connection = await api.restore();
    } catch (e) {
      status = error(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> connect() async {
    final run = ++generation;
    setState(() {
      busy = true;
      preview = null;
      status = '正在连接 Keep…';
    });
    try {
      if (!await api.isAppInstalled()) {
        throw const KeepException('未检测到 Keep，请先安装 Keep 并登录后重试。');
      }
      if (!mounted || run != generation) return;
      final qr = await api.startLogin();
      if (!mounted || run != generation) return;
      if (!await api.openAuthorization(qr)) {
        throw const KeepException('无法唤起 Keep，请确认已安装最新版本后重试。');
      }
      if (!mounted || run != generation) return;
      setState(() {
        login = qr;
        busy = false;
        polling = true;
        status = '请在 Keep 中确认授权，然后返回 Poise。';
      });
      final deadline = DateTime.now().add(const Duration(minutes: 5));
      while (mounted &&
          run == generation &&
          DateTime.now().isBefore(deadline)) {
        final c = await api.checkLogin(qr);
        if (!mounted || run != generation) return;
        if (c != null) {
          setState(() => busy = true);
          await api.acceptLogin(c);
          if (!mounted || run != generation) return;
          setState(() {
            connection = c;
            login = null;
            polling = false;
            busy = false;
            status = 'Keep 连接成功。';
          });
          await read();
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      if (mounted && run == generation) {
        setState(() => status = 'Keep 授权已超时，请重新连接。');
      }
    } catch (e) {
      if (mounted && run == generation) setState(() => status = error(e));
    } finally {
      if (mounted && run == generation) {
        setState(() {
          busy = false;
          polling = false;
        });
      }
    }
  }

  Future<void> cancelLogin() async {
    generation++;
    setState(() {
      login = null;
      polling = false;
      status = '已取消 Keep 连接。';
    });
    await load();
  }

  Future<void> openAuth() async {
    final uri = login?.redirect;
    if (uri == null) return;
    try {
      if (!await api.openAuthorization(login!)) {
        throw const KeepException('无法唤起 Keep，请确认已安装最新版本后重试。');
      }
    } catch (e) {
      if (mounted) setState(() => status = error(e));
    }
  }

  Future<void> read() async {
    setState(() {
      busy = true;
      preview = null;
      imported = false;
      useHeight = false;
      status = '正在读取 Keep 数据…';
    });
    try {
      final result = await api.read(days: days);
      if (mounted) {
        setState(() {
          preview = result;
          status = result.samples.isEmpty ? '未读到可导入的日期记录。' : '读取完成，请核对后导入。';
        });
      }
    } catch (e) {
      if (mounted) setState(() => status = error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> commit() async {
    final result = preview;
    if (result == null || imported) return;
    setState(() => busy = true);
    final next = data.copyWith(
      keepSamples: mergeKeepSamples(data.keepSamples, result.samples),
      height: useHeight ? result.height : null,
    );
    try {
      final ok = await widget.onSave(next);
      if (mounted) {
        setState(() {
          if (ok) {
            data = next;
            imported = true;
            status = 'Keep 数据已导入，重复读取不会新增相同日期记录。';
          } else {
            status = '保存失败，原有数据未改变，请重试。';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => status = '保存失败，原有数据未改变，请重试。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> disconnect() async {
    setState(() => busy = true);
    try {
      final revoked = await api.disconnect();
      if (mounted) {
        setState(() {
          connection = null;
          preview = null;
          status = revoked ? '已断开 Keep 连接，已导入记录保留。' : '本机登录信息已清除，Keep 远端撤销失败。';
        });
      }
    } catch (e) {
      if (mounted) setState(() => status = error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> clear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(tr(context, '移除 Keep 数据副本？')),
            content: Text(
              tr(context, '只移除 Poise 内的 Keep 记录，手动记录、健康数据和 Keep 原始记录均保留。'),
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
      final next = data.copyWith(keepSamples: []);
      final ok = await widget.onSave(next);
      if (mounted) {
        setState(() {
          if (ok) {
            data = next;
            status = 'Keep 本地副本已移除。';
          } else {
            status = '保存失败，原有数据未改变，请重试。';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => status = '保存失败，原有数据未改变，请重试。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget resultCard(KeepImport result) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, '读取结果'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            tr(
              context,
              '${result.samples.length} 天记录 · 体重 ${result.samples.where((s) => s.kg != null).length} 天 · 体脂 ${result.samples.where((s) => s.fat != null).length} 天',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              context,
              'Keep 最新身高：${result.height?.toStringAsFixed(1) ?? '—'} cm',
            ),
          ),
          Text(
            tr(context, 'Keep BMI：${result.bmi?.toStringAsFixed(1) ?? '—'}'),
          ),
          Text(
            tr(
              context,
              'BMI 按当前身高 ${(useHeight ? result.height! : data.height).toStringAsFixed(0)} cm 计算',
            ),
            style: TextStyle(fontSize: 12, color: paletteOf(context).secondary),
          ),
          const SizedBox(height: 4),
          Text(
            tr(context, '身高和 Keep BMI 未提供记录日期，仅展示最新查询值，不作为历史测量。'),
            style: TextStyle(fontSize: 12, color: paletteOf(context).secondary),
          ),
          if (result.height != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: useHeight,
              onChanged:
                  busy || imported
                      ? null
                      : (v) => setState(() => useHeight = v!),
              title: Text(tr(context, '使用 Keep 身高更新身体档案')),
              subtitle: Text(tr(context, '更新身高会重新计算历史 BMI。')),
            ),
          for (final row in result.samples.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(dateLabel(row.date)),
              subtitle: Text(
                [
                  if (row.kg != null) '${row.kg!.toStringAsFixed(2)} kg',
                  if (row.fat != null)
                    '${tr(context, '体脂率')} ${row.fat!.toStringAsFixed(1)}%',
                ].join(' · '),
              ),
            ),
          if (result.samples.length > 5)
            Text(
              tr(context, '预览仅显示前 5 天，确认后导入全部已识别记录。'),
              style: const TextStyle(fontSize: 12),
            ),
          for (final w in result.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr(context, w),
                style: TextStyle(
                  fontSize: 12,
                  color: paletteOf(context).secondary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  busy || imported || (result.samples.isEmpty && !useHeight)
                      ? null
                      : commit,
              child: Text(tr(context, imported ? '已导入' : '确认导入')),
            ),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(tr(context, '查看 Keep 返回内容')),
            children: [
              SelectableText(result.raw, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy || (preview == null && login == null),
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, '连接 Keep'))),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: const KeepIcon(),
                      ),
                      const SizedBox(height: 12),
                      sectionHeading('Keep 身体记录', '连接已有数据，接着记录变化。'),
                      Text(
                        tr(
                          context,
                          '读取 Keep 的体重、体脂及最新身高和 BMI。只有确认导入后才会写入 Poise，Keep 原始记录不会修改。',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!api.supported)
                        Text(
                          tr(
                            context,
                            'Keep 连接仅支持 Android / iOS 原生 App，网页预览不支持。',
                          ),
                        )
                      else ...[
                        if (connection != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              CupertinoIcons.person_crop_circle,
                            ),
                            title: Text(connection!.username),
                            subtitle: Text(
                              tr(
                                context,
                                connection!.expired
                                    ? '授权已过期，请重新连接。'
                                    : '已连接 Keep',
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: busy || polling ? null : disconnect,
                              child: Text(tr(context, '断开连接')),
                            ),
                          ),
                        if (connection == null || connection!.expired)
                          FilledButton.icon(
                            onPressed: busy || polling ? null : connect,
                            icon: const Icon(CupertinoIcons.link),
                            label: Text(tr(context, '授权连接 Keep')),
                          ),
                        if (login != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    tr(context, '请在 Keep 中确认授权，然后返回 Poise。'),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton(
                                    onPressed:
                                        busy || !polling ? null : openAuth,
                                    child: Text(tr(context, '重新打开 Keep')),
                                  ),
                                  TextButton(
                                    onPressed: busy ? null : cancelLogin,
                                    child: Text(tr(context, '取消连接')),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (connection != null &&
                            !connection!.expired &&
                            !polling) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: days,
                            decoration: InputDecoration(
                              labelText: tr(context, '读取范围'),
                            ),
                            items: [
                              for (final d in [7, 30, 90, 365])
                                DropdownMenuItem(
                                  value: d,
                                  child: Text(tr(context, '最近 $d 天')),
                                ),
                            ],
                            onChanged:
                                busy ? null : (v) => setState(() => days = v!),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: busy ? null : read,
                            icon: const Icon(Icons.sync),
                            label: Text(tr(context, '读取 Keep 数据')),
                          ),
                        ],
                        if (connection != null &&
                            !connection!.expired &&
                            status.contains('授权'))
                          TextButton(
                            onPressed: busy || polling ? null : connect,
                            child: Text(tr(context, '重新授权')),
                          ),
                      ],
                      if (busy)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: LinearProgressIndicator(),
                        ),
                      if (status.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(tr(context, status)),
                        ),
                      if (preview != null) resultCard(preview!),
                      const SizedBox(height: 12),
                      Text(
                        tr(context, '已保存 ${data.keepSamples.length} 天 Keep 数据'),
                      ),
                      TextButton(
                        onPressed:
                            busy || polling || data.keepSamples.isEmpty
                                ? null
                                : clear,
                        child: Text(tr(context, '移除 Keep 本地副本')),
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(tr(context, 'Keep 数据说明')),
                        children: [
                          Text(
                            tr(
                              context,
                              'Keep 当前只返回日期和数值，不提供测量时分秒及原始 ID。Poise 按账号和日期更新 Keep 每日值，日期记录仅显示在“全天”，不会伪造测量时间。同日有精确时间的其他来源记录优先用于主趋势。\n\n登录凭据由设备安全存储保存，不进入 JSON 备份。连接时仅向 Keep 发送授权和查询请求，不上传你的其他健康记录。此版本暂不自动同步 Keep；读取结果需核对后导入。',
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
