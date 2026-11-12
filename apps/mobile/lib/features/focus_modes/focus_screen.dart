import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';
import '../../core/platform_capabilities/capability.dart';
import '../../shared/catalog.dart';

class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(capabilityRegistryProvider).of(FeatureId.focusSessions);
    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: PageBody(
        children: [
          if (!focus.isUsable) ...[
            const SizedBox(height: Space.md),
            CapabilityNotice(focus),
          ],
          const SectionHeader('Planned modes'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final m in focusModePresets)
                  ListTile(
                    leading: Icon(m.icon),
                    title: Text(m.name),
                    subtitle: Text(m.summary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
