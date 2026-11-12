import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unscroll/core/platform_capabilities/capability.dart';
import 'package:unscroll/core/storage/app_settings.dart';

import 'package:unscroll/features/settings/capabilities_screen.dart';

import 'support/fakes.dart';

Future<void> tapNext(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

FakeNative basic() => FakeNative(
  'Android',
  {'inAppSectionControl': 'unavailable'},
  permissions: {'usageAccess': 'denied'},
);

void main() {
  testWidgets('onboarding saves choices and opens Home', (tester) async {
    final platform = basic();
    final prefs = await pumpUnscroll(tester, platform, initial: {});
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
    expect(platform.permissionRequests, [AppPermission.usageAccess]);
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
    await pumpUnscroll(tester, basic());
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
    await pumpUnscroll(tester, basic());
    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    final entry = find.text('Device capabilities');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    final reason = find.text('Reason for inAppSectionControl.');
    await tester.scrollUntilVisible(
      reason,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(reason, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CapabilitiesScreen),
        matching: find.byType(Switch, skipOffstage: false),
      ),
      findsNothing,
    );
  });

  testWidgets('deleting data clears storage and returns to onboarding', (
    tester,
  ) async {
    final prefs = await pumpUnscroll(tester, basic());
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
