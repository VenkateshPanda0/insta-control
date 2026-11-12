import 'package:flutter/services.dart';

import '../storage/app_settings.dart';
import '../usage/usage_models.dart';
import 'platform_capability_service.dart';

class InstalledApp {
  const InstalledApp(this.packageName, this.label);
  final String packageName;
  final String label;
}

/// What iOS lets us know about the user's Screen Time selection: counts only.
/// The apps themselves are opaque tokens that stay on the native side.
class TokenSelectionSummary {
  const TokenSelectionSummary({
    this.apps = 0,
    this.categories = 0,
    this.webDomains = 0,
    this.shieldActive = false,
  });
  final int apps;
  final int categories;
  final int webDomains;
  final bool shieldActive;

  bool get isEmpty => apps + categories + webDomains == 0;

  static TokenSelectionSummary? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    int n(String k) => map[k] is int ? map[k] as int : 0;
    return TokenSelectionSummary(
      apps: n('apps'),
      categories: n('categories'),
      webDomains: n('webDomains'),
      shieldActive: map['shieldActive'] == true,
    );
  }
}

/// All methods return null / empty on failure instead of throwing, so a
/// native problem can never crash the shared UI.
abstract interface class UsageReportingService {
  Future<UsageReport?> fetchReport();
}

abstract interface class ApplicationSelectionService {
  /// Android: apps with a launcher icon.
  Future<List<InstalledApp>> listInstalledApps();

  /// iOS: shows Apple's app picker and returns the new selection counts.
  Future<TokenSelectionSummary?> presentSystemPicker();
  Future<TokenSelectionSummary?> selectionSummary();
}

abstract interface class RestrictionService {
  /// iOS: shield (or unshield) the selected apps now.
  Future<TokenSelectionSummary?> setShieldActive(bool active);

  /// Android: hand daily budgets to the background reminder check.
  Future<void> syncBudgets(Map<String, ManagedApp> apps);
}

class MethodChannelNativeServices
    implements
        UsageReportingService,
        ApplicationSelectionService,
        RestrictionService {
  const MethodChannelNativeServices();

  Future<T?> _guard<T>(Future<T?> Function() call) async {
    try {
      return await call();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<Map<Object?, Object?>?> _map(String method, [Object? args]) => _guard(
    () => platformChannel.invokeMapMethod<Object?, Object?>(method, args),
  );

  @override
  Future<UsageReport?> fetchReport() async {
    final map = await _map('getUsageReport');
    return map == null ? null : UsageReport.fromMap(map);
  }

  @override
  Future<List<InstalledApp>> listInstalledApps() async {
    final list = await _guard(
      () => platformChannel.invokeListMethod<Object?>('listInstalledApps'),
    );
    return [
      for (final item in list ?? const [])
        if (item is Map && item['package'] is String && item['label'] is String)
          InstalledApp(item['package'] as String, item['label'] as String),
    ];
  }

  @override
  Future<TokenSelectionSummary?> presentSystemPicker() async =>
      TokenSelectionSummary.fromMap(await _map('presentAppPicker'));

  @override
  Future<TokenSelectionSummary?> selectionSummary() async =>
      TokenSelectionSummary.fromMap(await _map('getSelectionSummary'));

  @override
  Future<TokenSelectionSummary?> setShieldActive(bool active) async =>
      TokenSelectionSummary.fromMap(
        await _map('setShieldActive', {'active': active}),
      );

  @override
  Future<void> syncBudgets(Map<String, ManagedApp> apps) => _guard(
    () => platformChannel.invokeMethod<void>('syncBudgets', {
      'budgets': {
        for (final e in apps.entries)
          if (e.value.dailyLimitMinutes != null)
            e.key: {
              'label': e.value.label,
              'minutes': e.value.dailyLimitMinutes,
            },
      },
    }),
  );
}
