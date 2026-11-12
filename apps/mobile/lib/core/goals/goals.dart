import '../focus/focus_models.dart';
import '../usage/usage_models.dart';

enum GoalKind { screenTimeUnder, focusAtLeast }

class Goal {
  const Goal({required this.id, required this.kind, required this.minutes});
  final String id;
  final GoalKind kind;
  final int minutes;

  String get title => switch (kind) {
    GoalKind.screenTimeUnder =>
      'Screen time under ${formatDuration(Duration(minutes: minutes))} a day',
    GoalKind.focusAtLeast =>
      'Focus for ${formatDuration(Duration(minutes: minutes))} a day',
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'minutes': minutes,
  };

  static Goal? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], minutes = json['minutes'];
    final kind = GoalKind.values.asNameMap()[json['kind']];
    if (id is! String || kind == null || minutes is! int || minutes <= 0) {
      return null;
    }
    return Goal(id: id, kind: kind, minutes: minutes);
  }
}

class GoalProgress {
  const GoalProgress({
    required this.measurable,
    this.todayMinutes = 0,
    this.metToday = false,
    this.daysMet = 0,
    this.daysCounted = 0,
    this.streak = 0,
  });

  /// False when the device cannot supply the data this goal needs.
  final bool measurable;
  final int todayMinutes;

  /// For "under" goals this means "still under so far today".
  final bool metToday;

  /// Completed days (before today) in the last week that met the goal.
  final int daysMet;
  final int daysCounted;

  /// Consecutive completed days met, ending yesterday; today is added only
  /// once a "reach at least" goal has been reached.
  final int streak;
}

GoalProgress evaluateGoal(
  Goal goal, {
  required UsageReport? usage,
  required List<SessionRecord> history,
  required DateTime now,
}) {
  // Per-day minutes, oldest first, today last.
  final List<int> days;
  switch (goal.kind) {
    case GoalKind.screenTimeUnder:
      if (usage == null || usage.days.isEmpty) {
        return const GoalProgress(measurable: false);
      }
      days = [for (final d in usage.days) d.total.inMinutes];
    case GoalKind.focusAtLeast:
      days = [
        for (var i = 6; i >= 0; i--)
          focusMinutesOn(history, DateTime(now.year, now.month, now.day - i)),
      ];
  }
  bool met(int minutes) => switch (goal.kind) {
    GoalKind.screenTimeUnder => minutes < goal.minutes,
    GoalKind.focusAtLeast => minutes >= goal.minutes,
  };
  final past = days.sublist(0, days.length - 1);
  final metToday = met(days.last);
  var streak = 0;
  for (final m in past.reversed) {
    if (!met(m)) break;
    streak++;
  }
  if (goal.kind == GoalKind.focusAtLeast && metToday) streak++;
  return GoalProgress(
    measurable: true,
    todayMinutes: days.last,
    metToday: metToday,
    daysMet: past.where(met).length,
    daysCounted: past.length,
    streak: streak,
  );
}
