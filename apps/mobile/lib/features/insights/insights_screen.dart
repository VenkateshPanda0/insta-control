import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';
import '../../core/platform_capabilities/capability.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(capabilityRegistryProvider).of(FeatureId.usageReporting);
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: PageBody(
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
          ],
        ],
      ),
    );
  }
}
