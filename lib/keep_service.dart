import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'model.dart';

class KeepException implements Exception {
  final String message;
  const KeepException(this.message);
  @override
  String toString() => message;
}

class KeepCredentials {
  final String token, userId, username;
  final DateTime? expires;
  const KeepCredentials({
    required this.token,
    required this.userId,
    required this.username,
    this.expires,
  });
  String get account => sha256.convert(utf8.encode(userId)).toString();
  bool get expired => expires != null && !expires!.isAfter(DateTime.now());
  Map<String, dynamic> toJson() => {
    'token': token,
    'userId': userId,
    'username': username,
    'expires': expires?.toIso8601String(),
  };
  factory KeepCredentials.fromJson(Map<String, dynamic> j) {
    final c = KeepCredentials(
      token: j['token'] as String,
      userId: j['userId'] as String,
      username: j['username'] as String? ?? 'Keep',
      expires:
          j['expires'] == null ? null : DateTime.parse(j['expires'] as String),
    );
    if (c.token.isEmpty || c.userId.isEmpty) {
      throw const KeepException('Keep 登录信息无效，请重新连接。');
    }
    return c;
  }
}

abstract class KeepVault {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureKeepVault implements KeepVault {
  static const key = 'poise.keep.connection.v1';
  final FlutterSecureStorage storage;
  const SecureKeepVault({
    this.storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  });
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String value) => storage.write(key: key, value: value);
  @override
  Future<void> delete() => storage.delete(key: key);
}

class KeepLogin {
  final String id;
  final Uri image, redirect;
  const KeepLogin(this.id, this.image, this.redirect);
}

bool keepUrlAllowed(Uri u) =>
    u.scheme == 'https' &&
    (u.host == 'gotokeep.com' || u.host.endsWith('.gotokeep.com'));

// Keep's official login page uses keep://webview/<encoded HTTPS URL>.
// Hand off only that authorization route; never accept arbitrary app links.
Uri keepAuthorizationLink(Uri redirect) {
  if (redirect.scheme != 'https' ||
      redirect.host != 'show.gotokeep.com' ||
      redirect.path != '/login/auth' ||
      redirect.userInfo.isNotEmpty ||
      redirect.hasPort ||
      redirect.fragment.isNotEmpty) {
    throw const KeepException('Keep 授权链接无效，请重新连接。');
  }
  return Uri.parse(
    'keep://webview/${Uri.encodeComponent(redirect.toString())}?isExternalLaunch=1',
  );
}

class KeepImport {
  final List<KeepSample> samples;
  final double? height, bmi;
  final List<String> warnings;
  final String raw;
  const KeepImport({
    required this.samples,
    this.height,
    this.bmi,
    this.warnings = const [],
    this.raw = '',
  });
  factory KeepImport.parse({
    required String account,
    required String weights,
    required String fats,
    required String profile,
    required DateTime start,
    required DateTime end,
  }) {
    final warnings = <String>[];
    Map<DateTime, double> readings(String text, bool fat) {
      final byDate = <DateTime, Set<double>>{};
      final re = RegExp(
        r'^\s*(?:[-*•]\s*)?(\d{4}-\d{1,2}-\d{1,2})\s*[:：]\s*' +
            (fat
                ? r'体脂率\s*([0-9]+(?:\.[0-9]+)?)\s*(%|％)'
                : r'体重\s*([0-9]+(?:\.[0-9]+)?)\s*(公斤|千克|kg|斤)') +
            r'\s*[。.]?\s*$',
        caseSensitive: false,
      );
      for (final line in const LineSplitter().convert(
        text.replaceAll('**', ''),
      )) {
        final m = re.firstMatch(line);
        if (m == null) continue;
        final date = DateTime.tryParse(m[1]!);
        if (date == null) continue;
        final parts = m[1]!.split('-').map(int.parse).toList();
        var value = double.parse(m[2]!);
        if (!fat && m[3] == '斤') value /= 2;
        if (date.year != parts[0] ||
            date.month != parts[1] ||
            date.day != parts[2] ||
            date.isBefore(dayOf(start)) ||
            date.isAfter(dayOf(end)) ||
            !value.isFinite ||
            (fat
                ? (value <= 0 || value >= 100)
                : (value < 10 || value > 500))) {
          warnings.add('已跳过无效或超出读取范围的 Keep 数据。');
          continue;
        }
        byDate.putIfAbsent(date, () => {}).add(value);
      }
      if (byDate.isEmpty &&
          !RegExp(
            r'暂无|没有.*(?:数据|记录)|未(?:查|查询)到|no\s+(?:data|records)',
            caseSensitive: false,
          ).hasMatch(text)) {
        warnings.add(
          fat ? '未识别体脂率明细，请检查 Keep 返回内容。' : '未识别体重明细，请检查 Keep 返回内容。',
        );
      }
      final result = <DateTime, double>{};
      byDate.forEach((date, values) {
        if (values.length == 1) {
          result[date] = values.single;
        } else {
          warnings.add('同一天存在不同数值，已跳过该日该项，请在 Keep 中核对。');
        }
      });
      return result;
    }

    final w = readings(weights, false), f = readings(fats, true);
    double? scalar(RegExp re, double min, double max) {
      final values =
          re.allMatches(profile).map((m) => double.parse(m[1]!)).toSet();
      if (values.length != 1) return null;
      final value = values.single;
      return value.isFinite && value >= min && value <= max ? value : null;
    }

    final h = scalar(
      RegExp(
        r'身高\s*(?:为|是|[:：])?\s*([0-9]+(?:\.[0-9]+)?)\s*(?:厘米|公分|cm)',
        caseSensitive: false,
      ),
      80,
      250,
    );
    final bmi = scalar(
      RegExp(
        r'BMI\s*(?:为|是|[:：])?\s*([0-9]+(?:\.[0-9]+)?)',
        caseSensitive: false,
      ),
      5,
      100,
    );
    final dates = {...w.keys, ...f.keys}.toList()..sort();
    return KeepImport(
      samples: [
        for (final d in dates)
          KeepSample(account: account, date: d, kg: w[d], fat: f[d]),
      ],
      height: h,
      bmi: bmi,
      warnings: warnings.toSet().toList(),
      raw: '$weights\n\n$fats\n\n$profile',
    );
  }
}

/// Read-only MCP client. Never invokes Keep record/upload tools.
class KeepService {
  static final endpoint = Uri.parse(
    'https://mcp.gotokeep.com/skills-mcp-gateway-page/v1',
  );
  final http.Client client;
  final KeepVault vault;
  KeepCredentials? _credentials;
  String? _session;
  int _id = 0;
  bool _ready = false;
  KeepService({http.Client? client, KeepVault? vault})
    : client = client ?? http.Client(),
      vault = vault ?? const SecureKeepVault();
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  static const appChannel = MethodChannel('com.qingheng.bodylog/keep');
  Future<bool> isAppInstalled() async =>
      await appChannel.invokeMethod<bool>('isInstalled') ?? false;
  Future<bool> openAuthorization(KeepLogin login) async =>
      await appChannel.invokeMethod<bool>('openAuthorization', {
        'url': keepAuthorizationLink(login.redirect).toString(),
      }) ??
      false;
  KeepCredentials? get credentials => _credentials;
  Future<KeepCredentials?> restore() async {
    String? text;
    try {
      text = await vault.read();
    } catch (_) {
      throw const KeepException('设备安全存储不可用，请检查系统后重试。');
    }
    if (text == null) return null;
    try {
      _credentials = KeepCredentials.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );
    } catch (_) {
      await vault.delete();
      throw const KeepException('Keep 登录信息无效，请重新连接。');
    }
    return _credentials;
  }

  Future<Map<String, dynamic>> _wire(
    String method,
    Map<String, dynamic>? params, {
    bool notification = false,
  }) async {
    final id = ++_id;
    final response = await client
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json, text/event-stream',
            if (_session != null) 'Mcp-Session-Id': _session!,
            if (_ready) 'MCP-Protocol-Version': '2025-03-26',
            if (_credentials != null)
              'Authorization': 'Bearer ${_credentials!.token}',
          },
          body: jsonEncode({
            'jsonrpc': '2.0',
            'method': method,
            if (!notification) 'id': id,
            if (params != null) 'params': params,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const KeepException('Keep 授权已失效，请重新连接。');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 400 || response.statusCode == 404) {
        _ready = false;
        _session = null;
      }
      throw const KeepException('Keep 服务暂不可用，请稍后重试。');
    }
    _session = response.headers['mcp-session-id'] ?? _session;
    if (notification) return {};
    final body = utf8.decode(response.bodyBytes);
    final candidates = <String>[];
    if (body.trimLeft().startsWith('{')) {
      candidates.add(body);
    } else {
      var parts = <String>[];
      for (final line in const LineSplitter().convert(body)) {
        if (line.startsWith('data:')) parts.add(line.substring(5).trimLeft());
        if (line.isEmpty && parts.isNotEmpty) {
          candidates.add(parts.join('\n'));
          parts = [];
        }
      }
      if (parts.isNotEmpty) candidates.add(parts.join('\n'));
    }
    for (final text in candidates) {
      dynamic raw;
      try {
        raw = jsonDecode(text);
      } catch (_) {
        throw const KeepException('Keep 返回格式有变化，请稍后重试。');
      }
      if (raw is! Map<String, dynamic> || raw['id'] != id) continue;
      if (raw['error'] != null) {
        throw const KeepException('Keep 返回错误，请重新连接后重试。');
      }
      if (raw['result'] is Map<String, dynamic>) {
        return raw['result'] as Map<String, dynamic>;
      }
    }
    throw const KeepException('Keep 返回格式有变化，请稍后重试。');
  }

  Future<void> _initialize() async {
    if (_ready) return;
    _session = null;
    await _wire('initialize', {
      'protocolVersion': '2025-03-26',
      'capabilities': {},
      'clientInfo': {'name': 'Poise', 'version': '0.8.6'},
    });
    await _wire('notifications/initialized', null, notification: true);
    _ready = true;
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    await _initialize();
    final r = await _wire('tools/call', {'name': name, 'arguments': arguments});
    final content = r['content'];
    if (content is! List) throw const KeepException('Keep 返回格式有变化，请稍后重试。');
    final text = content
        .whereType<Map>()
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'])
        .whereType<String>()
        .join('\n');
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const KeepException('Keep 返回格式有变化，请稍后重试。');
    }
    if (r['isError'] == true ||
        decoded['error'] != null ||
        decoded['code'] == 'AUTH_REQUIRED' ||
        decoded['code'] == 'TOKEN_EXPIRED') {
      throw const KeepException('Keep 请求失败或授权已失效，请重新连接后重试。');
    }
    return decoded;
  }

  Future<KeepLogin> startLogin() async {
    _credentials = null;
    _ready = false;
    _session = null;
    final d = await _call('get_qrcode', {});
    final id = d['qrcodeId'] as String?,
        image = Uri.tryParse(d['qrcodeUrl'] as String? ?? ''),
        redirect = Uri.tryParse(d['redirectUrl'] as String? ?? '');
    if (id == null ||
        image == null ||
        redirect == null ||
        !keepUrlAllowed(image) ||
        !keepUrlAllowed(redirect)) {
      throw const KeepException('无法获取 Keep 授权会话，请重试。');
    }
    return KeepLogin(id, image, redirect);
  }

  Future<KeepCredentials?> checkLogin(KeepLogin login) async {
    final d = await _call('check_login', {'qrcodeId': login.id});
    if (d['status'] == 'pending') return null;
    final token = d['token'];
    final user = d['user'];
    if (d['status'] != 'authorized' ||
        token is! String ||
        user is! Map ||
        user['id'] == null) {
      throw const KeepException('Keep 授权已超时，请重新连接。');
    }
    DateTime? expires;
    try {
      final j = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      );
      if (j['exp'] is num) {
        expires = DateTime.fromMillisecondsSinceEpoch(
          (j['exp'] as num).toInt() * 1000,
        );
      }
    } catch (_) {
      /* Server will validate opaque credentials. */
    }
    final c = KeepCredentials(
      token: token,
      userId: user['id'].toString(),
      username: (user['username'] ?? user['name'] ?? 'Keep').toString(),
      expires: expires,
    );
    if (c.userId.isEmpty || c.token.isEmpty || c.expired) {
      throw const KeepException('Keep 授权已失效，请重新连接。');
    }
    return c;
  }

  Future<void> acceptLogin(KeepCredentials c) async {
    try {
      await vault.write(jsonEncode(c.toJson()));
    } catch (_) {
      throw const KeepException('设备安全存储不可用，请检查系统后重试。');
    }
    _credentials = c;
  }

  Future<KeepImport> read({required int days, DateTime? now}) async {
    final c = _credentials;
    if (c == null || c.expired) throw const KeepException('Keep 授权已失效，请重新连接。');
    if (![7, 30, 90, 365].contains(days)) throw const KeepException('读取范围无效。');
    final end = dayOf(now ?? DateTime.now()),
        start = dayOf(now ?? DateTime.now()).subtract(Duration(days: days - 1));
    final range = '${dateLabel(start)}至${dateLabel(end)}';
    Future<String> query(String text) async {
      final d = await _call('query_tool', {'text': text});
      if (d['result'] is! String) {
        throw const KeepException('Keep 返回格式有变化，请稍后重试。');
      }
      return d['result'] as String;
    }

    final weights = await query(
      '查询我在$range的全部体重历史明细，请按“YYYY-MM-DD：体重 数值 公斤”逐条返回，仅返回已有数据，不要推算、汇总或编造日期和数值；没有数据请明确说明。',
    );
    final fats = await query(
      '查询我在$range的全部体脂率历史明细，请按“YYYY-MM-DD：体脂率 数值%”逐条返回，仅返回已有数据，不要推算、汇总或编造日期和数值；没有数据请明确说明。',
    );
    final profile = await query(
      '查询我已保存的最新身高和BMI，返回已有数值及单位；没有数据请明确说明，不要根据其他指标推算或补全。',
    );
    return KeepImport.parse(
      account: c.account,
      weights: weights,
      fats: fats,
      profile: profile,
      start: start,
      end: end,
    );
  }

  Future<bool> disconnect() async {
    var revoked = true;
    try {
      if (_credentials != null) await _call('revoke_auth', {});
    } catch (_) {
      revoked = false;
    }
    await vault.delete();
    _credentials = null;
    _ready = false;
    _session = null;
    return revoked;
  }

  void dispose() => client.close();
}
