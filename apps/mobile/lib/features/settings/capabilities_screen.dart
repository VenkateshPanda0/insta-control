import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';

class CapabilitiesScreen extends ConsumerWidget {
  const CapabilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(capabilityRegistryProvider);
    final report = registry.report;
    final device = report.error ??
        '${report.platform} ${report.osVersion}'.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Device capabilities')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(platformReportProvider.notifier).refresh(),
        child: PageBody(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Text(
                'Reported by this device: $device',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            for (final c in registry.all)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: CapabilityNotice(c),
              ),
          ],
        ),
      ),
    );
  }
}
