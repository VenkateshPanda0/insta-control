import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unscroll/core/platform_capabilities/native_services.dart';
import 'package:unscroll/core/usage/usage_models.dart';

import 'support/fakes.dart';

Future<FakeNative> pumpApp(WidgetTester tester, FakeNative native) async {
  await pumpUnscroll(tester, native);
  return native;
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

  testWidgets('Android: add an app from the picker', (tester) async {
    await pumpApp(
      tester,
      FakeNative('Android', {
        'usageReporting': 'supported',
        'appSelection': 'supported',
      }),
    );
    await openTab(tester, 'Apps');
    await tester.tap(find.text('Add apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vidstream'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('22m today · No rules'), findsOneWidget);
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
