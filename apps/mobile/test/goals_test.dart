import 'package:flutter_test/flutter_test.dart';
import 'package:unscroll/core/focus/focus_models.dart';
import 'package:unscroll/core/goals/goals.dart';
import 'package:unscroll/core/usage/usage_models.dart';

final now = DateTime(2026, 11, 12, 15);

UsageReport usage(List<int> minutes) => UsageReport(
  days: [
    for (final (i, m) in minutes.indexed)
      DayUsage(
        DateTime(2026, 11, 12 - (minutes.length - 1 - i)),
        Duration(minutes: m),
      ),
  ],
  todayApps: const [],
);

SessionRecord session(int daysAgo, int minutes) => SessionRecord(
  modeName: 'Study',
  startedAt: DateTime(2026, 11, 12 - daysAgo, 9),
  plannedMinutes: minutes,
  actualMinutes: minutes,
  completed: true,
);

void main() {
  const under = Goal(id: 'g', kind: GoalKind.screenTimeUnder, minutes: 120);
  const focus = Goal(id: 'f', kind: GoalKind.focusAtLeast, minutes: 50);

  test('screen-time goal is not measurable without usage data', () {
    final p = evaluateGoal(under, usage: null, history: const [], now: now);
    expect(p.measurable, isFalse);
  });

  test('screen-time goal: days met and streak end yesterday', () {
    // oldest … yesterday, today
    final p = evaluateGoal(
      under,
      usage: usage([200, 90, 130, 100, 110, 60, 45]),
      history: const [],
      now: now,
    );
    expect(p.todayMinutes, 45);
    expect(p.metToday, isTrue);
    expect(p.daysMet, 4);
    expect(p.daysCounted, 6);
    expect(p.streak, 3); // today is not counted until the day is over
  });

  test('going over today does not erase a streak built on past days', () {
    final p = evaluateGoal(
      under,
      usage: usage([60, 60, 300]),
      history: const [],
      now: now,
    );
    expect(p.metToday, isFalse);
    expect(p.streak, 2);
  });

  test(
    'focus goal counts session minutes per day, including today once met',
    () {
      final p = evaluateGoal(
        focus,
        usage: null,
        history: [
          session(0, 25),
          session(0, 25),
          session(1, 50),
          session(2, 10),
          session(3, 90),
        ],
        now: now,
      );
      expect(p.measurable, isTrue);
      expect(p.todayMinutes, 50);
      expect(p.metToday, isTrue);
      expect(p.daysMet, 2);
      expect(p.streak, 2); // yesterday + today; two days ago missed
    },
  );

  test('goal JSON round trip and rejection', () {
    expect(Goal.fromJson(under.toJson())!.minutes, 120);
    expect(Goal.fromJson({'id': 'x', 'kind': 'nope', 'minutes': 5}), isNull);
    expect(
      Goal.fromJson({'id': 'x', 'kind': 'focusAtLeast', 'minutes': 0}),
      isNull,
    );
  });
}
