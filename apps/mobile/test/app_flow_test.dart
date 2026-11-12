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
import 'package:unscroll/core/storage/app_settings.dart';

/// Fake native layer. These tests check UI behaviour against a scripted
/// report; they say nothing about real operating-system enforcement.
class FakePlatform implements PlatformCapabilityService, PermissionService {
  var usageAccess = 'denied';
  final requested = <AppPermission>[];

  @override
  Future<PlatformReport> fetchReport() async => PlatformReport.fromMap({
    'platform': 'Android',
    'osVersion': 'test',
    'permissions': {'usageAccess': usageAccess},
    'capabilities': {
      'inAppSectionControl': {
        'status': 'unavailable',
        'source': 'thirdPartyApp',
        'reason': 'Other apps do not allow this.',
      },
    },
  });

  @override
  Future<PermissionRequestResult> request(AppPermission permission) async {
    requested.add(permission);
    usageAccess = 'granted';
    return const PermissionRequestResult(
      PermissionRequestOutcome.openedSettings,
    );
  }
}

class NoRestrictions implements RestrictionService {
  const NoRestrictions();
  @override
  Future<TokenSelectionSummary?> setShieldActive(bool active) async => null;
  @override
  Future<void> syncBudgets(Map<String, ManagedApp> apps) async {}
}

Future<(SharedPreferences, FakePlatform)> pumpApp(
  WidgetTester tester, {
  Map<String, Object> initial = const {},
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final platform = FakePlatform();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(PrefsSettingsStore(prefs)),
        capabilityServiceProvider.overrideWithValue(platform),
        permissionServiceProvider.overrideWithValue(platform),
        restrictionServiceProvider.overrideWithValue(const NoRestrictions()),
      ],
      child: const UnscrollApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (prefs, platform);
}

const _onboarded = {'settings.v1': '{"onboardingComplete":true}'};

Future<void> tapNext(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onboarding saves choices and opens Home', (tester) async {
    final (prefs, platform) = await pumpApp(tester);
    expect(
      find.text('Use what matters. Block what distracts.'),
      findsOneWidget,
    );

    await tapNext(tester, 'Get started');
    await tester.tap(find.text('Better sleep'));
    await tapNext(tester, 'Continue');
    await tester.tap(find.text('Instagram'));
    await tapNext(tester, 'Continue');

    // Permission page reflects the device report and updates after a request.
    expect(find.text('Not allowed'), findsOneWidget);
    await tester.tap(find.text('Allow usage access'));
    await tester.pumpAndSettle();
    expect(platform.requested, [AppPermission.usageAccess]);
    expect(find.text('Allowed'), findsOneWidget);

    await tapNext(tester, 'Continue');
    await tester.tap(find.text('Strict'));
    await tapNext(tester, 'Continue');
    await tapNext(tester, 'Open Unscroll');

    expect(find.text('Screen time isn\'t available yet'), findsOneWidget);
    expect(find.text('Better sleep'), findsOneWidget);

    final saved = PrefsSettingsStore(prefs).load();
    expect(saved.onboardingComplete, isTrue);
    expect(saved.goals, {'better_sleep'});
    expect(saved.managedPresets, {'instagram'});
    expect(saved.frictionMode, FrictionMode.strict);
  });

  testWidgets('returning users skip onboarding; all five tabs open', (
    tester,
  ) async {
    await pumpApp(tester, initial: _onboarded);
    expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);
    for (final tab in ['Apps', 'Focus', 'Insights', 'Settings', 'Home']) {
      await tester.tap(find.widgetWithText(NavigationDestination, tab));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, tab), findsOneWidget);
    }
  });

  testWidgets('unavailable features explain themselves and show no switch', (
    tester,
  ) async {
    await pumpApp(tester, initial: _onboarded);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    final entry = find.text('Device capabilities');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    final reason = find.text('Other apps do not allow this.');
    await tester.scrollUntilVisible(
      reason,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(reason, findsOneWidget);
    expect(find.text('Third-party app limitation'), findsOneWidget);
    expect(find.byType(Switch, skipOffstage: false), findsNothing);
  });

  testWidgets('deleting data clears storage and returns to onboarding', (
    tester,
  ) async {
    final (prefs, _) = await pumpApp(tester, initial: _onboarded);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    final delete = find.text('Delete all Unscroll data');
    await tester.scrollUntilVisible(delete, 200);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete data'));
    await tester.pumpAndSettle();

    expect(
      find.text('Use what matters. Block what distracts.'),
      findsOneWidget,
    );
    expect(prefs.getKeys(), isEmpty);
  });
}
