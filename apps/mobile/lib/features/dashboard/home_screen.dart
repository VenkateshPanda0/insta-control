import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';
import '../../core/navigation/router.dart';
import '../../core/platform_capabilities/capability.dart';
import '../../core/usage/usage_models.dart';
import '../../shared/catalog.dart';
import '../../shared/usage_widgets.dart';
import '../goals/goals_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final registry = ref.watch(capabilityRegistryProvider);
    final usage = registry.of(FeatureId.usageReporting);
    final report = ref.watch(usageReportProvider);
    final data = report.value;
    final tracked = ref.watch(goalsProvider);
    final session = ref.watch(focusProvider.select((f) => f.active));
    final theme = Theme.of(context);
    final goals = goalOptions.where((g) => settings.goals.contains(g.id));
    final apps = settings.managedApps.isNotEmpty
        ? [
            for (final a in settings.managedApps.values)
              AppPreset(a.label, a.label, Icons.apps_outlined),
          ]
        : appPresets
              .where((p) => settings.managedPresets.contains(p.id))
              .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: PageBody(
        children: [
          if (session != null) ...[
            const SizedBox(height: Space.md),
            UCard(
              onTap: () => context.go(Routes.focus),
              child: Row(
                children: [
                  Icon(Icons.timelapse, color: theme.colorScheme.primary),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      '${session.modeName} session in progress',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
          const SectionHeader('Today'),
          // No usage number is shown unless the device really measured it.
          if (!usage.isUsable)
            EmptyState(
              icon: Icons.hourglass_empty,
              title: 'Screen time isn\'t available yet',
              message: usage.reason.isEmpty
                  ? 'Unscroll will only show usage measured by your device.'
                  : usage.reason,
            )
          else if (data == null)
            report.isLoading
                ? const Center(child: CircularProgressIndicator())
                : const EmptyState(
                    icon: Icons.error_outline,
                    title: 'Couldn\'t read usage',
                    message: 'Open the app again to retry.',
                  )
          else
            UCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Screen time today',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatDuration(data.today),
                    style: theme.textTheme.displaySmall,
                  ),
                  if (data.todayApps.isNotEmpty)
                    const SizedBox(height: Space.sm),
                  for (final app in data.todayApps.take(3))
                    AppUsageRow(app, max: data.todayApps.first.duration),
                ],
              ),
            ),
          const SectionHeader('Your goals'),
          for (final goal in tracked.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: GoalCard(goal),
            ),
          if (tracked.isNotEmpty)
            const SizedBox.shrink()
          else if (goals.isEmpty)
            const EmptyState(
              icon: Icons.flag_outlined,
              title: 'No goals yet',
              message: 'Add a goal from the Insights tab.',
            )
          else
            UCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final g in goals)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.xs),
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(child: Text(g.title)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SectionHeader('Apps on your list'),
          if (apps.isEmpty)
            const EmptyState(
              icon: Icons.apps_outlined,
              title: 'No apps chosen',
              message: 'Add apps you want to manage from the Apps tab.',
            )
          else
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final p in apps)
                  Chip(avatar: Icon(p.icon, size: 18), label: Text(p.name)),
              ],
            ),
          const SectionHeader('This device'),
          UCard(
            onTap: () => context.go(Routes.capabilities),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${registry.all.where((c) => c.isUsable).length} of '
                    '${registry.all.length} features are usable on this '
                    'device right now. See why.',
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
