import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:unscroll/core/platform_capabilities/native_services.dart';

import 'support/fakes.dart';

const _withApp = <String, Object>{
  'settings.v1':
      '{"onboardingComplete":true,"frictionMode":"gentle",'
      '"managedApps":{"com.example.video":{"label":"Vidstream"}}}',
};

FakeNative android({bool reminders = true}) => FakeNative(
  'Android',
  {
    'usageReporting': 'supported',
    'appSelection': 'supported',
    'focusSessions': 'supportedWithLimitations',
    'reminders': reminders
        ? 'supportedWithLimitations'
        : 'requiresAuthorization',
  },
  permissions: {'notifications': 'granted'},
);

void main() {
  testWidgets('create a budget rule: preview, save, and it reaches native', (
    tester,
  ) async {
    final native = android();
    final prefs = await pumpUnscroll(tester, native, initial: _withApp);
    await openTab(tester, 'Apps');
    await scrollTap(tester, find.text('New rule'));

    expect(find.text('Choose at least one app.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Vidstream'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '30 min'));
    await tester.pumpAndSettle();
    const preview =
        'You\'ll get a reminder after 30 minutes of Vidstream each day on '
        'this device. The app stays usable.';
    expect(find.text(preview, skipOffstage: false), findsOneWidget);

    await scrollTap(tester, find.text('Save rule'));
    expect(find.text(preview, skipOffstage: false), findsOneWidget);
    expect(native.plans.last.today.budgets['com.example.video']!.minutes, 30);
    expect(jsonDecode(prefs.getString('rules.v1')!), hasLength(1));

    // Turning the rule off removes it from the native plan.
    await scrollTap(tester, find.byType(Switch));
    expect(native.plans.last.today.budgets, isEmpty);
  });

  testWidgets('a rule the device cannot run is saved without a switch', (
    tester,
  ) async {
    final native = android(reminders: false);
    await pumpUnscroll(tester, native, initial: _withApp);
    await openTab(tester, 'Apps');
    await scrollTap(tester, find.text('New rule'));
    await tester.tap(find.widgetWithText(FilterChip, 'Vidstream'));
    await tester.pumpAndSettle();
    await scrollTap(tester, find.text('Save rule'));

    expect(
      find.text('Can\'t run here yet', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('Reason for reminders.', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(Switch, skipOffstage: false), findsNothing);
    expect(native.plans.last.today.budgets, isEmpty);
  });

  testWidgets('pause for today is an exception that the plan honours', (
    tester,
  ) async {
    final native = android();
    await pumpUnscroll(
      tester,
      native,
      initial: {
        ..._withApp,
        'rules.v1':
            '[{"id":"r1","targets":{"com.example.video":"Vidstream"},'
            '"trigger":{"type":"dailyUsage","minutes":20}}]',
      },
      clock: TestClock(),
    );
    expect(native.plans.last.today.budgets, hasLength(1));
    await openTab(tester, 'Apps');
    await scrollTap(tester, find.textContaining('reminder after 20 minutes'));
    await scrollTap(tester, find.text('Pause for today'));

    expect(find.text('Paused today', skipOffstage: false), findsOneWidget);
    expect(native.plans.last.today.budgets, isEmpty);
    expect(native.plans.last.base.budgets, hasLength(1)); // back tomorrow
  });

  testWidgets('focus session: start, tick down, complete, history', (
    tester,
  ) async {
    final native = android();
    final clock = TestClock();
    await pumpUnscroll(tester, native, initial: _withApp, clock: clock);
    await openTab(tester, 'Focus');
    await tester.tap(
      find.widgetWithText(FilledButton, 'Start').first,
    ); // Study, 25 min
    await tester.pumpAndSettle();

    expect(find.text('25:00'), findsOneWidget);
    expect(
      find.text('You\'ll get a notification when it ends.'),
      findsOneWidget,
    );
    expect(
      native.sessionEnds.single,
      clock.now.add(const Duration(minutes: 25)),
    );

    clock.now = clock.now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('15:00'), findsOneWidget);

    clock.now = clock.now.add(const Duration(minutes: 15));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Completed · 25m'), findsOneWidget);
    expect(find.text('25m of focus today'), findsOneWidget);
    expect(native.sessionEndCancels, 0);
  });

  testWidgets(
    'ending early is recorded honestly and cancels the notification',
    (tester) async {
      final native = android();
      final clock = TestClock();
      await pumpUnscroll(tester, native, initial: _withApp, clock: clock);
      await openTab(tester, 'Focus');
      await tester.tap(find.widgetWithText(FilledButton, 'Start').first);
      await tester.pumpAndSettle();
      clock.now = clock.now.add(const Duration(minutes: 7));
      await tester.tap(find.text('End session'));
      await tester.pumpAndSettle();

      expect(find.text('Ended early after 7m of 25m'), findsOneWidget);
      expect(native.sessionEndCancels, 1);
    },
  );

  testWidgets('strict mode asks before ending early', (tester) async {
    await pumpUnscroll(
      tester,
      android(),
      initial: {
        'settings.v1': '{"onboardingComplete":true,"frictionMode":"strict"}',
      },
      clock: TestClock(),
    );
    await openTab(tester, 'Focus');
    await tester.tap(find.widgetWithText(FilledButton, 'Start').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You chose Strict mode'), findsOneWidget);
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'End session'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ended early'), findsOneWidget);
  });

  testWidgets(
    'iOS: a restricting session shields apps and lifts them at the end',
    (tester) async {
      final native = FakeNative('iOS', {
        'appSelection': 'experimental',
        'appBlocking': 'experimental',
        'focusSessions': 'supportedWithLimitations',
      })..selection = const TokenSelectionSummary(apps: 2);
      final clock = TestClock();
      await pumpUnscroll(tester, native, initial: _withApp, clock: clock);
      await openTab(tester, 'Focus');
      await tester.tap(find.widgetWithText(FilledButton, 'Start').first);
      await tester.pumpAndSettle();
      expect(native.selection.shieldActive, isTrue);
      expect(
        find.textContaining('open Unscroll to lift the restriction'),
        findsOneWidget,
      );

      await tester.tap(find.text('End session'));
      await tester.pumpAndSettle();
      expect(native.selection.shieldActive, isFalse);
    },
  );

  testWidgets('goals: add a focus goal and see measured progress', (
    tester,
  ) async {
    final clock = TestClock();
    await pumpUnscroll(tester, android(), initial: _withApp, clock: clock);
    await openTab(tester, 'Insights');
    await tester.tap(find.text('New goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More focus'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '25m'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add goal'));
    await tester.pumpAndSettle();
    expect(find.text('Focus for 25m a day'), findsOneWidget);
    expect(find.text('0m of 25m today.'), findsOneWidget);

    await openTab(tester, 'Focus');
    await tester.tap(find.widgetWithText(FilledButton, 'Start').first);
    await tester.pumpAndSettle();
    clock.now = clock.now.add(const Duration(minutes: 25));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await openTab(tester, 'Insights');
    expect(find.text('25m today. Goal reached.'), findsOneWidget);
  });

  testWidgets('screen-time goal says when it cannot be tracked', (
    tester,
  ) async {
    await pumpUnscroll(
      tester,
      FakeNative('iOS', {'usageReporting': 'unavailable'}),
      initial: {
        ...onboardedPrefs,
        'goals.v1': '[{"id":"g","kind":"screenTimeUnder","minutes":120}]',
      },
    );
    expect(
      find.text('Can\'t be tracked yet: Reason for usageReporting.'),
      findsOneWidget,
    );
  });

  testWidgets('deleting data ends a session and clears rules and goals', (
    tester,
  ) async {
    final native = android();
    final prefs = await pumpUnscroll(
      tester,
      native,
      initial: {
        ..._withApp,
        'rules.v1':
            '[{"id":"r1","targets":{"com.example.video":"Vidstream"},'
            '"trigger":{"type":"dailyUsage","minutes":20}}]',
      },
      clock: TestClock(),
    );
    await openTab(tester, 'Focus');
    await tester.tap(find.widgetWithText(FilledButton, 'Start').first);
    await tester.pumpAndSettle();
    await openTab(tester, 'Settings');
    await scrollTap(tester, find.text('Delete all Unscroll data'));
    await tester.tap(find.text('Delete data'));
    await tester.pumpAndSettle();

    expect(
      find.text('Use what matters. Block what distracts.'),
      findsOneWidget,
    );
    expect(prefs.getKeys(), isEmpty);
    expect(native.sessionEndCancels, greaterThan(0));
    expect(native.plans.last.today.budgets, isEmpty);
  });
}
