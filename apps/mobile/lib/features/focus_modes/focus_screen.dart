import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';
import '../../core/focus/focus_models.dart';
import '../../core/platform_capabilities/capability.dart';
import '../../core/storage/app_settings.dart';
import '../../core/usage/usage_models.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Tick once a second only while a session is running.
  void _syncTicker(bool active) {
    if (active && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        ref.read(focusProvider.notifier).finishIfDue();
        if (mounted) setState(() {});
      });
    } else if (!active) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _end() async {
    final friction = ref.read(settingsProvider).frictionMode;
    if (friction != FrictionMode.gentle) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('End this session early?'),
          content: Text(
            friction == FrictionMode.strict
                ? 'You chose Strict mode. Take a breath first: is this what '
                      'you want right now?'
                : 'The session will be saved as ended early.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep going'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End session'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref.read(focusProvider.notifier).end();
  }

  Future<void> _newMode(bool canRestrict) async {
    final mode = await showDialog<FocusMode>(
      context: context,
      builder: (_) => _NewModeDialog(
        canRestrict: canRestrict,
        id: 'c${ref.read(clockProvider)().microsecondsSinceEpoch}',
      ),
    );
    if (mode != null) await ref.read(focusProvider.notifier).addMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(capabilityRegistryProvider);
    final capability = registry.of(FeatureId.focusSessions);
    final canRestrict = registry.of(FeatureId.appBlocking).isUsable;
    final focus = ref.watch(focusProvider);
    final session = focus.active;
    _syncTicker(session != null);
    final now = ref.read(clockProvider)();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (!capability.isUsable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Focus')),
        body: PageBody(
          children: [
            const SizedBox(height: Space.md),
            CapabilityNotice(capability),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: PageBody(
        children: [
          const SizedBox(height: Space.md),
          if (session != null)
            _ActiveCard(
              session: session,
              now: now,
              notify:
                  registry.permission(AppPermission.notifications) ==
                  PermissionState.granted,
              onEnd: _end,
            )
          else ...[
            UCard(
              child: Text(
                '${formatDuration(Duration(minutes: focusMinutesOn(focus.history, now)))} '
                'of focus today',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SectionHeader('Modes'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final mode in focus.modes)
                    ListTile(
                      title: Text(mode.name),
                      subtitle: Text(
                        [
                          formatDuration(Duration(minutes: mode.minutes)),
                          mode.summary,
                          if (mode.restrictApps && canRestrict)
                            'Restricts your chosen apps',
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!mode.builtIn)
                            IconButton(
                              tooltip: 'Delete ${mode.name}',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => ref
                                  .read(focusProvider.notifier)
                                  .removeMode(mode.id),
                            ),
                          FilledButton.tonal(
                            onPressed: () =>
                                ref.read(focusProvider.notifier).start(mode),
                            child: Text(
                              'Start',
                              semanticsLabel: 'Start ${mode.name}',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            OutlinedButton.icon(
              onPressed: () => _newMode(canRestrict),
              icon: const Icon(Icons.add),
              label: const Text('New mode'),
            ),
            const SizedBox(height: Space.sm),
            Text(capability.reason, style: muted),
          ],
          const SectionHeader('History'),
          if (focus.history.isEmpty)
            const EmptyState(
              icon: Icons.history,
              title: 'No sessions yet',
              message: 'Finished sessions appear here.',
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final r in focus.history.take(10))
                    ListTile(
                      leading: Icon(
                        r.completed
                            ? Icons.check_circle_outline
                            : Icons.timelapse,
                      ),
                      title: Text(r.modeName),
                      subtitle: Text(
                        r.completed
                            ? 'Completed · ${formatDuration(Duration(minutes: r.plannedMinutes))}'
                            : 'Ended early after ${formatDuration(Duration(minutes: r.actualMinutes))} '
                                  'of ${formatDuration(Duration(minutes: r.plannedMinutes))}',
                      ),
                      trailing: Text(
                        '${r.startedAt.day}/${r.startedAt.month}',
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.session,
    required this.now,
    required this.notify,
    required this.onEnd,
  });
  final ActiveSession session;
  final DateTime now;
  final bool notify;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = session.endsAt.difference(session.startedAt);
    final left = session.endsAt.difference(now);
    final remaining = left.isNegative ? Duration.zero : left;
    String two(int n) => n.toString().padLeft(2, '0');
    final clock = remaining.inHours > 0
        ? '${remaining.inHours}:${two(remaining.inMinutes % 60)}:${two(remaining.inSeconds % 60)}'
        : '${two(remaining.inMinutes)}:${two(remaining.inSeconds % 60)}';
    return UCard(
      child: Column(
        children: [
          Text(session.modeName, style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          Semantics(
            label: '${formatDuration(remaining)} remaining',
            child: ExcludeSemantics(
              child: Text(
                clock,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          LinearProgressIndicator(
            value: (1 - remaining.inSeconds / total.inSeconds).clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          const SizedBox(height: Space.md),
          Text(
            [
              if (session.restricting)
                'Your chosen apps are restricted. When time is up, open '
                    'Unscroll to lift the restriction.',
              if (notify) 'You\'ll get a notification when it ends.',
            ].join(' '),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.md),
          OutlinedButton(onPressed: onEnd, child: const Text('End session')),
        ],
      ),
    );
  }
}

class _NewModeDialog extends StatefulWidget {
  const _NewModeDialog({required this.canRestrict, required this.id});
  final bool canRestrict;
  final String id;

  @override
  State<_NewModeDialog> createState() => _NewModeDialogState();
}

class _NewModeDialogState extends State<_NewModeDialog> {
  String _name = '';
  int _minutes = 25;
  bool _restrict = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New mode'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (v) => setState(() => _name = v.trim()),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final m in const [15, 25, 45, 60, 90, 120])
                ChoiceChip(
                  label: Text('$m min'),
                  selected: _minutes == m,
                  onSelected: (_) => setState(() => _minutes = m),
                ),
            ],
          ),
          // Only offered where the device can really restrict apps.
          if (widget.canRestrict)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Restrict my chosen apps'),
              value: _restrict,
              onChanged: (v) => setState(() => _restrict = v),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _name.isEmpty
            ? null
            : () => Navigator.pop(
                context,
                FocusMode(
                  id: widget.id,
                  name: _name,
                  summary: 'Custom mode',
                  minutes: _minutes,
                  restrictApps: _restrict,
                ),
              ),
        child: const Text('Create'),
      ),
    ],
  );
}
