import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bodylog/design.dart';
import 'package:bodylog/main.dart';
import 'package:bodylog/model.dart';
import 'package:bodylog/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'wide sidebar adapts to mobile tabs and preserves selected page',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const BodyApp());
      await tester.pumpAndSettle();
      expect(find.byType(FrostedTabs), findsNothing);
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('个人设置'), findsOneWidget);
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      await tester.pumpAndSettle();
      expect(find.byType(FrostedTabs), findsOneWidget);
      expect(find.text('个人设置'), findsOneWidget);
      await tester.tap(find.text('趋势'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('体脂率'));
      await tester.pumpAndSettle();
      expect(find.text('填写体脂率后，就能在这里看见趋势。'), findsOneWidget);
    },
  );
  testWidgets('calendar and trend remain usable with larger text', (
    tester,
  ) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      BodyStore.key:
          BodyData(
            records: [Measurement(id: 'one', time: now, kg: 68.5, fat: 22)],
          ).encode(),
    });
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: appleTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 1100),
            textScaler: TextScaler.linear(1.3),
          ),
          child: const Home(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('68.5'), findsOneWidget);
    await tester.tap(find.text('趋势'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('近一年'));
    await tester.pumpAndSettle();
  });
}
