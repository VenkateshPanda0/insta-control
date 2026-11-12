import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';
import '../../core/platform_capabilities/capability.dart';
import '../../shared/usage_widgets.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref
        .watch(capabilityRegistryProvider)
        .of(FeatureId.usageReporting);
    final report = ref.watch(usageReportProvider);
    final data = report.value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(usageReportProvider.future),
        child: PageBody(
          children: [
            const SizedBox(height: Space.md),
            if (!usage.isUsable) ...[
              const EmptyState(
                icon: Icons.insights_outlined,
                title: 'No insights yet',
                message:
                    'Trends appear here once Unscroll can read usage measured '
                    'by your device. Unscroll never shows estimated or sample '
                    'numbers as real usage.',
              ),
              const SizedBox(height: Space.sm),
              CapabilityNotice(usage),
            ] else if (data == null)
              report.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : const EmptyState(
                      icon: Icons.error_outline,
                      title: 'Couldn\'t read usage',
                      message: 'Pull down to try again.',
                    )
            else ...[
              UCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last 7 days', style: theme.textTheme.titleMedium),
                    const SizedBox(height: Space.md),
                    WeekChart(data.days),
                  ],
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(
                usage.reason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SectionHeader('Today by app'),
              if (data.todayApps.isEmpty)
                const EmptyState(
                  icon: Icons.hourglass_empty,
                  title: 'Nothing measured today',
                  message: 'Apps you use today will appear here.',
                )
              else
                UCard(
                  child: Column(
                    children: [
                      for (final app in data.todayApps.take(15))
                        AppUsageRow(app, max: data.todayApps.first.duration),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
