import 'language.dart';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const accent = Color(0xFF1D8276);
const canvas = Color(0xFFF2F2F7);
const ink = Color(0xFF1D1D1F);
const muted = Color(0xFF86868B);

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background,
      surface,
      raised,
      text,
      secondary,
      line,
      sidebar,
      segment,
      accentColor,
      onAccent;
  const AppPalette({
    required this.background,
    required this.surface,
    required this.raised,
    required this.text,
    required this.secondary,
    required this.line,
    required this.sidebar,
    required this.segment,
    required this.accentColor,
    required this.onAccent,
  });
  static const light = AppPalette(
    background: canvas,
    surface: Colors.white,
    raised: Colors.white,
    text: ink,
    secondary: muted,
    line: Color(0xFFE5E6EB),
    sidebar: Color(0xFFECEEF2),
    segment: Color(0xFFE6E7EC),
    accentColor: accent,
    onAccent: Colors.white,
  );
  static const dark = AppPalette(
    background: Color(0xFF111619),
    surface: Color(0xFF1C2327),
    raised: Color(0xFF39434A),
    text: Color(0xFFEEF2F3),
    secondary: Color(0xFFA1AAB1),
    line: Color(0xFF323D44),
    sidebar: Color(0xFF171E22),
    segment: Color(0xFF293239),
    accentColor: Color(0xFF72CFC0),
    onAccent: Color(0xFF102D29),
  );
  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? raised,
    Color? text,
    Color? secondary,
    Color? line,
    Color? sidebar,
    Color? segment,
    Color? accentColor,
    Color? onAccent,
  }) => AppPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    raised: raised ?? this.raised,
    text: text ?? this.text,
    secondary: secondary ?? this.secondary,
    line: line ?? this.line,
    sidebar: sidebar ?? this.sidebar,
    segment: segment ?? this.segment,
    accentColor: accentColor ?? this.accentColor,
    onAccent: onAccent ?? this.onAccent,
  );
  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      raised: mix(raised, other.raised),
      text: mix(text, other.text),
      secondary: mix(secondary, other.secondary),
      line: mix(line, other.line),
      sidebar: mix(sidebar, other.sidebar),
      segment: mix(segment, other.segment),
      accentColor: mix(accentColor, other.accentColor),
      onAccent: mix(onAccent, other.onAccent),
    );
  }
}

AppPalette paletteOf(BuildContext context) =>
    Theme.of(context).extension<AppPalette>() ??
    (Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light);
SystemUiOverlayStyle appOverlay(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? AppPalette.dark : AppPalette.light;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: brightness,
    systemNavigationBarColor: p.surface,
    systemNavigationBarIconBrightness:
        dark ? Brightness.light : Brightness.dark,
    systemNavigationBarDividerColor: p.line,
  );
}

ThemeData appleTheme({Brightness brightness = Brightness.light}) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final scheme =
      brightness == Brightness.dark
          ? ColorScheme.dark(
            primary: p.accentColor,
            secondary: Color(0xFF8AB0EF),
            surface: p.surface,
            onSurface: p.text,
            onPrimary: p.onAccent,
            outline: p.line,
            outlineVariant: p.line,
            surfaceContainerHighest: p.segment,
          )
          : ColorScheme.light(
            primary: p.accentColor,
            secondary: Color(0xFF4D7DD9),
            surface: p.surface,
            onSurface: p.text,
            onPrimary: p.onAccent,
            outline: p.line,
            outlineVariant: p.line,
            surfaceContainerHighest: p.segment,
          );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    platform: TargetPlatform.iOS,
    fontFamily: 'NotoSansSC',
    extensions: [p],
    cupertinoOverrideTheme: CupertinoThemeData(
      primaryColor: p.accentColor,
      brightness: brightness,
    ),
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    splashFactory: NoSplash.splashFactory,
    dividerColor: p.line,
    dividerTheme: DividerThemeData(color: p.line, thickness: .6, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: appOverlay(brightness),
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansSC',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
      iconTheme: IconThemeData(color: p.accentColor, size: 22),
    ),
    cardTheme: CardTheme(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: p.text),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: p.secondary),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: p.text,
      ),
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -.7,
        color: p.text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor:
          brightness == Brightness.dark ? Color(0xFF252E34) : Color(0xFFF6F6F9),
      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.accentColor, width: 1),
      ),
      labelStyle: TextStyle(fontSize: 13, color: p.secondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accentColor,
        foregroundColor: p.onAccent,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.accentColor,
        backgroundColor: p.surface,
        side: BorderSide(color: p.line),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accentColor,
        textStyle: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansSC',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.accentColor,
      textColor: p.text,
      minLeadingWidth: 30,
      horizontalTitleGap: 14,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansSC',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: p.text,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'NotoSansSC',
        fontSize: 12,
        height: 1.45,
        color: p.secondary,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(
        brightness == Brightness.dark ? Color(0xFFF1F6F4) : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accentColor : p.segment,
      ),
      trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.raised,
      contentTextStyle: TextStyle(color: p.text, fontFamily: 'NotoSansSC'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 30});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .26),
    child: Image.asset(
      'assets/brand/qingheng.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
      excludeFromSemantics: true,
    ),
  );
}

class AppleSegments<T extends Object> extends StatelessWidget {
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  const AppleSegments({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        backgroundColor: p.segment,
        thumbColor: p.raised,
        padding: EdgeInsets.all(3),
        children: items.map(
          (key, label) => MapEntry(
            key,
            Padding(
              padding: EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tr(context, label),
                  style: TextStyle(
                    fontFamily: 'NotoSansSC',
                    fontSize: 13,
                    fontWeight:
                        key == value ? FontWeight.w600 : FontWeight.w400,
                    color: key == value ? p.text : p.secondary,
                  ),
                ),
              ),
            ),
          ),
        ),
        onValueChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class FrostedTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const FrostedTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  static const labels = ['日历', '趋势', '设置'];
  static const icons = [
    CupertinoIcons.calendar,
    CupertinoIcons.chart_bar,
    CupertinoIcons.gear_alt,
  ];
  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: .9),
            border: Border(top: BorderSide(color: p.line, width: .5)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 66,
              child: Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Semantics(
                      selected: selected == i,
                      button: true,
                      child: InkWell(
                        onTap: () => onChanged(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icons[i],
                              size: 23,
                              color:
                                  selected == i ? p.accentColor : p.secondary,
                            ),
                            SizedBox(height: 5),
                            Text(
                              tr(context, labels[i]),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    selected == i
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                color:
                                    selected == i ? p.accentColor : p.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget sectionHeading(String title, String subtitle) =>
    _SectionHeading(title, subtitle);

class _SectionHeading extends StatelessWidget {
  final String title, subtitle;
  const _SectionHeading(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, title),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              color: p.text,
            ),
          ),
          SizedBox(height: 5),
          Text(
            tr(context, subtitle),
            style: TextStyle(fontSize: 13, color: p.secondary),
          ),
        ],
      ),
    );
  }
}

Widget settingIcon(IconData icon, Color color) => Container(
  width: 34,
  height: 34,
  decoration: BoxDecoration(
    color: color.withValues(alpha: .13),
    borderRadius: BorderRadius.circular(9),
  ),
  child: Icon(icon, color: color, size: 20),
);
