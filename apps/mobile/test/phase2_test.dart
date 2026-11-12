import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unscroll/app/app.dart';
import 'package:unscroll/app/providers.dart';
import 'package:unscroll/core/platform_capabilities/capability.dart';
import 'package:unscroll/core/platform_capabilities/native_services.dart';
import 'package:unscroll/core/platform_capabilities/platform_capability_service.dart';
import 'package:unscroll/core/storage/app_settings.dart';
import 'package:unscroll/core/usage/usage_models.dart';

/// Scripted native layer. These tests cover UI and data flow only; real
/// usage reading, shields and notifications need a physical device.
class FakeNative
    implements
        PlatformCapabilityService,
        ApplicationSelectionService,
        RestrictionService {
  FakeNative(this.platform, this.capabilities);
  final String platform;
  final Map<String, String> capabilities;

  var selection = const TokenSelectionSummary();
  final budgetSyncs = <Map<String, ManagedApp>>[];
  var usageFetches = 0;

  @override
  Future<PlatformReport> fetchReport() async => PlatformReport.fromMap({
    'platform': platform,
    'osVersion': 'test',
    'capabilities': {
      for (final e in capabilities.entries)
        e.key: {'status': e.value, 'reason': 'Reason for ${e.key}.'},
    },
  });

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
  Future<void> syncBudgets(Map<String, ManagedApp> apps) async =>
      budgetSyncs.add(apps);
}

class FakeUsage implements UsageReportingService {
  FakeUsage(this.native);
  final FakeNative native;

  @override
  Future<UsageReport?> fetchReport() async {
    native.usageFetches++;
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
}

Future<FakeNative> pumpApp(WidgetTester tester, FakeNative native) async {
  SharedPreferences.setMockInitialValues({
    'settings.v1': '{"onboardingComplete":true}',
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(PrefsSettingsStore(prefs)),
        capabilityServiceProvider.overrideWithValue(native),
        usageServiceProvider.overrideWithValue(FakeUsage(native)),
        appSelectionServiceProvider.overrideWithValue(native),
        restrictionServiceProvider.overrideWithValue(native),
      ],
      child: const UnscrollApp(),
    ),
  );
  await tester.pumpAndSettle();
  return native;
}

Future<void> openTab(WidgetTester tester, String tab) async {
  await tester.tap(find.widgetWithText(NavigationDestination, tab));
  await tester.pumpAndSettle();
}

void main() {
  test('usage report parsing drops malformed rows', () {
    final report = UsageReport.fromMap({
      'days': [
        {'start': 0, 'totalMs': 60000},
        {'start': 'x', 'totalMs': 1},
        {'start': 86400000, 'totalMs': 5400000},
      ],
      'todayApps': [
        {'package': 'a', 'label': 'A', 'ms': 5400000},
        {'package': 'b', 'label': 'B', 'ms': 0},
        {'package': 'c', 'ms': 10},
      ],
    });
    expect(report.days, hasLength(2));
    expect(report.today, const Duration(minutes: 90));
    expect(report.todayApps.single.label, 'A');
    expect(report.usageFor('a'), const Duration(minutes: 90));
    expect(report.usageFor('zzz'), Duration.zero);
  });

  test('durations are formatted for people', () {
    expect(formatDuration(Duration.zero), '0m');
    expect(formatDuration(const Duration(seconds: 20)), '<1m');
    expect(formatDuration(const Duration(minutes: 45)), '45m');
    expect(formatDuration(const Duration(hours: 2)), '2h');
    expect(formatDuration(const Duration(minutes: 134)), '2h 14m');
  });

  testWidgets('Android: measured usage shows on Home and Insights', (
    tester,
  ) async {
    await pumpApp(
      tester,
      FakeNative('Android', {'usageReporting': 'supportedWithLimitations'}),
    );
    expect(find.text('Screen time today'), findsOneWidget);
    expect(find.text('30m'), findsOneWidget);
    expect(find.text('Vidstream'), findsOneWidget);

    await openTab(tester, 'Insights');
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('1h 30m'), findsOneWidget); // six days ago
  });

  testWidgets('usage is never fetched or shown without the capability', (
    tester,
  ) async {
    final native = await pumpApp(
      tester,
      FakeNative('Android', {'usageReporting': 'requiresAuthorization'}),
    );
    expect(native.usageFetches, 0);
    expect(find.text('Screen time today'), findsNothing);
    expect(find.text('Screen time isn\'t available yet'), findsOneWidget);
  });

  testWidgets('Android: add an app, set a budget, budget reaches native', (
    tester,
  ) async {
    final native = await pumpApp(
      tester,
      FakeNative('Android', {
        'usageReporting': 'supported',
        'appSelection': 'supported',
        'reminders': 'supportedWithLimitations',
      }),
    );
    await openTab(tester, 'Apps');
    await tester.tap(find.text('Add apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vidstream'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('22m today · No budget'), findsOneWidget);
    await tester.tap(find.text('Vidstream'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('This is a reminder, not a block'),
      findsOneWidget,
    );
    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();

    final synced = native.budgetSyncs.last;
    expect(synced['com.example.video']?.dailyLimitMinutes, 30);
    expect(find.text('22m today · Reminder at 30 min'), findsOneWidget);
  });

  testWidgets('Android: no budget chips when reminders are not usable', (
    tester,
  ) async {
    await pumpApp(
      tester,
      FakeNative('Android', {
        'appSelection': 'supported',
        'reminders': 'requiresAuthorization',
      }),
    );
    await openTab(tester, 'Apps');
    await tester.tap(find.text('Add apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chatter'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chatter'));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Reason for reminders.'), findsOneWidget);
  });

  testWidgets('iOS: pick apps, then the restrict switch appears and works', (
    tester,
  ) async {
    final native = await pumpApp(
      tester,
      FakeNative('iOS', {
        'appSelection': 'experimental',
        'appBlocking': 'experimental',
      }),
    );
    await openTab(tester, 'Apps');
    expect(find.text('Nothing chosen yet'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);

    await tester.tap(find.text('Choose apps'));
    await tester.pumpAndSettle();
    expect(find.text('2 app(s), 1 category(ies)'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(native.selection.shieldActive, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('iOS: no restrict switch when blocking is not authorized', (
    tester,
  ) async {
    final native = FakeNative('iOS', {
      'appSelection': 'experimental',
      'appBlocking': 'requiresAuthorization',
    })..selection = const TokenSelectionSummary(apps: 3);
    await pumpApp(tester, native);
    await openTab(tester, 'Apps');
    expect(find.text('3 app(s)'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });
}
