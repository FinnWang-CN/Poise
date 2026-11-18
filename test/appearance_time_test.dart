import 'package:bodylog/main.dart';
import 'package:bodylog/appearance.dart';
import 'package:bodylog/manual_time.dart';
import 'package:bodylog/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
 test('manual timestamps accept now/past and reject future instants',(){
  final now=DateTime(2026,11,18,10,30);
  expect(manualTimeError(now,now),isNull);
  expect(manualTimeError(now.toUtc(),now),isNull);
  expect(manualTimeError(now.subtract(const Duration(seconds:1)),now),isNull);
  expect(manualTimeError(now.add(const Duration(seconds:1)),now),isNotNull);
 });
 testWidgets('appearance toggles, persists after restart, and can return to system', (tester) async {
  await tester.binding.setSurfaceSize(const Size(390,1100));addTearDown(()=>tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(const BodyApp());await tester.pumpAndSettle();
  await tester.tap(find.text('设置'));await tester.pumpAndSettle();
  await tester.tap(find.text('深色'));await tester.pumpAndSettle();
  expect(Theme.of(tester.element(find.text('个人设置'))).brightness,Brightness.dark);
  expect((await SharedPreferences.getInstance()).getString(AppearanceStore.key),'dark');
  await tester.pumpWidget(const SizedBox());await tester.pumpAndSettle();
  await tester.pumpWidget(const BodyApp());await tester.pumpAndSettle();
  expect(Theme.of(tester.element(find.byType(Home))).brightness,Brightness.dark);
  await tester.tap(find.text('设置'));await tester.pumpAndSettle();
  await tester.tap(find.text('浅色'));await tester.pumpAndSettle();
  expect(Theme.of(tester.element(find.text('个人设置'))).brightness,Brightness.light);
  await tester.tap(find.text('跟随系统').last);await tester.pumpAndSettle();
  expect((await SharedPreferences.getInstance()).getString(AppearanceStore.key),'system');
 });
 testWidgets('system appearance responds to platform brightness', (tester) async {
  SharedPreferences.setMockInitialValues({AppearanceStore.key:'system'});
  tester.platformDispatcher.platformBrightnessTestValue=Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(const BodyApp());await tester.pumpAndSettle();
  expect(Theme.of(tester.element(find.byType(Home))).brightness,Brightness.dark);
  tester.platformDispatcher.platformBrightnessTestValue=Brightness.light;await tester.pumpAndSettle();
  expect(Theme.of(tester.element(find.byType(Home))).brightness,Brightness.light);
 });
 testWidgets('future manual record cannot save; date picker is capped at today', (tester) async {
  await tester.binding.setSurfaceSize(const Size(390,1100));addTearDown(()=>tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(const BodyApp());await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('下个月'));await tester.pumpAndSettle();
  await tester.tap(find.text('1').first);await tester.pumpAndSettle();
  await tester.tap(find.text('记一笔'));await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first,'70');
  await tester.tap(find.text('保存'));await tester.pumpAndSettle();
  expect(find.text('测量时间不能晚于现在，请调整日期或时间'),findsOneWidget);
  expect((await BodyStore().load()).records,isEmpty);
  final n=DateTime.now();final future=DateTime(n.year,n.month+1,1);
  final label='${future.year}-${future.month.toString().padLeft(2,'0')}-01';
  await tester.tap(find.text(label));await tester.pumpAndSettle();
  final picker=tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
  expect(DateUtils.isSameDay(picker.lastDate,DateTime.now()),isTrue);
  await tester.tap(find.text('取消').last);await tester.pumpAndSettle();
  await tester.tap(find.text('取消').last);await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds:2));
 });
}
