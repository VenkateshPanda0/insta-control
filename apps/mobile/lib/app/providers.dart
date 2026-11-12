import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions/permission_service.dart';
import '../core/platform_capabilities/capability.dart';
import '../core/platform_capabilities/capability_registry.dart';
import '../core/platform_capabilities/native_services.dart';
import '../core/platform_capabilities/platform_capability_service.dart';
import '../core/storage/app_settings.dart';
import '../core/usage/usage_models.dart';

/// Overridden in `main` (and in tests) with a real store.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('settingsStoreProvider not overridden'),
);

final capabilityServiceProvider = Provider<PlatformCapabilityService>(
  (ref) => const MethodChannelCapabilityService(),
);

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const MethodChannelPermissionService(),
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsStoreProvider).load();

  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    await ref.read(settingsStoreProvider).save(state);
  }

  Future<void> deleteAllData() async {
    await ref.read(settingsStoreProvider).deleteAll();
    state = const AppSettings();
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class PlatformReportController extends AsyncNotifier<PlatformReport> {
  @override
  Future<PlatformReport> build() =>
      ref.read(capabilityServiceProvider).fetchReport();

  Future<void> refresh() async {
    state = AsyncData(await ref.read(capabilityServiceProvider).fetchReport());
  }

  Future<PermissionRequestResult> requestPermission(
    AppPermission permission,
  ) async {
    final result = await ref
        .read(permissionServiceProvider)
        .request(permission);
    await refresh();
    return result;
  }
}

final platformReportProvider =
    AsyncNotifierProvider<PlatformReportController, PlatformReport>(
      PlatformReportController.new,
    );

/// Until the device has answered, everything is treated as unavailable.
final capabilityRegistryProvider = Provider<CapabilityRegistry>((ref) {
  final report = ref.watch(platformReportProvider).value;
  return CapabilityRegistry(
    report ?? const PlatformReport.unreachable('Checking this device…'),
  );
});

const _native = MethodChannelNativeServices();

final usageServiceProvider = Provider<UsageReportingService>((ref) => _native);
final appSelectionServiceProvider = Provider<ApplicationSelectionService>(
  (ref) => _native,
);
final restrictionServiceProvider = Provider<RestrictionService>(
  (ref) => _native,
);

/// Measured usage, or null when the device cannot provide it. Re-read
/// whenever the device report changes (for example after returning to the app).
final usageReportProvider = FutureProvider<UsageReport?>((ref) async {
  final registry = ref.watch(capabilityRegistryProvider);
  if (!registry.of(FeatureId.usageReporting).isUsable) return null;
  return ref.read(usageServiceProvider).fetchReport();
});

final installedAppsProvider = FutureProvider.autoDispose<List<InstalledApp>>(
  (ref) => ref.read(appSelectionServiceProvider).listInstalledApps(),
);

/// iOS Screen Time selection counts and shield state.
class TokenSelectionController extends AsyncNotifier<TokenSelectionSummary?> {
  @override
  Future<TokenSelectionSummary?> build() =>
      ref.read(appSelectionServiceProvider).selectionSummary();

  Future<void> pick() async {
    final next = await ref
        .read(appSelectionServiceProvider)
        .presentSystemPicker();
    if (next != null) state = AsyncData(next);
  }

  Future<void> setShieldActive(bool active) async {
    final next = await ref
        .read(restrictionServiceProvider)
        .setShieldActive(active);
    if (next != null) state = AsyncData(next);
  }
}

final tokenSelectionProvider =
    AsyncNotifierProvider<TokenSelectionController, TokenSelectionSummary?>(
      TokenSelectionController.new,
    );

/// Keeps the Android background reminder check in step with saved budgets.
final budgetSyncProvider = Provider<void>((ref) {
  final apps = ref.watch(settingsProvider.select((s) => s.managedApps));
  ref.read(restrictionServiceProvider).syncBudgets(apps);
});
