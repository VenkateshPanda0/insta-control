/// Rule evaluation, conflict resolution, wording and compilation to the
/// plan the native layer runs in the background. Pure Dart.
library;

import 'rule.dart';

/// What the device can do for rules that must work while Unscroll is closed.
class EngineCapabilities {
  const EngineCapabilities({
    this.backgroundRestrict = false,
    this.reminders = false,
    this.unavailableReason = '',
  });
  final bool backgroundRestrict;
  final bool reminders;

  /// Shown when a rule cannot run at all.
  final String unavailableReason;
}

enum EffectiveAction { restrict, remind, none }

class BudgetInstruction {
  const BudgetInstruction(this.ruleId, this.label, this.minutes);
  final String ruleId;
  final String label;
  final int minutes;
}

class WindowInstruction {
  const WindowInstruction({
    required this.ruleId,
    required this.apps,
    required this.days,
    required this.startMinute,
    required this.endMinute,
  });
  final String ruleId;
  final Map<String, String> apps;
  final Set<int> days;
  final int startMinute;
  final int endMinute;
}

class PlanBody {
  const PlanBody(this.budgets, this.windows);

  /// Package name -> the single budget that applies to it.
  final Map<String, BudgetInstruction> budgets;
  final List<WindowInstruction> windows;

  Map<String, Object?> toMap() => {
    'budgets': {
      for (final e in budgets.entries)
        e.key: {'label': e.value.label, 'minutes': e.value.minutes},
    },
    'windows': [
      for (final w in windows)
        {
          'id': w.ruleId,
          'apps': w.apps,
          'days': w.days.toList()..sort(),
          'start': w.startMinute,
          'end': w.endMinute,
        },
    ],
  };
}

/// [today] includes that day's pauses and extensions and is only valid on
/// [day]; the native layer falls back to [base] on any other day, so
/// temporary exceptions expire even if Unscroll is not opened again.
class NativePlan {
  const NativePlan(this.day, this.today, this.base);
  final String day;
  final PlanBody today;
  final PlanBody base;

  Map<String, Object?> toMap() => {
    'day': day,
    'today': today.toMap(),
    'base': base.toMap(),
  };
}

class RuleEngine {
  const RuleEngine(this.capabilities);
  final EngineCapabilities capabilities;

  /// The strongest thing this device can really do for [rule].
  EffectiveAction actionFor(Rule rule) {
    if (capabilities.backgroundRestrict) return EffectiveAction.restrict;
    // Reminders are computed per app, which opaque iOS tokens do not allow.
    if (capabilities.reminders && !rule.usesSystemSelection) {
      return EffectiveAction.remind;
    }
    return EffectiveAction.none;
  }

  static bool isPaused(Rule rule, DateTime now) =>
      rule.pausedDay == dayKey(now);

  static int effectiveMinutes(Rule rule, DateTime now) {
    final trigger = rule.trigger;
    if (trigger is! DailyUsageTrigger) return 0;
    return trigger.minutes +
        (rule.extensionDay == dayKey(now) ? rule.extensionMinutes : 0);
  }

  /// Start of the window instance that contains [now], or null.
  static DateTime? activeWindowStart(ScheduleTrigger t, DateTime now) {
    final minute = now.hour * 60 + now.minute;
    final today = DateTime(now.year, now.month, now.day);
    DateTime at(DateTime day) => DateTime(
      day.year,
      day.month,
      day.day,
      t.startMinute ~/ 60,
      t.startMinute % 60,
    );
    if (t.startMinute < t.endMinute) {
      final inside = minute >= t.startMinute && minute < t.endMinute;
      return inside && t.days.contains(today.weekday) ? at(today) : null;
    }
    if (minute >= t.startMinute && t.days.contains(today.weekday)) {
      return at(today);
    }
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (minute < t.endMinute && t.days.contains(yesterday.weekday)) {
      return at(yesterday);
    }
    return null;
  }

  /// Conflict resolution for budgets: per app, the highest priority wins;
  /// on a tie the stricter (lower) limit wins; then the lower id, so the
  /// result is stable.
  PlanBody _body(List<Rule> rules, DateTime now, {required bool temporary}) {
    final budgets = <String, BudgetInstruction>{};
    final rank = <String, (int, int, String)>{};
    final windows = <WindowInstruction>[];
    for (final rule in rules) {
      if (!rule.enabled || actionFor(rule) == EffectiveAction.none) continue;
      if (temporary && isPaused(rule, now)) continue;
      final trigger = rule.trigger;
      switch (trigger) {
        case DailyUsageTrigger():
          final minutes = temporary
              ? effectiveMinutes(rule, now)
              : trigger.minutes;
          final mine = (-rule.priority, minutes, rule.id);
          rule.targets.forEach((package, label) {
            final current = rank[package];
            if (current == null || _less(mine, current)) {
              rank[package] = mine;
              budgets[package] = BudgetInstruction(rule.id, label, minutes);
            }
          });
        case ScheduleTrigger():
          windows.add(
            WindowInstruction(
              ruleId: rule.id,
              apps: rule.targets,
              days: trigger.days,
              startMinute: trigger.startMinute,
              endMinute: trigger.endMinute,
            ),
          );
      }
    }
    return PlanBody(budgets, windows);
  }

  static bool _less((int, int, String) a, (int, int, String) b) {
    if (a.$1 != b.$1) return a.$1 < b.$1;
    if (a.$2 != b.$2) return a.$2 < b.$2;
    return a.$3.compareTo(b.$3) < 0;
  }

  NativePlan compile(List<Rule> rules, DateTime now) => NativePlan(
    dayKey(now),
    _body(rules, now, temporary: true),
    _body(rules, now, temporary: false),
  );

  /// For each budget rule that loses on some app: rule id -> winning rule id.
  Map<String, String> overridden(List<Rule> rules, DateTime now) {
    final winners = _body(rules, now, temporary: true).budgets;
    final result = <String, String>{};
    for (final rule in rules) {
      if (rule.trigger is! DailyUsageTrigger || !rule.enabled) continue;
      if (isPaused(rule, now) || actionFor(rule) == EffectiveAction.none) {
        continue;
      }
      for (final package in rule.targets.keys) {
        final winner = winners[package]?.ruleId;
        if (winner != null && winner != rule.id) result[rule.id] = winner;
      }
    }
    return result;
  }

  // ---- Wording -----------------------------------------------------------

  static String targetText(Rule rule) {
    if (rule.usesSystemSelection) return 'your chosen apps';
    final names = rule.targets.values.toList()..sort();
    if (names.length <= 2) return names.join(' or ');
    return '${names.take(2).join(', ')} or ${names.length - 2} more';
  }

  static String clock(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  static String daysText(Set<int> days) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (days.length == 7) return 'every day';
    if (days.length == 5 && !days.contains(6) && !days.contains(7)) {
      return 'on weekdays';
    }
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return 'on weekends';
    }
    final sorted = days.toList()..sort();
    return 'on ${sorted.map((d) => names[d - 1]).join(', ')}';
  }

  static String triggerText(RuleTrigger trigger) => switch (trigger) {
    DailyUsageTrigger(:final minutes) => '$minutes min a day',
    ScheduleTrigger(:final days, :final startMinute, :final endMinute) =>
      '${clock(startMinute)}–${clock(endMinute)} ${daysText(days)}',
  };

  /// Plain-language preview. The wording always matches what will really
  /// happen: a rule that can only remind is never described as a block.
  String describe(Rule rule) {
    final target = targetText(rule);
    final action = actionFor(rule);
    final trigger = rule.trigger;
    final what = switch (trigger) {
      DailyUsageTrigger(:final minutes) => switch (action) {
        EffectiveAction.restrict =>
          '${_cap(target)} will be restricted after $minutes minutes of use each day on this device.',
        _ =>
          'You\'ll get a reminder after $minutes minutes of $target each day on this device. The app stays usable.',
      },
      ScheduleTrigger(:final days, :final startMinute, :final endMinute) =>
        switch (action) {
          EffectiveAction.restrict =>
            '${_cap(target)} will be restricted from ${clock(startMinute)} to ${clock(endMinute)} ${daysText(days)}.',
          _ =>
            'You\'ll get a reminder if you use $target between ${clock(startMinute)} and ${clock(endMinute)} ${daysText(days)}. The app stays usable.',
        },
    };
    if (action != EffectiveAction.none) return what;
    final summary = switch (trigger) {
      DailyUsageTrigger(:final minutes) => '$minutes minutes a day for $target',
      ScheduleTrigger(:final days, :final startMinute, :final endMinute) =>
        '${clock(startMinute)} to ${clock(endMinute)} ${daysText(days)} for $target',
    };
    return 'Saved ($summary), but it can\'t run on this device yet. '
            '${capabilities.unavailableReason}'
        .trim();
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
