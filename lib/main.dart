import 'health_service.dart';
import 'health_sync.dart';
import 'language.dart';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'model.dart';
import 'store.dart';
import 'health_page.dart';
import 'file_import_page.dart';
import 'daily_records.dart';
import 'appearance.dart';
import 'manual_time.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BodyApp());
}

class BodyApp extends StatefulWidget {
  final HealthService? healthService;
  const BodyApp({super.key, this.healthService});
  @override
  State<BodyApp> createState() => _BodyAppState();
}

class _BodyAppState extends State<BodyApp> {
  final appearance = AppearanceStore();
  ThemeMode mode = ThemeMode.system;
  AppLanguage language = AppLanguage.zh;
  final languageStore = LanguageStore();
  bool ready = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ThemeMode value;
    try {
      value = await appearance.load();
    } catch (_) {
      value = ThemeMode.system;
    }
    AppLanguage loaded;
    try {
      loaded = await languageStore.load();
    } catch (_) {
      loaded = AppLanguage.zh;
    }
    if (mounted) {
      setState(() {
        language = loaded;
        mode = value;
        ready = true;
      });
    }
  }

  Future<bool> changeAppearance(ThemeMode value) async {
    try {
      if (!await appearance.save(value)) return false;
      if (mounted) setState(() => mode = value);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> changeLanguage(AppLanguage value) async {
    try {
      if (!await languageStore.save(value)) return false;
      if (mounted) setState(() => language = value);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => tr(context, '轻衡 · 身体记录'),
    locale: language == AppLanguage.system ? null : Locale(language.name),
    supportedLocales: [Locale('zh'), Locale('en')],
    localeResolutionCallback:
        (locale, supported) =>
            locale?.languageCode == 'zh' ? Locale('zh') : Locale('en'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    theme: appleTheme(),
    darkTheme: appleTheme(brightness: Brightness.dark),
    themeMode: mode,
    themeAnimationDuration: Duration(milliseconds: 180),
    builder:
        (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: appOverlay(Theme.of(context).brightness),
          child: child!,
        ),
    home:
        ready
            ? Home(
              healthService: widget.healthService,
              appearanceMode: mode,
              onAppearanceChanged: changeAppearance,
              language: language,
              onLanguageChanged: changeLanguage,
            )
            : Scaffold(body: Center(child: CircularProgressIndicator())),
  );
}

class Home extends StatefulWidget {
  final HealthService? healthService;
  final AppLanguage language;
  final Future<bool> Function(AppLanguage)? onLanguageChanged;
  final ThemeMode appearanceMode;
  final Future<bool> Function(ThemeMode)? onAppearanceChanged;
  const Home({
    super.key,
    this.healthService,
    this.language = AppLanguage.zh,
    this.onLanguageChanged,
    this.appearanceMode = ThemeMode.system,
    this.onAppearanceChanged,
  });
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  late final healthService = widget.healthService ?? HealthService();
  bool healthSyncing = false;
  DateTime? lastHealthAttempt;
  int dataRevision = 0;
  final store = BodyStore();
  BodyData data = BodyData();
  bool loading = true, saving = false;
  String? loadError;
  int page = 0, range = 30, metric = 0;
  String? extraMetric;
  DateTime selected = dayOf(DateTime.now());
  late DateTime month = DateTime(selected.year, selected.month);
  Period period = Period.all;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) autoSyncHealth();
  }

  Future<void> autoSyncHealth() async {
    if (!mounted ||
        loading ||
        saving ||
        loadError != null ||
        healthSyncing ||
        !healthService.supported ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final now = DateTime.now();
    if (lastHealthAttempt != null &&
        now.difference(lastHealthAttempt!) < Duration(minutes: 1)) {
      return;
    }
    healthSyncing = true;
    final revision = dataRevision;
    try {
      final settings = await HealthSyncSettings.load();
      if (!mounted ||
          revision != dataRevision ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      // Existing imported records migrate without asking for new permissions.
      if (!settings.enabled ||
          (!settings.connected && data.healthSamples.isEmpty)) {
        return;
      }
      lastHealthAttempt = now;
      final result = await healthService.readAuthorized(
        start: now.subtract(
          Duration(
            days:
                healthService.android ? min(30, settings.days) : settings.days,
          ),
        ),
        end: now,
        includeHeight: settings.includeHeight,
      );
      final stillEnabled = (await HealthSyncSettings.load()).enabled;
      if (!mounted ||
          saving ||
          revision != dataRevision ||
          ModalRoute.of(context)?.isCurrent != true ||
          !stillEnabled ||
          result.samples.isEmpty) {
        return;
      }
      final heights =
          result.samples.where((s) => s.kind == SampleKind.height).toList()
            ..sort((a, b) => a.time.compareTo(b.time));
      final next = data.copyWith(
        healthSamples: mergeSamples(data.healthSamples, result.samples),
        height:
            settings.includeHeight && heights.isNotEmpty
                ? heights.last.value
                : null,
      );
      if (next.encode() != data.encode()) await save(next);
    } catch (_) {
      // Failed/unavailable/revoked reads preserve local data. Reauthorize manually.
    } finally {
      healthSyncing = false;
    }
  }

  Future<void> load() async {
    try {
      final d = await store.load();
      if (mounted) {
        setState(() {
          data = d;
          loading = false;
          loadError = null;
        });
        autoSyncHealth();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = '本地数据读取失败。为保护原始数据，已暂停写入，请重试。';
        });
      }
    }
  }

  void message(String s) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(context, s))));
    }
  }

  Future<bool> save(BodyData next) async {
    if (saving || loadError != null) return false;
    dataRevision++;
    setState(() => saving = true);
    try {
      await store.save(next);
      if (mounted) setState(() => data = next);
      return true;
    } catch (_) {
      message('保存失败，请检查设备存储后重试');
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<bool> confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (c) => AlertDialog(
              title: Text(tr(context, title)),
              content: Text(tr(context, body)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(tr(context, '取消')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(tr(context, '确认')),
                ),
              ],
            ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final content =
          loading
              ? Center(child: CircularProgressIndicator())
              : loadError != null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(tr(context, loadError!)),
                    ),
                    FilledButton(
                      onPressed: load,
                      child: Text(tr(context, '重新读取')),
                    ),
                  ],
                ),
              )
              : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 780),
                  child: IndexedStack(
                    index: page,
                    children: [calendarPage(), trendPage(), settingsPage()],
                  ),
                ),
              );
      return Scaffold(
        appBar:
            wide
                ? null
                : AppBar(
                  centerTitle: false,
                  title: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BrandMark(size: 30),
                        SizedBox(width: 9),
                        Text(
                          tr(context, '轻衡'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    if (saving)
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (page != 2 && !loading && loadError == null)
                      Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: TextButton.icon(
                          onPressed: saving ? null : () => edit(),
                          icon: Icon(CupertinoIcons.add, size: 19),
                          label: Text(tr(context, '记一笔')),
                        ),
                      )
                    else
                      Padding(
                        padding: EdgeInsets.only(right: 22),
                        child: Center(
                          child: Text(
                            tr(context, 'BODY JOURNAL'),
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.7,
                              color: paletteOf(context).secondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        body: Row(
          children: [
            if (wide)
              Container(
                width: 216,
                decoration: BoxDecoration(
                  color: paletteOf(context).sidebar,
                  border: Border(
                    right: BorderSide(
                      color: paletteOf(context).line,
                      width: .7,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 26, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              BrandMark(size: 36),
                              SizedBox(width: 10),
                              Text(
                                tr(context, '轻衡'),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(12, 9, 0, 32),
                          child: Text(
                            tr(context, '你的身体记录'),
                            style: TextStyle(
                              fontSize: 12,
                              color: paletteOf(context).secondary,
                            ),
                          ),
                        ),
                        ...List.generate(
                          3,
                          (i) => Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Material(
                              color:
                                  page == i
                                      ? paletteOf(
                                        context,
                                      ).surface.withValues(alpha: .85)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                dense: true,
                                selected: page == i,
                                leading: Icon(
                                  FrostedTabs.icons[i],
                                  size: 19,
                                  color:
                                      page == i
                                          ? paletteOf(context).accentColor
                                          : paletteOf(context).secondary,
                                ),
                                title: Text(
                                  tr(context, FrostedTabs.labels[i]),
                                  style: TextStyle(
                                    color:
                                        page == i
                                            ? paletteOf(context).text
                                            : paletteOf(context).secondary,
                                    fontSize: 14,
                                    fontWeight:
                                        page == i
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                  ),
                                ),
                                onTap: () => setState(() => page = i),
                              ),
                            ),
                          ),
                        ),
                        Spacer(),
                        if (page != 2 && !loading && loadError == null)
                          Padding(
                            padding: EdgeInsets.only(bottom: 18),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: saving ? null : () => edit(),
                                icon: Icon(CupertinoIcons.add, size: 18),
                                label: Text(tr(context, '记一笔')),
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            tr(context, '记录变化，慢慢靠近目标。'),
                            style: TextStyle(
                              color: paletteOf(context).secondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: content),
          ],
        ),
        bottomNavigationBar:
            wide
                ? null
                : FrostedTabs(
                  selected: page,
                  onChanged: (i) => setState(() => page = i),
                ),
      );
    },
  );
  Widget panel(Widget child, {double padding = 18}) => Card(
    margin: EdgeInsets.only(bottom: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: paletteOf(context).line, width: .6),
    ),
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
  Widget empty(String title, String subtitle) => Padding(
    padding: EdgeInsets.symmetric(vertical: 30, horizontal: 12),
    child: Column(
      children: [
        Icon(
          Icons.spa_outlined,
          size: 40,
          color: paletteOf(context).accentColor,
        ),
        SizedBox(height: 12),
        Text(
          tr(context, title),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        SizedBox(height: 6),
        Text(
          tr(context, subtitle),
          textAlign: TextAlign.center,
          style: TextStyle(color: paletteOf(context).secondary),
        ),
      ],
    ),
  );
  Widget calendarPage() {
    final records = data.onDay(selected, period).reversed.toList();
    final first = DateTime(month.year, month.month, 1);
    final offset = first.weekday % 7;
    final length = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + length) / 7).ceil() * 7;
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < 650;
        return Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, upperBox) {
                  final rowHeight = ((upperBox.maxHeight -
                              (compact ? 240 : 262)) /
                          (cells / 7))
                      .clamp(34.0, 62.0);
                  return SingleChildScrollView(
                    key: ValueKey('calendar-scroll'),
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (compact)
                          Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: Text(
                              tr(context, '身体日历'),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.7,
                              ),
                            ),
                          )
                        else
                          sectionHeading('身体日历', '每一次记录，都是对自己的关照。'),
                        panel(
                          Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: tr(context, '上个月'),
                                    onPressed:
                                        () => setState(
                                          () =>
                                              month = DateTime(
                                                month.year,
                                                month.month - 1,
                                              ),
                                        ),
                                    icon: Icon(
                                      CupertinoIcons.chevron_left,
                                      size: 20,
                                    ),
                                  ),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        tr(
                                          context,
                                          MaterialLocalizations.of(
                                            context,
                                          ).formatMonthYear(month),
                                        ),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: tr(context, '下个月'),
                                    onPressed:
                                        () => setState(
                                          () =>
                                              month = DateTime(
                                                month.year,
                                                month.month + 1,
                                              ),
                                        ),
                                    icon: Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 20,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => setState(() {
                                          selected = dayOf(DateTime.now());
                                          month = DateTime(
                                            selected.year,
                                            selected.month,
                                          );
                                        }),
                                    child: Text(tr(context, '今天')),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              AppleSegments<Period>(
                                value: period,
                                items: {
                                  for (final p in Period.values) p: p.label,
                                },
                                onChanged: (p) => setState(() => period = p),
                              ),
                              SizedBox(height: 14),
                              Row(
                                children:
                                    ['日', '一', '二', '三', '四', '五', '六']
                                        .map(
                                          (s) => Expanded(
                                            child: Center(
                                              child: Text(
                                                tr(context, s),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      paletteOf(
                                                        context,
                                                      ).secondary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                              SizedBox(height: 6),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: cells,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 7,
                                      mainAxisExtent: rowHeight,
                                    ),
                                itemBuilder: (c, i) {
                                  final day = first.add(
                                    Duration(days: i - offset),
                                  );
                                  final inMonth = day.month == month.month;
                                  final list = data.onDay(day, period);
                                  final active = day == selected;
                                  return Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Material(
                                      color:
                                          active
                                              ? paletteOf(context).accentColor
                                              : day == dayOf(DateTime.now())
                                              ? paletteOf(context).accentColor
                                                  .withValues(alpha: .07)
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap:
                                            () => setState(() {
                                              selected = day;
                                              if (!inMonth) {
                                                month = DateTime(
                                                  day.year,
                                                  day.month,
                                                );
                                              }
                                            }),
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  tr(context, '${day.day}'),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        active
                                                            ? paletteOf(
                                                              context,
                                                            ).onAccent
                                                            : inMonth
                                                            ? paletteOf(
                                                              context,
                                                            ).text
                                                            : Colors
                                                                .grey
                                                                .shade400,
                                                  ),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  tr(
                                                    context,
                                                    list.isEmpty
                                                        ? ''
                                                        : data
                                                            .displayWeight(
                                                              list.last.kg,
                                                            )
                                                            .toStringAsFixed(1),
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        active
                                                            ? paletteOf(
                                                              context,
                                                            ).onAccent
                                                            : inMonth
                                                            ? paletteOf(
                                                              context,
                                                            ).accentColor
                                                            : Colors
                                                                .grey
                                                                .shade400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            DailyRecordsPane(
              key: ValueKey('daily-$selected-$period-${records.length}'),
              day: selected,
              period: period,
              records: records,
              unit: data.unit,
              maxHeight: box.maxHeight * .65,
              recordBuilder: (r) => recordCard(r, compact: true),
              measureRecord: (width) => compactRecordHeight(context, width),
            ),
          ],
        );
      },
    );
  }

  double compactRecordHeight(BuildContext context, double cardWidth) {
    final base = Theme.of(context).textTheme.bodyMedium!;
    Size measure(
      String text,
      double size, {
      double maxWidth = double.infinity,
      FontWeight? weight,
      double? spacing,
      int? maxLines,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: base.copyWith(
            fontSize: size,
            fontWeight: weight,
            letterSpacing: spacing,
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: maxLines,
      )..layout(maxWidth: maxWidth);
      return painter.size;
    }

    final time = measure('23:59', 12);
    final cellWidth = max(
      1.0,
      (cardWidth - 24 - max(24.0, time.width) - 20 - 24) / 3,
    );
    final values = ['88.88', '88.8', '88.8'];
    final labels = ['体重 ${data.unit}', 'BMI', '体脂率 %'];
    var rowHeight = 24 + time.height;
    for (var i = 0; i < values.length; i++) {
      final number = measure(
        values[i],
        22,
        weight: FontWeight.w600,
        spacing: -.6,
        maxLines: 1,
      );
      final numberHeight = number.height;
      rowHeight = max(
        rowHeight,
        numberHeight +
            4 +
            measure(tr(context, labels[i]), 12, maxWidth: cellWidth).height,
      );
    }
    // Always reserve one note line, independent of the selected date or record.
    final noteHeight = 6 + measure('测量备注', 12, maxLines: 1).height;
    // Actual row + card padding + its 14px bottom margin. Two pixels cover rounding.
    return (rowHeight + 24 + noteHeight + 14).ceilToDouble() + 2;
  }

  Widget recordCard(Measurement r, {bool compact = false}) => panel(
    InkWell(
      onTap: saving ? null : () => edit(r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                children: [
                  Icon(
                    r.time.hour < 12
                        ? CupertinoIcons.sunrise
                        : r.time.hour < 18
                        ? CupertinoIcons.sun_max
                        : CupertinoIcons.moon,
                    color: paletteOf(context).accentColor,
                  ),
                  Text(
                    tr(
                      context,
                      '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}',
                    ),
                    style: TextStyle(
                      color: paletteOf(context).secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 20),
              Expanded(
                child: valueCell(
                  data.displayWeight(r.kg).toStringAsFixed(2),
                  '体重 ${data.unit}',
                ),
              ),
              Expanded(
                child: valueCell(r.bmi(data.height).toStringAsFixed(1), 'BMI'),
              ),
              Expanded(
                child: valueCell(r.fat?.toStringAsFixed(1) ?? '—', '体脂率 %'),
              ),
              Icon(
                r.healthKey != null ? Icons.lock_outline : Icons.chevron_right,
                color: paletteOf(context).secondary,
              ),
            ],
          ),
          if (r.note.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: compact ? 6 : 12),
              child: Text(
                (r.note == 'Fitdays 文件导入' ||
                        r.note.startsWith('演示数据 ·') ||
                        r.healthKey != null)
                    ? tr(context, r.note)
                    : r.note,
                maxLines: compact ? 1 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: TextStyle(
                  color: paletteOf(context).secondary,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    ),
    padding: compact ? 12 : 18,
  );
  Widget valueCell(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          tr(context, value),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -.6,
          ),
        ),
      ),
      SizedBox(height: 4),
      Text(
        tr(context, label),
        style: TextStyle(color: paletteOf(context).secondary, fontSize: 12),
      ),
    ],
  );
  Widget trendPage() {
    final now = dayOf(DateTime.now());
    final start = DateTime(now.year, now.month, now.day - range + 1);
    final extras = data.extraMetricKeys;
    final chosen =
        extraMetric != null && extras.contains(extraMetric)
            ? extraMetric
            : null;
    final activeMetric = metric == 3 && chosen == null ? 0 : metric;
    final daily =
        activeMetric == 3 && chosen != null
            ? data.extraTrend(chosen, start, now)
            : data.trend(activeMetric, start, now);
    final unit =
        activeMetric == 3 && chosen != null
            ? data.extraUnit(chosen)
            : activeMetric == 0
            ? data.unit
            : activeMetric == 1
            ? '%'
            : '';
    final values = daily.map((r) => r.value).toList();
    final delta = values.length > 1 ? values.last - values.first : null;
    final spots =
        daily
            .map(
              (r) => FlSpot(
                DateTime.utc(r.time.year, r.time.month, r.time.day)
                    .difference(
                      DateTime.utc(start.year, start.month, start.day),
                    )
                    .inDays
                    .toDouble(),
                r.value,
              ),
            )
            .toList();
    final goal = data.displayWeight(data.goal);
    final bounds = [
      ...values,
      if (activeMetric == 0 && values.isNotEmpty) goal,
    ];
    final minY =
        bounds.isEmpty
            ? 0.0
            : bounds.reduce(min) - (activeMetric == 0 ? 1 : 0.5);
    final maxY =
        bounds.isEmpty
            ? 1.0
            : bounds.reduce(max) + (activeMetric == 0 ? 1 : 0.5);
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: [
        sectionHeading('变化趋势', '关注长期变化，也接纳日常波动。'),
        AppleSegments<int>(
          value: activeMetric < 3 ? activeMetric : null,
          items: {0: '体重', 1: '体脂率', 2: 'BMI'},
          onChanged: (i) => setState(() => metric = i),
        ),
        if (extras.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<String>(
              value: activeMetric == 3 ? chosen : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr(context, '更多身体指标')),
              hint: Text(tr(context, '选择表格中的其他指标')),
              items:
                  extras
                      .map(
                        (key) => DropdownMenuItem(
                          value: key,
                          child: Text(
                            tr(context, key == 'BMI' ? 'BMI（文件原值）' : key),
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  (key) => setState(() {
                    extraMetric = key;
                    metric = 3;
                  }),
            ),
          ),
        SizedBox(height: 16),
        AppleSegments<int>(
          value: range,
          items: {
            for (final r in [7, 30, 90, 365]) r: r == 365 ? '近一年' : '近 $r 天',
          },
          onChanged: (r) => setState(() => range = r),
        ),
        SizedBox(height: 18),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: valueCell(
                      values.isEmpty
                          ? '—'
                          : '${values.last.toStringAsFixed(1)} $unit',
                      '最近记录',
                    ),
                  ),
                  Expanded(
                    child: valueCell(
                      delta == null
                          ? '—'
                          : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} $unit',
                      '较区间首次',
                    ),
                  ),
                  Expanded(child: valueCell('${daily.length}', '记录天数')),
                ],
              ),
              SizedBox(height: 28),
              if (spots.isEmpty)
                empty(
                  '这个区间还没有数据',
                  activeMetric == 1 ? '填写体脂率后，就能在这里看见趋势。' : '添加记录后，变化会在这里呈现。',
                )
              else
                SizedBox(
                  height: 240,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (range - 1).toDouble(),
                      minY: minY,
                      maxY: maxY,
                      clipData: FlClipData.all(),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine:
                            (_) => FlLine(
                              color: paletteOf(
                                context,
                              ).line.withValues(alpha: .6),
                              strokeWidth: .7,
                              dashArray: [3, 4],
                            ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget:
                                (v, meta) => Text(
                                  tr(context, v.toStringAsFixed(1)),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: paletteOf(context).secondary,
                                  ),
                                ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: (range - 1) / 3,
                            getTitlesWidget: (v, meta) {
                              final d = start.add(Duration(days: v.round()));
                              return Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  tr(context, '${d.month}/${d.day}'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: paletteOf(context).secondary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          if (activeMetric == 0)
                            HorizontalLine(
                              y: goal,
                              color: Colors.orange,
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            ),
                        ],
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems:
                              (items) =>
                                  items.map((s) {
                                    final d = start.add(
                                      Duration(days: s.x.round()),
                                    );
                                    return LineTooltipItem(
                                      tr(
                                        context,
                                        '${d.month}/${d.day}\n${s.y.toStringAsFixed(1)} $unit',
                                      ),
                                      TextStyle(color: Colors.white),
                                    );
                                  }).toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: spots.length > 2,
                          curveSmoothness: .18,
                          preventCurveOverShooting: true,
                          preventCurveOvershootingThreshold: 4,
                          isStrokeCapRound: true,
                          isStrokeJoinRound: true,
                          color: paletteOf(context).accentColor,
                          barWidth: 2.5,
                          dotData: FlDotData(show: daily.length < 10),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                paletteOf(
                                  context,
                                ).accentColor.withValues(alpha: .15),
                                paletteOf(
                                  context,
                                ).accentColor.withValues(alpha: .01),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 16),
              Text(
                tr(
                  context,
                  activeMetric == 3
                      ? '按所选指标每天最后一次有效记录显示，缺测不补零。'
                      : activeMetric == 0
                      ? '橙色虚线：目标 ${goal.toStringAsFixed(1)} ${data.unit}'
                      : activeMetric == 2
                      ? 'BMI 按当前身高 ${data.height.toStringAsFixed(0)} cm 计算'
                      : '体脂率仅使用已填写的数据',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: paletteOf(context).secondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          tr(context, '测量记录'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 6),
        Text(
          tr(context, '趋势取每天最后一次测量，缺测不补零。'),
          style: TextStyle(fontSize: 12, color: paletteOf(context).secondary),
        ),
        SizedBox(height: 12),
        ...daily.reversed
            .take(15)
            .map(
              (r) => panel(
                Row(
                  children: [
                    Expanded(child: Text(tr(context, dateLabel(r.time)))),
                    Text(
                      tr(context, '${r.value.toStringAsFixed(1)} $unit'),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      tooltip: tr(
                        context,
                        r.record?.healthKey != null ? '系统记录' : '编辑记录',
                      ),
                      onPressed:
                          saving || r.record == null
                              ? null
                              : () => edit(r.record),
                      icon: Icon(
                        r.record?.healthKey != null
                            ? Icons.cloud_done_outlined
                            : Icons.edit_outlined,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget settingGroup(String caption, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(15, 0, 0, 8),
        child: Text(
          tr(context, caption),
          style: TextStyle(fontSize: 12, color: paletteOf(context).secondary),
        ),
      ),
      Card(
        margin: EdgeInsets.only(bottom: 22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: paletteOf(context).line, width: .6),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                child: rows[i],
              ),
              if (i < rows.length - 1)
                Padding(
                  padding: EdgeInsets.only(left: 62),
                  child: Divider(height: 1, thickness: .6),
                ),
            ],
          ],
        ),
      ),
    ],
  );
  Widget settingsPage() => ListView(
    padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
    children: [
      sectionHeading('个人设置', '让记录更适合你的日常。'),
      settingGroup('语言', [
        Padding(
          padding: EdgeInsets.all(14),
          child: AppleSegments<AppLanguage>(
            value: widget.language,
            items: {
              AppLanguage.zh: '中文',
              AppLanguage.en: 'English',
              AppLanguage.system: tr(context, '跟随系统'),
            },
            onChanged: (value) async {
              final ok = await widget.onLanguageChanged?.call(value) ?? false;
              if (!ok && mounted) message(tr(context, '语言设置保存失败，请重试'));
            },
          ),
        ),
      ]),
      settingGroup('外观', [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: AppleSegments<ThemeMode>(
            value: widget.appearanceMode,
            items: {
              ThemeMode.light: '浅色',
              ThemeMode.dark: '深色',
              ThemeMode.system: '跟随系统',
            },
            onChanged: (value) async {
              final ok = await widget.onAppearanceChanged?.call(value) ?? false;
              if (!ok) message('外观设置保存失败，请重试');
            },
          ),
        ),
      ]),
      settingGroup('数据来源', [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: settingIcon(CupertinoIcons.doc_text, Color(0xFF4D7DD9)),
          title: Text(tr(context, '导入 Fitdays 文件')),
          subtitle: Text(tr(context, 'Excel 历史记录与全部指标')),
          trailing: Icon(
            CupertinoIcons.chevron_forward,
            size: 15,
            color: paletteOf(context).secondary,
          ),
          onTap:
              saving
                  ? null
                  : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) => FileImportPage(initial: data, onSave: save),
                    ),
                  ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: settingIcon(CupertinoIcons.heart_fill, Color(0xFFDE6D85)),
          title: Text(tr(context, '健康数据')),
          subtitle: Text(tr(context, 'Health Connect · HealthKit')),
          trailing: Icon(
            CupertinoIcons.chevron_forward,
            size: 15,
            color: paletteOf(context).secondary,
          ),
          onTap:
              saving
                  ? null
                  : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (_) => HealthPage(
                            initial: data,
                            onSave: save,
                            service: healthService,
                          ),
                    ),
                  ),
        ),
      ]),
      settingGroup('身体档案', [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: settingIcon(CupertinoIcons.person, Color(0xFF8B78BA)),
          title: Text(tr(context, '身高与目标体重')),
          subtitle: Text(
            tr(
              context,
              '${data.height.toStringAsFixed(0)} cm · ${data.displayWeight(data.goal).toStringAsFixed(1)} ${data.unit}',
            ),
          ),
          trailing: Icon(
            CupertinoIcons.chevron_forward,
            size: 15,
            color: paletteOf(context).secondary,
          ),
          onTap: saving ? null : settings,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, '使用斤显示')),
          subtitle: Text(tr(context, '内部统一以公斤保存')),
          value: data.jin,
          onChanged: saving ? null : (v) => save(data.copyWith(jin: v)),
        ),
      ]),
      settingGroup('数据备份', [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: settingIcon(
            CupertinoIcons.arrow_up_doc,
            paletteOf(context).accentColor,
          ),
          title: Text(tr(context, '导出 JSON 备份')),
          subtitle: Text(
            tr(
              context,
              '本地 ${data.records.length} 条 · 健康 ${data.healthSamples.length} 条',
            ),
          ),
          trailing: Icon(
            CupertinoIcons.chevron_forward,
            size: 15,
            color: paletteOf(context).secondary,
          ),
          onTap: backup,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: settingIcon(
            CupertinoIcons.arrow_down_doc,
            Color(0xFF4D7DD9),
          ),
          title: Text(tr(context, '导入 JSON 备份')),
          subtitle: Text(tr(context, '校验后替换当前数据')),
          trailing: Icon(
            CupertinoIcons.chevron_forward,
            size: 15,
            color: paletteOf(context).secondary,
          ),
          onTap: saving ? null : restore,
        ),
      ]),
      panel(
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.only(bottom: 10),
          shape: Border(),
          collapsedShape: Border(),
          leading: Icon(
            CupertinoIcons.lock,
            size: 20,
            color: paletteOf(context).secondary,
          ),
          title: Text(
            tr(context, '数据与隐私'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          children: [
            Text(
              tr(
                context,
                '数据仅保存在当前设备，不上传服务器。卸载应用或清理浏览器数据可能丢失记录，请定期备份。可在健康数据页导入系统记录；智能秤直连尚未接入。',
              ),
            ),
            SizedBox(height: 10),
            Text(
              tr(context, '体脂率需来自测量或手动填写；BMI 和趋势用于个人记录，不作诊断依据。'),
              style: TextStyle(
                fontSize: 12,
                color: paletteOf(context).secondary,
              ),
            ),
          ],
        ),
      ),
      if (data.records.isEmpty && data.healthSamples.isEmpty)
        OutlinedButton.icon(
          onPressed: saving ? null : demo,
          icon: Icon(CupertinoIcons.chart_bar, size: 18),
          label: Text(tr(context, '载入演示数据（非真实测量）')),
        ),
      TextButton(
        onPressed:
            saving || (data.records.isEmpty && data.healthSamples.isEmpty)
                ? null
                : () async {
                  if (await confirm(
                    '清空所有记录？',
                    '此操作无法撤销，并会关闭自动同步。建议先导出备份；身高和目标设置会保留，系统健康原始记录不会删除。',
                  )) {
                    try {
                      await HealthSyncSettings.setEnabled(false);
                      if (!mounted) return;
                      await save(data.copyWith(records: [], healthSamples: []));
                    } catch (_) {
                      message('自动同步设置保存失败，请重试。');
                    }
                  }
                },
        child: Text(
          tr(context, '清空所有记录'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          tr(context, '轻衡 0.7.0 · 身体记录'),
          textAlign: TextAlign.center,
          style: TextStyle(color: paletteOf(context).secondary, fontSize: 11),
        ),
      ),
    ],
  );
  Future<void> edit([Measurement? existing]) async {
    if (existing?.healthKey != null) {
      message('系统记录请在来源 App 中修改，再到健康数据页重新同步。');
      return;
    }
    final form = GlobalKey<FormState>();
    final weight = TextEditingController(
      text:
          existing == null
              ? ''
              : data.displayWeight(existing.kg).toStringAsFixed(2),
    );
    final fat = TextEditingController(text: existing?.fat?.toString() ?? '');
    final note = TextEditingController(text: existing?.note ?? '');
    var time =
        existing?.time ??
        DateTime(
          selected.year,
          selected.month,
          selected.day,
          DateTime.now().hour,
          DateTime.now().minute,
        );
    String? timeError;
    final result = await showDialog<Object>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, refresh) => AlertDialog(
                  title: Text(
                    tr(context, existing == null ? '记录身体变化' : '编辑记录'),
                  ),
                  content: SizedBox(
                    width: 380,
                    child: SingleChildScrollView(
                      child: Form(
                        key: form,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (existing != null && existing.extras.isNotEmpty)
                              ExpansionTile(
                                title: Text(tr(context, '查看表格全部数据')),
                                subtitle: Text(
                                  tr(context, '以下为文件原始值，修改体重不会改写原始字段'),
                                ),
                                children:
                                    existing.extras.entries
                                        .map(
                                          (e) => Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 9,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    tr(context, e.key),
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Flexible(
                                                  child: SelectableText(
                                                    e.value,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            TextFormField(
                              controller: weight,
                              autofocus: existing == null,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: tr(context, '体重 (${data.unit})'),
                              ),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                final kg =
                                    n == null ? null : n / (data.jin ? 2 : 1);
                                return kg == null ||
                                        !kg.isFinite ||
                                        kg < 10 ||
                                        kg > 500
                                    ? tr(
                                      context,
                                      '请输入 ${data.jin ? '20–1000 斤' : '10–500 kg'}',
                                    )
                                    : null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: fat,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: tr(context, '体脂率 %（选填）'),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final n = double.tryParse(v);
                                return n == null ||
                                        !n.isFinite ||
                                        n <= 0 ||
                                        n >= 100
                                    ? tr(context, '请输入大于 0、小于 100 的体脂率')
                                    : null;
                              },
                            ),
                            SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(tr(context, dateLabel(time))),
                              trailing: Icon(Icons.calendar_today_outlined),
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: c,
                                  initialDate:
                                      time.isAfter(DateTime.now())
                                          ? DateTime.now()
                                          : time,
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );
                                if (d != null) {
                                  refresh(() {
                                    time = DateTime(
                                      d.year,
                                      d.month,
                                      d.day,
                                      time.hour,
                                      time.minute,
                                    );
                                    timeError = manualTimeError(
                                      time,
                                      DateTime.now(),
                                    );
                                  });
                                }
                              },
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                tr(
                                  context,
                                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                ),
                              ),
                              trailing: Icon(Icons.schedule),
                              onTap: () async {
                                final t = await showTimePicker(
                                  context: c,
                                  initialTime: TimeOfDay.fromDateTime(time),
                                );
                                if (t != null) {
                                  refresh(() {
                                    time = DateTime(
                                      time.year,
                                      time.month,
                                      time.day,
                                      t.hour,
                                      t.minute,
                                    );
                                    timeError = manualTimeError(
                                      time,
                                      DateTime.now(),
                                    );
                                  });
                                }
                              },
                            ),
                            if (timeError != null)
                              Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  tr(context, timeError!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(c).colorScheme.error,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                tr(context, '测量时间不能晚于当前时间'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: paletteOf(c).secondary,
                                ),
                              ),
                            ),
                            TextFormField(
                              controller: note,
                              maxLength: 500,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: tr(context, '备注（选填）'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    if (existing != null)
                      TextButton(
                        onPressed: () => Navigator.pop(c, 'delete'),
                        child: Text(
                          tr(context, '删除'),
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(tr(context, '取消')),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (form.currentState!.validate()) {
                          final error = manualTimeError(time, DateTime.now());
                          if (error != null) {
                            refresh(() => timeError = error);
                            return;
                          }
                          Navigator.pop(
                            c,
                            Measurement(
                              id:
                                  existing?.id ??
                                  '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}',
                              time: time,
                              kg:
                                  double.parse(weight.text) /
                                  (data.jin ? 2 : 1),
                              fat: double.tryParse(fat.text),
                              note: note.text.trim(),
                              extras: existing?.extras ?? {},
                            ),
                          );
                        }
                      },
                      child: Text(tr(context, '保存')),
                    ),
                  ],
                ),
          ),
    );
    // Controllers are released after the dialog route finishes its exit animation.
    Future.delayed(Duration(seconds: 1), () {
      weight.dispose();
      fat.dispose();
      note.dispose();
    });
    if (!mounted) return;
    if (result == 'delete' && existing != null) {
      if (await confirm('删除这条记录？', '删除后无法撤销。')) {
        await save(
          data.copyWith(
            records: data.records.where((r) => r.id != existing.id).toList(),
          ),
        );
      }
    } else if (result is Measurement) {
      final ok = await save(
        data.copyWith(
          records: [...data.records.where((r) => r.id != result.id), result],
        ),
      );
      if (ok && mounted) {
        setState(() {
          selected = dayOf(result.time);
          month = DateTime(selected.year, selected.month);
        });
      }
    }
  }

  Future<void> settings() async {
    final form = GlobalKey<FormState>();
    final h = TextEditingController(text: data.height.toString());
    final g = TextEditingController(
      text: data.displayWeight(data.goal).toStringAsFixed(1),
    );
    final next = await showDialog<BodyData>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(tr(context, '身高与目标')),
            content: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: h,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr(context, '身高 cm'),
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return n == null || !n.isFinite || n < 80 || n > 250
                          ? tr(context, '请输入 80–250 cm')
                          : null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: g,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: tr(context, '目标体重 ${data.unit}'),
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      final kg = n == null ? null : n / (data.jin ? 2 : 1);
                      return kg == null || !kg.isFinite || kg < 10 || kg > 500
                          ? tr(context, '请输入有效目标体重')
                          : null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(tr(context, '取消')),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(
                      c,
                      data.copyWith(
                        height: double.parse(h.text),
                        goal: double.parse(g.text) / (data.jin ? 2 : 1),
                      ),
                    );
                  }
                },
                child: Text(tr(context, '保存')),
              ),
            ],
          ),
    );
    Future.delayed(Duration(seconds: 1), () {
      h.dispose();
      g.dispose();
    });
    if (next != null) await save(next);
  }

  Future<void> backup() async {
    await showDialog<void>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(tr(context, '导出备份')),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: SelectableText(data.encode()),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(tr(context, '关闭')),
              ),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: data.encode()));
                    message('已复制备份，请粘贴到安全位置保存');
                  } catch (_) {
                    message('复制失败，请直接选择文本复制');
                  }
                },
                icon: Icon(Icons.copy),
                label: Text(tr(context, '复制 JSON')),
              ),
            ],
          ),
    );
  }

  Future<void> restore() async {
    final text = TextEditingController();
    String? error;
    final next = await showDialog<BodyData>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, refresh) => AlertDialog(
                  title: Text(tr(context, '导入备份')),
                  content: SizedBox(
                    width: 450,
                    child: TextField(
                      controller: text,
                      maxLines: 10,
                      decoration: InputDecoration(
                        hintText: tr(context, '粘贴轻衡 JSON 备份'),
                        errorText: error == null ? null : tr(context, error!),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(tr(context, '取消')),
                    ),
                    FilledButton(
                      onPressed: () {
                        try {
                          if (text.text.length > 10000000) {
                            throw FormatException('备份超过 10 MB');
                          }
                          final d = BodyData.decode(text.text);
                          Navigator.pop(c, d);
                        } catch (_) {
                          refresh(() => error = '备份格式或数值不合法，请检查完整 JSON');
                        }
                      },
                      child: Text(tr(context, '校验备份')),
                    ),
                  ],
                ),
          ),
    );
    Future.delayed(Duration(seconds: 1), text.dispose);
    if (next == null || !mounted) return;
    if (await confirm(
      '替换当前数据？',
      '导入 ${next.records.length} 条手动记录和 ${next.healthSamples.length} 条健康数据，替换当前全部记录和设置。请先备份现有数据。',
    )) {
      if (await save(next)) message('备份已导入');
    }
  }

  Future<void> demo() async {
    if (!await confirm('载入演示数据？', '将生成近 45 天的虚构记录，仅用于体验界面，不代表你的身体数据。')) return;
    final now = DateTime.now();
    final records = List.generate(
      45,
      (i) => Measurement(
        id: 'demo-$i',
        time: DateTime(now.year, now.month, now.day - 44 + i, 7, 20),
        kg: 73 - i * .075 + sin(i * .8) * .3,
        fat: 24 - i * .045 + sin(i) * .15,
        note: '演示数据 · 非真实测量',
      ),
    );
    await save(data.copyWith(records: records));
  }
}
