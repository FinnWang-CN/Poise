import 'dart:convert';
import 'package:bodylog/keep_service.dart';
import 'package:bodylog/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryVault implements KeepVault {
  String? value;
  MemoryVault([this.value]);
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    value = v;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  final start = DateTime(2026, 10, 20), end = DateTime(2026, 11, 18);
  test(
    'parse dated daily values; ignore summaries, validate range and retain undated profile separately',
    () {
      final r = KeepImport.parse(
        account: 'fixture',
        start: start,
        end: end,
        weights:
            '记录如下：\n2026-11-17：体重 70.2 公斤\n2026-11-18：体重 140 斤\n最近一次为2026-11-18，体重140斤。\n2026-11-19：体重 69 公斤\n2026-11-31：体重 68 公斤',
        fats: '2026-11-17：体脂率 22.4%\n2026-11-18：体脂率 0%',
        profile: '最新身高为168.0厘米，BMI为24.9。未提供记录日期。',
      );
      expect(r.samples, hasLength(2));
      expect(r.samples.last.kg, 70);
      expect(r.samples.first.fat, 22.4);
      expect(r.height, 168);
      expect(r.bmi, 24.9);
      expect(r.warnings, isNotEmpty);
      expect(r.samples.every((s) => s.toJson().containsKey('time')), isFalse);
    },
  );
  test(
    'conflicting daily readings are not silently selected; changed formats do not fabricate values',
    () {
      final r = KeepImport.parse(
        account: 'fixture',
        start: start,
        end: end,
        weights: '2026-11-18：体重 70 公斤\n2026-11-18：体重 71 公斤',
        fats: '2026-11-18：体脂率 22%',
        profile: '未查询到身高',
      );
      expect(r.samples.single.kg, isNull);
      expect(r.samples.single.fat, 22);
      expect(r.warnings, hasLength(1));
      final unknown = KeepImport.parse(
        account: 'fixture',
        start: start,
        end: end,
        weights: '平均体重 70kg，目标65kg',
        fats: '暂无体脂率数据',
        profile: 'BMI为24.0，之前BMI为25.0',
      );
      expect(unknown.samples, isEmpty);
      expect(unknown.bmi, isNull);
      expect(unknown.warnings, hasLength(1));
    },
  );
  test(
    'Keep daily merge updates by account and date without deleting absent fields or other accounts',
    () {
      final day = DateTime(2026, 11, 18);
      final merged = mergeKeepSamples(
        [
          KeepSample(account: 'a', date: day, kg: 70, fat: 22),
          KeepSample(account: 'b', date: day, kg: 80),
        ],
        [KeepSample(account: 'a', date: day, kg: 69)],
      );
      expect(merged, hasLength(2));
      expect(merged.firstWhere((r) => r.account == 'a').kg, 69);
      expect(merged.firstWhere((r) => r.account == 'a').fat, 22);
    },
  );
  test(
    'date-only records stay in All day; timed readings take precedence, including exactly midnight',
    () {
      final day = DateTime(2026, 11, 18);
      final d = BodyData(
        records: [Measurement(id: 'precise', time: day, kg: 71, fat: 21)],
        keepSamples: [KeepSample(account: 'a', date: day, kg: 70, fat: 22)],
      );
      expect(d.onDay(day, Period.all), hasLength(2));
      expect(d.onDay(day, Period.morning).single.id, 'precise');
      expect(d.trend(0, day, day).single.value, 71);
      expect(d.trend(1, day, day).single.value, 21);
      final only = BodyData(
        keepSamples: [KeepSample(account: 'a', date: day, fat: 22)],
      );
      expect(only.allRecords, isEmpty);
      expect(only.trend(1, day, day).single.value, 22);
    },
  );
  test(
    'v3 backup preserves date precision and source keys; old backups load; invalid Keep values rejected',
    () {
      final d = BodyData(
        keepSamples: [
          KeepSample(account: 'a', date: DateTime(2026, 11, 18), kg: 70),
        ],
      );
      final loaded = BodyData.decode(d.encode());
      expect(loaded.keepSamples.single.key, d.keepSamples.single.key);
      expect(loaded.allRecords.single.dateOnly, isTrue);
      expect(jsonDecode(d.encode())['version'], 3);
      for (final v in [1, 2]) {
        final old = jsonDecode(d.encode()) as Map<String, dynamic>;
        old['version'] = v;
        old.remove('keepSamples');
        expect(BodyData.decode(jsonEncode(old)).keepSamples, isEmpty);
      }
      for (final bad in [
        <String, dynamic>{'account': 'a', 'date': '2026-02-30', 'kg': 70},
        {'account': 'a', 'date': '2026-11-18', 'kg': double.nan},
        {'account': 'a', 'date': '2026-11-18'},
      ]) {
        expect(() => KeepSample.fromJson(bad), throwsA(isA<FormatException>()));
      }
      final j = jsonDecode(d.encode()) as Map<String, dynamic>;
      j['keepSamples'] = [...j['keepSamples'], ...j['keepSamples']];
      expect(
        () => BodyData.decode(jsonEncode(j)),
        throwsA(isA<FormatException>()),
      );
    },
  );
  test(
    'MCP SSE session, authorization, secure persistence, explicit date queries and disconnect are read-only',
    () async {
      final vault = MemoryVault();
      final names = <String>[];
      var initialized = false;
      final client = MockClient((request) async {
        expect(request.url, KeepService.endpoint);
        final j = jsonDecode(request.body) as Map<String, dynamic>;
        final method = j['method'];
        Map<String, dynamic> result = {};
        if (method == 'initialize') {
          initialized = true;
          result = {'protocolVersion': '2025-03-26'};
        } else {
          expect(initialized, isTrue);
          expect(request.headers['Mcp-Session-Id'], 'fixture-session');
        }
        if (method == 'notifications/initialized') {
          return http.Response('', 202);
        }
        if (method == 'tools/call') {
          final p = j['params'] as Map<String, dynamic>,
              name = p['name'] as String;
          names.add(name);
          Map<String, dynamic> data;
          if (name == 'get_qrcode') {
            data = {
              'qrcodeId': 'qr',
              'qrcodeUrl': 'https://api.gotokeep.com/qr',
              'redirectUrl': 'https://show.gotokeep.com/auth',
            };
          } else if (name == 'check_login') {
            data = {
              'status': 'authorized',
              'token': 'fixture-secret',
              'user': {'id': 'user-fixture', 'username': 'Example'},
            };
          } else if (name == 'revoke_auth') {
            expect(request.headers['Authorization'], 'Bearer fixture-secret');
            data = {'success': true};
          } else {
            expect(name, 'query_tool');
            expect(request.headers['Authorization'], 'Bearer fixture-secret');
            final q = p['arguments']['text'] as String;
            if (q.contains('体重历史')) {
              expect(q, contains('2026-10-20至2026-11-18'));
              data = {'result': '2026-11-18：体重 70.2 公斤'};
            } else if (q.contains('体脂率历史')) {
              data = {'result': '2026-11-18：体脂率 22.4%'};
            } else {
              data = {'result': '身高为168厘米，BMI为24.9。'};
            }
          }
          result = {
            'content': [
              {'type': 'text', 'text': jsonEncode(data)},
            ],
          };
        }
        return http.Response(
          'event: message\ndata: ${jsonEncode({'jsonrpc': '2.0', 'id': j['id'], 'result': result})}\n\n',
          200,
          headers: {
            'content-type': 'text/event-stream; charset=utf-8',
            'mcp-session-id': 'fixture-session',
          },
        );
      });
      final api = KeepService(client: client, vault: vault);
      final qr = await api.startLogin();
      final c = await api.checkLogin(qr);
      expect(vault.value, isNull);
      await api.acceptLogin(c!);
      expect(vault.value, contains('fixture-secret'));
      final r = await api.read(days: 30, now: end);
      expect(r.samples.single.kg, 70.2);
      expect(r.height, 168);
      expect(
        BodyData(keepSamples: r.samples).encode(),
        isNot(contains('fixture-secret')),
      );
      expect(await api.disconnect(), isTrue);
      expect(vault.value, isNull);
      expect(names.toSet(), {
        'get_qrcode',
        'check_login',
        'query_tool',
        'revoke_auth',
      });
    },
  );
  test(
    'expired credentials do not issue data requests; foreign authorization URLs rejected',
    () async {
      var calls = 0;
      final v = MemoryVault(
        jsonEncode(
          KeepCredentials(
            token: 'secret',
            userId: 'a',
            username: 'A',
            expires: DateTime(2000),
          ).toJson(),
        ),
      );
      final api = KeepService(
        vault: v,
        client: MockClient((r) async {
          calls++;
          return http.Response('', 500);
        }),
      );
      await api.restore();
      await expectLater(api.read(days: 30), throwsA(isA<KeepException>()));
      expect(calls, 0);
      expect(keepUrlAllowed(Uri.parse('https://api.gotokeep.com/qr')), true);
      expect(
        keepUrlAllowed(Uri.parse('https://api.gotokeep.com.evil.example/qr')),
        false,
      );
      expect(keepUrlAllowed(Uri.parse('http://show.gotokeep.com/auth')), false);
    },
  );
}
