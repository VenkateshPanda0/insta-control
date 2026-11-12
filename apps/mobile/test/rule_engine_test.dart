import 'package:flutter_test/flutter_test.dart';
import 'package:unscroll/core/rule_engine/engine.dart';
import 'package:unscroll/core/rule_engine/rule.dart';

const remind = RuleEngine(EngineCapabilities(reminders: true));
const restrict = RuleEngine(
  EngineCapabilities(backgroundRestrict: true, reminders: true),
);
const nothing = RuleEngine(
  EngineCapabilities(unavailableReason: 'Needs an extension.'),
);

Rule usage(
  String id,
  int minutes, {
  int priority = 0,
  Map<String, String>? targets,
}) => Rule(
  id: id,
  targets: targets ?? {'ig': 'Instagram'},
  trigger: DailyUsageTrigger(minutes),
  priority: priority,
);

const bedtime = ScheduleTrigger(
  days: {1, 2, 3, 4, 5},
  startMinute: 23 * 60,
  endMinute: 7 * 60,
);
final thursday = DateTime(2026, 11, 12, 10); // a Thursday

void main() {
  group('wording matches what really happens', () {
    test('reminder-only devices never say "restricted"', () {
      final text = remind.describe(usage('a', 20));
      expect(text, contains('reminder after 20 minutes of Instagram'));
      expect(text, contains('stays usable'));
      expect(text, isNot(contains('restricted')));
    });

    test('restrict wording only when the device can restrict', () {
      expect(
        restrict.describe(usage('a', 20)),
        'Instagram will be restricted after 20 minutes of use each day on this device.',
      );
    });

    test('a rule that cannot run says so and why', () {
      final text = nothing.describe(usage('a', 20));
      expect(text, contains('can\'t run on this device yet'));
      expect(text, contains('Needs an extension.'));
    });

    test('iOS token rules cannot be reminders', () {
      const rule = Rule(
        id: 'i',
        targets: {},
        usesSystemSelection: true,
        trigger: DailyUsageTrigger(20),
      );
      expect(remind.actionFor(rule), EffectiveAction.none);
      expect(restrict.actionFor(rule), EffectiveAction.restrict);
    });

    test('schedule and day wording', () {
      final text = remind.describe(
        const Rule(
          id: 's',
          targets: {'ig': 'Instagram', 'yt': 'YouTube'},
          trigger: bedtime,
        ),
      );
      expect(
        text,
        contains('Instagram or YouTube between 23:00 and 07:00 on weekdays'),
      );
      expect(RuleEngine.daysText({1, 2, 3, 4, 5, 6, 7}), 'every day');
      expect(RuleEngine.daysText({6, 7}), 'on weekends');
      expect(RuleEngine.daysText({1, 3}), 'on Mon, Wed');
    });
  });

  group('conflict resolution', () {
    test('higher priority wins, then the stricter limit', () {
      final rules = [
        usage('loose', 60),
        usage('strict', 20),
        usage('vip', 45, priority: 1),
      ];
      expect(
        remind.compile(rules, thursday).today.budgets['ig']!.ruleId,
        'vip',
      );
      expect(
        remind
            .compile(rules.take(2).toList(), thursday)
            .today
            .budgets['ig']!
            .minutes,
        20,
      );
      expect(remind.overridden(rules, thursday), {
        'loose': 'vip',
        'strict': 'vip',
      });
    });

    test('rules on different apps do not conflict', () {
      final plan = remind.compile([
        usage('a', 20),
        usage('b', 30, targets: {'yt': 'YouTube'}),
      ], thursday);
      expect(plan.today.budgets.keys, {'ig', 'yt'});
      expect(remind.overridden([usage('a', 20)], thursday), isEmpty);
    });

    test('disabled rules and rules the device cannot run are left out', () {
      expect(
        remind
            .compile([usage('a', 20).copyWith(enabled: false)], thursday)
            .today
            .budgets,
        isEmpty,
      );
      expect(
        nothing.compile([usage('a', 20)], thursday).today.budgets,
        isEmpty,
      );
    });
  });

  group('temporary exceptions', () {
    test('pause and extension apply today only; base plan ignores them', () {
      final paused = usage('a', 20).copyWith(pausedDay: () => dayKey(thursday));
      final extended = usage(
        'b',
        20,
        targets: {'yt': 'YouTube'},
      ).copyWith(extensionDay: dayKey(thursday), extensionMinutes: 5);
      final plan = remind.compile([paused, extended], thursday);
      expect(plan.day, '2026-11-12');
      expect(plan.today.budgets.containsKey('ig'), isFalse);
      expect(plan.today.budgets['yt']!.minutes, 25);
      expect(plan.base.budgets['ig']!.minutes, 20);
      expect(plan.base.budgets['yt']!.minutes, 20);

      final friday = thursday.add(const Duration(days: 1));
      expect(RuleEngine.isPaused(paused, friday), isFalse);
      expect(RuleEngine.effectiveMinutes(extended, friday), 20);
    });

    test('pausing the winner lets the next rule apply', () {
      final rules = [
        usage('strict', 20).copyWith(pausedDay: () => dayKey(thursday)),
        usage('loose', 60),
      ];
      expect(
        remind.compile(rules, thursday).today.budgets['ig']!.ruleId,
        'loose',
      );
    });
  });

  group('schedule windows', () {
    test('same-day window', () {
      const t = ScheduleTrigger(
        days: {4},
        startMinute: 9 * 60,
        endMinute: 17 * 60,
      );
      expect(
        RuleEngine.activeWindowStart(t, thursday),
        DateTime(2026, 11, 12, 9),
      );
      expect(
        RuleEngine.activeWindowStart(t, DateTime(2026, 11, 12, 17)),
        isNull,
      );
      expect(
        RuleEngine.activeWindowStart(t, DateTime(2026, 11, 13, 10)),
        isNull,
      );
    });

    test('overnight window belongs to the day it starts', () {
      // Friday 23:30 is inside Friday's window.
      expect(
        RuleEngine.activeWindowStart(bedtime, DateTime(2026, 11, 13, 23, 30)),
        DateTime(2026, 11, 13, 23),
      );
      // Saturday 02:00 is still Friday's window.
      expect(
        RuleEngine.activeWindowStart(bedtime, DateTime(2026, 11, 14, 2)),
        DateTime(2026, 11, 13, 23),
      );
      // Saturday 23:30: Saturday is not a selected day.
      expect(
        RuleEngine.activeWindowStart(bedtime, DateTime(2026, 11, 14, 23, 30)),
        isNull,
      );
      // Monday 02:00 would be Sunday's window, which is not selected.
      expect(
        RuleEngine.activeWindowStart(bedtime, DateTime(2026, 11, 16, 2)),
        isNull,
      );
    });

    test('windows are compiled for the native layer', () {
      final plan = remind.compile([
        const Rule(id: 's', targets: {'ig': 'Instagram'}, trigger: bedtime),
      ], thursday);
      expect(plan.today.toMap()['windows'], [
        {
          'id': 's',
          'apps': {'ig': 'Instagram'},
          'days': [1, 2, 3, 4, 5],
          'start': 1380,
          'end': 420,
        },
      ]);
    });
  });

  test('rules survive JSON and malformed rules are dropped', () {
    final rule = usage('a', 20, priority: 1).copyWith(
      pausedDay: () => '2026-11-12',
      extensionDay: '2026-11-12',
      extensionMinutes: 5,
    );
    final back = Rule.fromJson(rule.toJson())!;
    expect(back.priority, 1);
    expect(back.pausedDay, '2026-11-12');
    expect(back.extensionMinutes, 5);
    expect((back.trigger as DailyUsageTrigger).minutes, 20);
    expect(
      Rule.fromJson(
        const Rule(id: 's', targets: {'a': 'A'}, trigger: bedtime).toJson(),
      ),
      isNotNull,
    );

    expect(
      Rule.fromJson({
        'id': 'x',
        'targets': {},
        'trigger': {'type': 'dailyUsage', 'minutes': 5},
      }),
      isNull,
    );
    expect(
      Rule.fromJson({
        'id': 'x',
        'targets': {'a': 'A'},
        'trigger': {'type': 'dailyUsage', 'minutes': 0},
      }),
      isNull,
    );
    expect(
      Rule.fromJson({
        'id': 'x',
        'targets': {'a': 'A'},
        'trigger': {
          'type': 'schedule',
          'days': [9],
          'start': 0,
          'end': 5,
        },
      }),
      isNull,
    );
    expect(Rule.fromJson('nope'), isNull);
  });
}
