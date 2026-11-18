import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearanceStore {
  static const key = 'bodylog.appearance';
  Future<ThemeMode> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  Future<bool> save(ThemeMode mode) async =>
      (await SharedPreferences.getInstance()).setString(key, mode.name);
}
