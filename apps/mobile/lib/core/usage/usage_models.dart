class AppUsage {
  const AppUsage(this.packageName, this.label, this.duration);
  final String packageName;
  final String label;
  final Duration duration;
}

class DayUsage {
  const DayUsage(this.day, this.total);
  final DateTime day;
  final Duration total;
}

/// Usage measured by the operating system. Never constructed from estimates.
class UsageReport {
  const UsageReport({required this.days, required this.todayApps});

  /// Oldest first; the last entry is today.
  final List<DayUsage> days;

  /// Most used first.
  final List<AppUsage> todayApps;

  Duration get today => days.isEmpty ? Duration.zero : days.last.total;

  Duration usageFor(String packageName) => todayApps
      .where((a) => a.packageName == packageName)
      .fold(Duration.zero, (sum, a) => sum + a.duration);

  factory UsageReport.fromMap(Map<Object?, Object?> map) {
    final days = <DayUsage>[];
    final apps = <AppUsage>[];
    final rawDays = map['days'];
    if (rawDays is List) {
      for (final d in rawDays) {
        if (d is! Map) continue;
        final start = d['start'], total = d['totalMs'];
        if (start is int && total is int && total >= 0) {
          days.add(
            DayUsage(
              DateTime.fromMillisecondsSinceEpoch(start),
              Duration(milliseconds: total),
            ),
          );
        }
      }
    }
    final rawApps = map['todayApps'];
    if (rawApps is List) {
      for (final a in rawApps) {
        if (a is! Map) continue;
        final package = a['package'], label = a['label'], ms = a['ms'];
        if (package is String && label is String && ms is int && ms > 0) {
          apps.add(AppUsage(package, label, Duration(milliseconds: ms)));
        }
      }
    }
    return UsageReport(days: days, todayApps: apps);
  }
}

String formatDuration(Duration d) {
  if (d.inSeconds < 60) return d == Duration.zero ? '0m' : '<1m';
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
