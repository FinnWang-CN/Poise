import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'translations.dart';

enum AppLanguage { zh, en, system }

class LanguageStore {
  static const key = 'bodylog.language';
  Future<AppLanguage> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    return AppLanguage.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => AppLanguage.zh,
    );
  }

  Future<bool> save(AppLanguage value) async =>
      (await SharedPreferences.getInstance()).setString(key, value.name);
}

bool isEnglish(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'en';
String tr(BuildContext context, String source) =>
    isEnglish(context) ? english(source) : source;

// Catalog entries may use numbered slots for dynamic measurements/counts.
final _patterns =
    translations.entries.where((e) => e.key.contains('{0}')).map((e) {
      final parts = e.key.split(RegExp(r'\{\d+\}'));
      return (
        RegExp(
          '^${parts.map(RegExp.escape).join('(.*?)')}\u0024',
          dotAll: true,
        ),
        e.value,
      );
    }).toList();
String english(String source) {
  final exact = translations[source];
  if (exact != null) return exact;
  for (final entry in _patterns) {
    final m = entry.$1.firstMatch(source);
    if (m != null) {
      return entry.$2.replaceAllMapped(
        RegExp(r'\{(\d+)\}'),
        (slot) => english(m.group(int.parse(slot[1]!) + 1) ?? ''),
      );
    }
  }
  // Multi-line summaries combine independently localized catalog entries.
  if (source.contains('\n')) return source.split('\n').map(english).join('\n');
  return source;
}
