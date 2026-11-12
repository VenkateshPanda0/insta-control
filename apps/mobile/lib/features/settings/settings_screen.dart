import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';
import '../../core/navigation/router.dart';
import '../../core/storage/app_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all Unscroll data?'),
        content: const Text(
          'This removes your goals, app list and preferences from this '
          'device and returns you to setup. System permissions are not '
          'changed; you can turn those off in system settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete data'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(settingsProvider.notifier).deleteAllData();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        children: [
          const SectionHeader('Appearance'),
          SegmentedButton<AppThemeMode>(
            segments: const [
              ButtonSegment(value: AppThemeMode.system, label: Text('System')),
              ButtonSegment(value: AppThemeMode.light, label: Text('Light')),
              ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) =>
                controller.update((v) => v.copyWith(themeMode: s.first)),
          ),
          const SectionHeader('Firmness'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: RadioGroup<FrictionMode>(
              groupValue: settings.frictionMode,
              onChanged: (m) => controller.update(
                (v) => v.copyWith(frictionMode: m ?? v.frictionMode),
              ),
              child: Column(
                children: [
                  for (final m in FrictionMode.values)
                    RadioListTile<FrictionMode>(
                      value: m,
                      title: Text(m.title),
                      subtitle: Text(m.summary),
                    ),
                ],
              ),
            ),
          ),
          const SectionHeader('Device'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Permissions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(Routes.permissions),
                ),
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: const Text('Device capabilities'),
                  subtitle: const Text('What works on this phone, and why'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(Routes.capabilities),
                ),
              ],
            ),
          ),
          const SectionHeader('Privacy'),
          const EmptyState(
            icon: Icons.lock_outline,
            title: 'Everything stays on this device',
            message:
                'No account, no ads, no analytics. Unscroll does not send '
                'your data anywhere.',
          ),
          const SizedBox(height: Space.md),
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete all Unscroll data'),
          ),
        ],
      ),
    );
  }
}
