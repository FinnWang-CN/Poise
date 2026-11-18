import 'package:shared_preferences/shared_preferences.dart';

/// Device-level connection preferences, separate from measurement backups.
class HealthSyncSettings {
  static const enabledKey = 'bodylog.healthAutoSync';
  static const connectedKey = 'bodylog.healthConnected';
  static const heightKey = 'bodylog.healthSyncHeight';
  static const daysKey = 'bodylog.healthSyncDays';
  final bool enabled, connected, includeHeight;
  final int days;
  const HealthSyncSettings({
    this.enabled = true,
    this.connected = false,
    this.includeHeight = false,
    this.days = 30,
  });
  static Future<HealthSyncSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final days = p.getInt(daysKey) ?? 30;
    return HealthSyncSettings(
      enabled: p.getBool(enabledKey) ?? true,
      connected: p.getBool(connectedKey) ?? false,
      includeHeight: p.getBool(heightKey) ?? false,
      days: [7, 30, 90, 365].contains(days) ? days : 30,
    );
  }

  static Future<void> setEnabled(bool value) async {
    if (!await (await SharedPreferences.getInstance()).setBool(
      enabledKey,
      value,
    )) {
      throw StateError('Could not save auto-sync preference');
    }
  }

  static Future<void> rememberConnection({
    required bool includeHeight,
    required int days,
  }) async {
    final p = await SharedPreferences.getInstance();
    if (!await p.setBool(heightKey, includeHeight) ||
        !await p.setInt(daysKey, days) ||
        !await p.setBool(connectedKey, true)) {
      throw StateError('Could not save health connection');
    }
  }
}
