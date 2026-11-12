import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions/permission_service.dart';
import '../core/platform_capabilities/capability.dart';
import '../core/platform_capabilities/capability_registry.dart';
import '../core/platform_capabilities/platform_capability_service.dart';
import '../core/storage/app_settings.dart';

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
    final result = await ref.read(permissionServiceProvider).request(permission);
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
