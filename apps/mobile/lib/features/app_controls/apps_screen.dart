import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';
import '../../core/platform_capabilities/capability.dart';
import '../../shared/catalog.dart';

class AppsScreen extends ConsumerWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managed = ref.watch(settingsProvider.select((s) => s.managedPresets));
    final registry = ref.watch(capabilityRegistryProvider);
    final controls = [
      registry.of(FeatureId.appSelection),
      registry.of(FeatureId.appBlocking),
      registry.of(FeatureId.inAppSectionControl),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Apps')),
      body: PageBody(
        children: [
          const SectionHeader('Your list'),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SectionHeader('Controls on this device'),
          for (final c in controls)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: CapabilityNotice(c),
            ),
        ],
      ),
    );
  }
}
