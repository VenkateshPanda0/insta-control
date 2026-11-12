/// Rule model. Pure Dart: no Flutter or platform imports.
library;

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

sealed class RuleTrigger {
  const RuleTrigger();
  Map<String, Object?> toJson();

  static RuleTrigger? fromJson(Object? json) {
    if (json is! Map) return null;
    switch (json['type']) {
      case 'dailyUsage':
        final m = json['minutes'];
        return m is int && m > 0 ? DailyUsageTrigger(m) : null;
      case 'schedule':
        final days = json['days'], start = json['start'], end = json['end'];
        if (days is! List || start is! int || end is! int) return null;
        final set = days
            .whereType<int>()
            .where((d) => d >= 1 && d <= 7)
            .toSet();
        if (set.isEmpty ||
            start < 0 ||
            start >= 1440 ||
            end < 0 ||
            end >= 1440) {
          return null;
        }
        return ScheduleTrigger(days: set, startMinute: start, endMinute: end);
    }
    return null;
  }
}

/// Fires once the target has been used this many minutes today.
class DailyUsageTrigger extends RuleTrigger {
  const DailyUsageTrigger(this.minutes);
  final int minutes;

  @override
  Map<String, Object?> toJson() => {'type': 'dailyUsage', 'minutes': minutes};
}

/// Applies during a repeating time window. [days] uses 1 = Monday … 7 =
/// Sunday and refers to the day the window starts. A window whose end is not
/// after its start runs past midnight into the next day.
class ScheduleTrigger extends RuleTrigger {
  const ScheduleTrigger({
    required this.days,
    required this.startMinute,
    required this.endMinute,
  });
  final Set<int> days;
  final int startMinute;
  final int endMinute;

  @override
  Map<String, Object?> toJson() => {
    'type': 'schedule',
    'days': days.toList()..sort(),
    'start': startMinute,
    'end': endMinute,
  };
}

class Rule {
  const Rule({
    required this.id,
    required this.targets,
    required this.trigger,
    this.usesSystemSelection = false,
    this.priority = 0,
    this.enabled = true,
    this.pausedDay,
    this.extensionDay,
    this.extensionMinutes = 0,
  });

  final String id;

  /// Android: package name -> display name.
  final Map<String, String> targets;

  /// iOS: the rule targets the apps chosen in Apple's picker (opaque tokens).
  final bool usesSystemSelection;
  final RuleTrigger trigger;

  /// Higher wins when two rules cover the same app.
  final int priority;
  final bool enabled;

  /// Temporary exception: the rule is skipped on this day only.
  final String? pausedDay;

  /// Temporary exception: extra minutes granted on this day only.
  final String? extensionDay;
  final int extensionMinutes;

  Rule copyWith({
    Map<String, String>? targets,
    RuleTrigger? trigger,
    int? priority,
    bool? enabled,
    String? Function()? pausedDay,
    String? extensionDay,
    int? extensionMinutes,
  }) => Rule(
    id: id,
    targets: targets ?? this.targets,
    usesSystemSelection: usesSystemSelection,
    trigger: trigger ?? this.trigger,
    priority: priority ?? this.priority,
    enabled: enabled ?? this.enabled,
    pausedDay: pausedDay == null ? this.pausedDay : pausedDay(),
    extensionDay: extensionDay ?? this.extensionDay,
    extensionMinutes: extensionMinutes ?? this.extensionMinutes,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'targets': targets,
    'usesSystemSelection': usesSystemSelection,
    'trigger': trigger.toJson(),
    'priority': priority,
    'enabled': enabled,
    'pausedDay': ?pausedDay,
    'extensionDay': ?extensionDay,
    'extensionMinutes': extensionMinutes,
  };

  static Rule? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final trigger = RuleTrigger.fromJson(json['trigger']);
    if (id is! String || trigger == null) return null;
    final targets = <String, String>{};
    final raw = json['targets'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String && v is String) targets[k] = v;
      });
    }
    final system = json['usesSystemSelection'] == true;
    if (targets.isEmpty && !system) return null;
    final ext = json['extensionMinutes'];
    return Rule(
      id: id,
      targets: targets,
      usesSystemSelection: system,
      trigger: trigger,
      priority: json['priority'] is int ? json['priority'] as int : 0,
      enabled: json['enabled'] != false,
      pausedDay: json['pausedDay'] is String
          ? json['pausedDay'] as String
          : null,
      extensionDay: json['extensionDay'] is String
          ? json['extensionDay'] as String
          : null,
      extensionMinutes: ext is int && ext > 0 ? ext : 0,
    );
  }
}
