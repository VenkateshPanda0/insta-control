import 'package:material_ui/material_ui.dart';

import '../core/design_system/tokens.dart';
import '../core/usage/usage_models.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Seven-day bar chart of measured screen time.
class WeekChart extends StatelessWidget {
  const WeekChart(this.days, {super.key});
  final List<DayUsage> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMs = days.fold<int>(
      1,
      (m, d) => d.total.inMilliseconds > m ? d.total.inMilliseconds : m,
    );
    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, d) in days.indexed)
            Expanded(
              child: Semantics(
                label:
                    '${_weekdays[d.day.weekday - 1]}, ${formatDuration(d.total)}',
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        formatDuration(d.total),
                        style: theme.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: Space.xs),
                      Container(
                        height: 4 + 116 * d.total.inMilliseconds / maxMs,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: i == days.length - 1
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.35,
                                ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        _weekdays[d.day.weekday - 1],
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One app with its measured time and a proportional bar.
class AppUsageRow extends StatelessWidget {
  const AppUsageRow(this.app, {super.key, required this.max});
  final AppUsage app;
  final Duration max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = max.inMilliseconds == 0
        ? 0.0
        : app.duration.inMilliseconds / max.inMilliseconds;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  app.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatDuration(app.duration),
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
        ],
      ),
    );
  }
}
