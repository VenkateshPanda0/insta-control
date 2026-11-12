import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

enum FrictionMode {
  gentle('Gentle', 'Encouraging reminders only.'),
  balanced('Balanced', 'Reminders plus restrictions where your device allows.'),
  strict('Strict', 'Stronger restrictions and deliberate override steps.');

  const FrictionMode(this.title, this.summary);
  final String title;
  final String summary;
}

/// An installed app the user chose to manage (Android).
class ManagedApp {
  const ManagedApp(this.label, {this.dailyLimitMinutes});
  final String label;

  /// Daily budget that triggers a reminder; null means no budget.
  final int? dailyLimitMinutes;

  Map<String, Object?> toJson() => {
    'label': label,
    'dailyLimitMinutes': ?dailyLimitMinutes,
  };
}

class AppSettings {
  const AppSettings({
    this.managedApps = const {},
    this.onboardingComplete = false,
    this.themeMode = AppThemeMode.system,
    this.goals = const {},
    this.managedPresets = const {},
    this.frictionMode = FrictionMode.gentle,
  });

  final bool onboardingComplete;
  final AppThemeMode themeMode;
  final Set<String> goals;
  final Set<String> managedPresets;
  final FrictionMode frictionMode;

  /// Package name -> managed app.
  final Map<String, ManagedApp> managedApps;

  AppSettings copyWith({
    Map<String, ManagedApp>? managedApps,
    bool? onboardingComplete,
    AppThemeMode? themeMode,
    Set<String>? goals,
    Set<String>? managedPresets,
    FrictionMode? frictionMode,
  }) => AppSettings(
    managedApps: managedApps ?? this.managedApps,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    themeMode: themeMode ?? this.themeMode,
    goals: goals ?? this.goals,
    managedPresets: managedPresets ?? this.managedPresets,
    frictionMode: frictionMode ?? this.frictionMode,
  );

  Map<String, Object?> toJson() => {
    'onboardingComplete': onboardingComplete,
    'themeMode': themeMode.name,
    'goals': goals.toList(),
    'managedPresets': managedPresets.toList(),
    'frictionMode': frictionMode.name,
    'managedApps': {
      for (final e in managedApps.entries) e.key: e.value.toJson(),
    },
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    Set<String> strings(Object? v) =>
        v is List ? v.whereType<String>().toSet() : const {};
    final apps = <String, ManagedApp>{};
    final rawApps = json['managedApps'];
    if (rawApps is Map) {
      rawApps.forEach((key, value) {
        if (key is! String || value is! Map || value['label'] is! String) {
          return;
        }
        final limit = value['dailyLimitMinutes'];
        apps[key] = ManagedApp(
          value['label'] as String,
          dailyLimitMinutes: limit is int && limit > 0 ? limit : null,
        );
      });
    }
    return AppSettings(
      managedApps: apps,
      onboardingComplete: json['onboardingComplete'] == true,
      themeMode:
          AppThemeMode.values.asNameMap()[json['themeMode']] ??
          AppThemeMode.system,
      goals: strings(json['goals']),
      managedPresets: strings(json['managedPresets']),
      frictionMode:
          FrictionMode.values.asNameMap()[json['frictionMode']] ??
          FrictionMode.gentle,
    );
  }
}

/// Local-only settings persistence. Nothing here leaves the device.
abstract interface class SettingsStore {
  AppSettings load();
  Future<void> save(AppSettings settings);
  Future<void> deleteAll();
}

class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'settings.v1';

  @override
  AppSettings load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) return AppSettings.fromJson(decoded);
    } on FormatException {
      // Corrupt data: fall back to defaults rather than crash at startup.
    }
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) =>
      _prefs.setString(_key, jsonEncode(settings.toJson()));

  @override
  Future<void> deleteAll() => _prefs.clear();
}
