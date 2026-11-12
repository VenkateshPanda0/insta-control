import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/providers.dart';
import '../core/design_system/tokens.dart';
import '../core/design_system/widgets.dart';
import '../core/permissions/permission_service.dart';
import '../core/platform_capabilities/capability.dart';

/// Lists the permissions this device actually reports, with live status.
class PermissionList extends ConsumerWidget {
  const PermissionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(platformReportProvider);
    final permissions = report.value?.permissions ?? const {};
    if (report.isLoading && permissions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(Space.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (permissions.isEmpty) {
      return EmptyState(
        icon: Icons.info_outline,
        title: 'No permissions to review',
        message:
            report.value?.error ??
            'This device did not report any permissions Unscroll can use.',
      );
    }
    return Column(
      children: [
        for (final entry in permissions.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: _PermissionCard(entry.key, entry.value),
          ),
      ],
    );
  }
}

class _PermissionCard extends ConsumerWidget {
  const _PermissionCard(this.permission, this.state);
  final AppPermission permission;
  final PermissionState state;

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(platformReportProvider.notifier)
        .requestPermission(permission);
    final message =
        result.message ??
        switch (result.outcome) {
          PermissionRequestOutcome.failed => 'The request could not be made.',
          PermissionRequestOutcome.denied =>
            'Not allowed. You can change this in system settings.',
          _ => null,
        };
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final granted = state == PermissionState.granted;
    return UCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  permission.title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              StatusPill(state.label, positive: granted),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            permission.explanation,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!granted && state != PermissionState.unavailable) ...[
            const SizedBox(height: Space.md),
            OutlinedButton(
              onPressed: () => _request(context, ref),
              child: Text('Allow ${permission.title.toLowerCase()}'),
            ),
          ],
          if (granted) ...[
            const SizedBox(height: Space.sm),
            Text(
              'You can turn this off at any time in system settings.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
