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
import '../rules/rule_builder_screen.dart';
import '../rules/rules_section.dart';

class AppsScreen extends ConsumerWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(capabilityRegistryProvider);
    final selection = registry.of(FeatureId.appSelection);
    final blocking = registry.of(FeatureId.appBlocking);
    final platform = registry.report.platform;

    return Scaffold(
      appBar: AppBar(title: const Text('Apps')),
      body: PageBody(
        children: [
          const SectionHeader('Your apps'),
          if (selection.isUsable && platform == 'Android')
            const _AndroidManagedApps()
          else if (selection.isUsable && platform == 'iOS')
            _IosSelection(blocking: blocking)
          else ...[
            const _PresetList(),
            const SizedBox(height: Space.sm),
            CapabilityNotice(selection),
          ],
          const SectionHeader('Rules'),
          const RulesSection(),
          const SectionHeader('What this device allows'),
          // On iOS the working control above already covers blocking.
          if (!blocking.isUsable) ...[
            CapabilityNotice(blocking),
            const SizedBox(height: Space.sm),
          ],
          CapabilityNotice(registry.of(FeatureId.inAppSectionControl)),
        ],
      ),
    );
  }
}

class _AndroidManagedApps extends ConsumerWidget {
  const _AndroidManagedApps();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managed = ref.watch(settingsProvider.select((s) => s.managedApps));
    final usage = ref.watch(usageReportProvider).value;
    final rules = ref.watch(rulesProvider);
    int ruleCount(String package) =>
        rules.where((r) => r.targets.containsKey(package)).length;
    final entries = managed.entries.toList()
      ..sort(
        (a, b) =>
            a.value.label.toLowerCase().compareTo(b.value.label.toLowerCase()),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entries.isEmpty)
          const EmptyState(
            icon: Icons.apps_outlined,
            title: 'No apps yet',
            message: 'Add the apps you want to keep an eye on.',
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final e in entries)
                  ListTile(
                    title: Text(e.value.label),
                    subtitle: Text(
                      [
                        if (usage != null)
                          '${formatDuration(usage.usageFor(e.key))} today',
                        switch (ruleCount(e.key)) {
                          0 => 'No rules',
                          1 => '1 rule',
                          final n => '$n rules',
                        },
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      isScrollControlled: true,
                      builder: (_) => _AppSheet(packageName: e.key),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: Space.sm),
        OutlinedButton.icon(
          onPressed: () => context.go(Routes.appPicker),
          icon: const Icon(Icons.add),
          label: const Text('Add apps'),
        ),
      ],
    );
  }
}

class _AppSheet extends ConsumerWidget {
  const _AppSheet({required this.packageName});
  final String packageName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(
      settingsProvider.select((s) => s.managedApps[packageName]),
    );
    if (app == null) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(app.label, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.md),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(context);
                context.go(
                  Routes.ruleBuilder,
                  extra: RuleBuilderArgs(presetPackage: packageName),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add a rule for this app'),
            ),
            const SizedBox(height: Space.sm),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(rulesProvider.notifier).removeTarget(packageName);
                ref
                    .read(settingsProvider.notifier)
                    .update(
                      (s) => s.copyWith(
                        managedApps: {...s.managedApps}..remove(packageName),
                      ),
                    );
              },
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Remove from my apps'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IosSelection extends ConsumerWidget {
  const _IosSelection({required this.blocking});
  final Capability blocking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(tokenSelectionProvider).value;
    final controller = ref.read(tokenSelectionProvider.notifier);
    final theme = Theme.of(context);
    final chosen = summary == null || summary.isEmpty
        ? 'Nothing chosen yet'
        : [
            if (summary.apps > 0) '${summary.apps} app(s)',
            if (summary.categories > 0) '${summary.categories} category(ies)',
            if (summary.webDomains > 0) '${summary.webDomains} website(s)',
          ].join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(chosen, style: theme.textTheme.titleMedium),
              const SizedBox(height: Space.xs),
              Text(
                'Apple keeps your choices private, so Unscroll can only show '
                'how many you picked, not their names.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Space.md),
              OutlinedButton(
                onPressed: controller.pick,
                child: const Text('Choose apps'),
              ),
            ],
          ),
        ),
        if (blocking.isUsable && summary != null && !summary.isEmpty) ...[
          const SizedBox(height: Space.sm),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              title: const Text('Restrict chosen apps now'),
              subtitle: Text(
                'Shows Apple\'s shield when you open them, until you turn '
                'this off. ${blocking.reason}',
              ),
              value: summary.shieldActive,
              onChanged: controller.setShieldActive,
            ),
          ),
        ],
      ],
    );
  }
}

class _PresetList extends ConsumerWidget {
  const _PresetList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managed = ref.watch(settingsProvider.select((s) => s.managedPresets));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final p in appPresets)
                CheckboxListTile(
                  secondary: Icon(p.icon),
                  title: Text(p.name),
                  value: managed.contains(p.id),
                  onChanged: (on) => ref
                      .read(settingsProvider.notifier)
                      .update(
                        (s) => s.copyWith(
                          managedPresets: on == true
                              ? {...s.managedPresets, p.id}
                              : ({...s.managedPresets}..remove(p.id)),
                        ),
                      ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          'This list is a saved preference. It does not restrict anything '
          'by itself.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
