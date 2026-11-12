import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';
import '../../core/goals/goals.dart';
import '../../core/platform_capabilities/capability.dart';
import '../../core/usage/usage_models.dart';

class GoalCard extends ConsumerWidget {
  const GoalCard(this.goal, {super.key, this.removable = false});
  final Goal goal;
  final bool removable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(goalProgressProvider(goal));
    final showStreaks = ref.watch(
      settingsProvider.select((s) => s.showStreaks),
    );
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final today = formatDuration(Duration(minutes: progress.todayMinutes));
    final target = formatDuration(Duration(minutes: goal.minutes));
    return UCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(goal.title, style: theme.textTheme.titleMedium),
              ),
              if (removable)
                IconButton(
                  tooltip: 'Remove goal',
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      ref.read(goalsProvider.notifier).remove(goal.id),
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          if (!progress.measurable)
            Text(
              'Can\'t be tracked yet: '
              '${ref.watch(capabilityRegistryProvider).of(FeatureId.usageReporting).reason}',
              style: muted,
            )
          else ...[
            LinearProgressIndicator(
              value: (progress.todayMinutes / goal.minutes).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            const SizedBox(height: Space.sm),
            Text(switch (goal.kind) {
              GoalKind.screenTimeUnder =>
                progress.metToday
                    ? '$today so far today, under your $target limit.'
                    : '$today today, over your $target limit. Tomorrow is a fresh start.',
              GoalKind.focusAtLeast =>
                progress.metToday
                    ? '$today today. Goal reached.'
                    : '$today of $target today.',
            }),
            if (progress.daysCounted > 0)
              Text(
                'Met on ${progress.daysMet} of the last ${progress.daysCounted} days.',
                style: muted,
              ),
            if (showStreaks && progress.streak >= 2)
              Text('${progress.streak} days in a row.', style: muted),
          ],
        ],
      ),
    );
  }
}

class GoalsSection extends ConsumerWidget {
  const GoalsSection({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final goal = await showModalBottomSheet<Goal>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _NewGoalSheet(
        id: 'g${ref.read(clockProvider)().microsecondsSinceEpoch}',
      ),
    );
    if (goal != null) await ref.read(goalsProvider.notifier).add(goal);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (goals.isEmpty)
          const EmptyState(
            icon: Icons.flag_outlined,
            title: 'No goals yet',
            message: 'Set a daily screen-time limit or a focus target.',
          ),
        for (final goal in goals)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: GoalCard(goal, removable: true),
          ),
        OutlinedButton.icon(
          onPressed: () => _add(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('New goal'),
        ),
      ],
    );
  }
}

class _NewGoalSheet extends StatefulWidget {
  const _NewGoalSheet({required this.id});
  final String id;

  @override
  State<_NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends State<_NewGoalSheet> {
  GoalKind _kind = GoalKind.screenTimeUnder;
  int _minutes = 120;

  @override
  Widget build(BuildContext context) {
    final options = _kind == GoalKind.screenTimeUnder
        ? const [60, 120, 180, 240, 300]
        : const [25, 50, 90, 120, 180];
    if (!options.contains(_minutes)) _minutes = options[1];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New goal', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.md),
            SegmentedButton<GoalKind>(
              segments: const [
                ButtonSegment(
                  value: GoalKind.screenTimeUnder,
                  label: Text('Less screen time'),
                ),
                ButtonSegment(
                  value: GoalKind.focusAtLeast,
                  label: Text('More focus'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final m in options)
                  ChoiceChip(
                    label: Text(formatDuration(Duration(minutes: m))),
                    selected: _minutes == m,
                    onSelected: (_) => setState(() => _minutes = m),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                Goal(id: widget.id, kind: _kind, minutes: _minutes),
              ),
              child: const Text('Add goal'),
            ),
          ],
        ),
      ),
    );
  }
}
