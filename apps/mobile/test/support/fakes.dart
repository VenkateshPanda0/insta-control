import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unscroll/app/app.dart';
import 'package:unscroll/app/providers.dart';
import 'package:unscroll/core/permissions/permission_service.dart';
import 'package:unscroll/core/platform_capabilities/capability.dart';
import 'package:unscroll/core/platform_capabilities/native_services.dart';
import 'package:unscroll/core/platform_capabilities/platform_capability_service.dart';
import 'package:unscroll/core/rule_engine/engine.dart';
import 'package:unscroll/core/storage/app_settings.dart';
import 'package:unscroll/core/storage/json_store.dart';
import 'package:unscroll/core/usage/usage_models.dart';

/// Scripted native layer. Tests using it cover UI and data flow only; real
/// usage reading, shields and notifications need a physical device.
class FakeNative
    implements
        PlatformCapabilityService,
        PermissionService,
        UsageReportingService,
        ApplicationSelectionService,
        RestrictionService {
  FakeNative(
    this.platform,
    this.capabilities, {
    Map<String, String>? permissions,
  }) : permissions = permissions ?? {};
  final String platform;
  final Map<String, String> capabilities;
  final Map<String, String> permissions;

  var selection = const TokenSelectionSummary();
  final plans = <NativePlan>[];
  final permissionRequests = <AppPermission>[];
  final sessionEnds = <DateTime>[];
  var sessionEndCancels = 0;
  var usageFetches = 0;

  @override
  Future<PlatformReport> fetchReport() async => PlatformReport.fromMap({
    'platform': platform,
    'osVersion': 'test',
    'permissions': permissions,
    'capabilities': {
      for (final e in capabilities.entries)
        e.key: {'status': e.value, 'reason': 'Reason for ${e.key}.'},
    },
  });

  @override
  Future<PermissionRequestResult> request(AppPermission permission) async {
    permissionRequests.add(permission);
    permissions[permission.name] = 'granted';
    return const PermissionRequestResult(
      PermissionRequestOutcome.openedSettings,
    );
  }

  @override
  Future<UsageReport?> fetchUsage() async {
    usageFetches++;
    final today = DateTime(2026, 11, 12);
    return UsageReport(
      days: [
        for (var i = 6; i >= 0; i--)
          DayUsage(
            today.subtract(Duration(days: i)),
            Duration(minutes: 30 + i * 10),
          ),
      ],
      todayApps: const [
        AppUsage('com.example.video', 'Vidstream', Duration(minutes: 22)),
        AppUsage('com.example.chat', 'Chatter', Duration(minutes: 8)),
      ],
    );
  }

  @override
  Future<List<InstalledApp>> listInstalledApps() async => const [
    InstalledApp('com.example.chat', 'Chatter'),
    InstalledApp('com.example.video', 'Vidstream'),
  ];

  @override
  Future<TokenSelectionSummary?> presentSystemPicker() async =>
      selection = TokenSelectionSummary(
        apps: 2,
        categories: 1,
        shieldActive: selection.shieldActive,
      );

  @override
  Future<TokenSelectionSummary?> selectionSummary() async => selection;

  @override
  Future<TokenSelectionSummary?> setShieldActive(bool active) async =>
      selection = TokenSelectionSummary(
        apps: selection.apps,
        categories: selection.categories,
        shieldActive: active,
      );

  @override
  Future<void> syncPlan(NativePlan plan) async => plans.add(plan);

  @override
  Future<void> scheduleSessionEnd(DateTime at, String modeName) async =>
      sessionEnds.add(at);

  @override
  Future<void> cancelSessionEnd() async => sessionEndCancels++;
}

/// A clock tests can move.
class TestClock {
  TestClock([DateTime? start]) : now = start ?? DateTime(2026, 11, 12, 10);
  DateTime now;
  DateTime call() => now;
}

const onboardedPrefs = <String, Object>{
  'settings.v1': '{"onboardingComplete":true}',
};

Future<SharedPreferences> pumpUnscroll(
  WidgetTester tester,
  FakeNative native, {
  Map<String, Object> initial = onboardedPrefs,
  TestClock? clock,
}) async {
  // A tall phone-width surface so lazily built list items exist in tests.
  tester.view.physicalSize = const Size(420, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(PrefsSettingsStore(prefs)),
        jsonStoreProvider.overrideWithValue(PrefsJsonStore(prefs)),
        capabilityServiceProvider.overrideWithValue(native),
        permissionServiceProvider.overrideWithValue(native),
        usageServiceProvider.overrideWithValue(native),
        appSelectionServiceProvider.overrideWithValue(native),
        restrictionServiceProvider.overrideWithValue(native),
        if (clock != null) clockProvider.overrideWithValue(clock.call),
      ],
      child: const UnscrollApp(),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

Future<void> openTab(WidgetTester tester, String tab) async {
  await tester.tap(find.widgetWithText(NavigationDestination, tab));
  await tester.pumpAndSettle();
}

/// Scrolls the visible page until [finder] can be tapped, then taps it.
Future<void> scrollTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
