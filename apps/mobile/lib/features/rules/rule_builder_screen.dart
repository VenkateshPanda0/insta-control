import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';
import '../../core/rule_engine/engine.dart';
import '../../core/rule_engine/rule.dart';

class RuleBuilderArgs {
  const RuleBuilderArgs({this.rule, this.presetPackage});

  /// Rule to edit; null creates a new one.
  final Rule? rule;

  /// Pre-select this app as the target of a new rule.
  final String? presetPackage;
}

class RuleBuilderScreen extends ConsumerStatefulWidget {
  const RuleBuilderScreen({super.key, this.args});
  final RuleBuilderArgs? args;

  @override
  ConsumerState<RuleBuilderScreen> createState() => _RuleBuilderScreenState();
}

class _RuleBuilderScreenState extends ConsumerState<RuleBuilderScreen> {
  static const _minuteOptions = [10, 15, 20, 30, 45, 60, 90, 120];
  static const _dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayLabels = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late final Rule? _existing = widget.args?.rule;
  late final String _id =
      _existing?.id ?? 'r${ref.read(clockProvider)().microsecondsSinceEpoch}';
  final _targets = <String, String>{};
  bool _schedule = false;
  int _minutes = 20;
  var _days = <int>{1, 2, 3, 4, 5, 6, 7};
  int _start = 23 * 60;
  int _end = 7 * 60;
  int _priority = 0;

  @override
  void initState() {
    super.initState();
    final rule = _existing;
    if (rule != null) {
      _targets.addAll(rule.targets);
      _priority = rule.priority;
      switch (rule.trigger) {
        case DailyUsageTrigger(:final minutes):
          _minutes = minutes;
        case ScheduleTrigger(:final days, :final startMinute, :final endMinute):
          _schedule = true;
          _days = {...days};
          _start = startMinute;
          _end = endMinute;
      }
    } else {
      final preset = widget.args?.presetPackage;
      final app = ref.read(settingsProvider).managedApps[preset];
      if (preset != null && app != null) _targets[preset] = app.label;
    }
  }

  bool get _ios =>
      ref.read(capabilityRegistryProvider).report.platform == 'iOS';

  Rule _draft() {
    final trigger = _schedule
        ? ScheduleTrigger(days: _days, startMinute: _start, endMinute: _end)
        : DailyUsageTrigger(_minutes);
    final base = _existing;
    if (base != null) {
      return base.copyWith(
        targets: {..._targets},
        trigger: trigger,
        priority: _priority,
      );
    }
    return Rule(
      id: _id,
      targets: {..._targets},
      usesSystemSelection: _ios,
      trigger: trigger,
      priority: _priority,
    );
  }

  bool get _valid =>
      (_ios || _targets.isNotEmpty) && (!_schedule || _days.isNotEmpty);

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    setState(() {
      final value = picked.hour * 60 + picked.minute;
      start ? _start = value : _end = value;
    });
  }

  Future<void> _saveAndClose(Rule rule) async {
    final navigator = Navigator.of(context);
    await ref.read(rulesProvider.notifier).save(rule);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(ruleEngineProvider);
    final managed = ref.watch(settingsProvider.select((s) => s.managedApps));
    final now = ref.read(clockProvider)();
    final theme = Theme.of(context);
    final draft = _draft();
    final existing = _existing;
    final canRun = engine.actionFor(draft) != EffectiveAction.none;
    final apps =
        {
          ...managed.map((k, v) => MapEntry(k, v.label)),
          ..._targets,
        }.entries.toList()..sort(
          (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
        );

    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'New rule' : 'Edit rule')),
      body: PageBody(
        children: [
          if (existing == null) ...[
            const SectionHeader('Start from a template'),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                ActionChip(
                  label: const Text('20 min a day'),
                  onPressed: () => setState(() {
                    _schedule = false;
                    _minutes = 20;
                  }),
                ),
                ActionChip(
                  label: const Text('Bedtime 23:00–07:00'),
                  onPressed: () => setState(() {
                    _schedule = true;
                    _days = {1, 2, 3, 4, 5, 6, 7};
                    _start = 23 * 60;
                    _end = 7 * 60;
                  }),
                ),
                ActionChip(
                  label: const Text('Weekday work hours'),
                  onPressed: () => setState(() {
                    _schedule = true;
                    _days = {1, 2, 3, 4, 5};
                    _start = 9 * 60;
                    _end = 17 * 60;
                  }),
                ),
              ],
            ),
          ],
          const SectionHeader('Apps'),
          if (_ios)
            const EmptyState(
              icon: Icons.apps_outlined,
              title: 'Your chosen apps',
              message:
                  'On iPhone a rule covers the apps you chose in Apple\'s '
                  'picker on the Apps tab.',
            )
          else if (apps.isEmpty)
            const EmptyState(
              icon: Icons.apps_outlined,
              title: 'No apps to choose from',
              message: 'Add apps on the Apps tab first.',
            )
          else
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final app in apps)
                  FilterChip(
                    label: Text(app.value),
                    selected: _targets.containsKey(app.key),
                    onSelected: (on) => setState(
                      () => on
                          ? _targets[app.key] = app.value
                          : _targets.remove(app.key),
                    ),
                  ),
              ],
            ),
          const SectionHeader('When'),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Daily time used')),
              ButtonSegment(value: true, label: Text('Time of day')),
            ],
            selected: {_schedule},
            onSelectionChanged: (s) => setState(() => _schedule = s.first),
          ),
          const SizedBox(height: Space.md),
          if (!_schedule)
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final m in {..._minuteOptions, _minutes}.toList()..sort())
                  ChoiceChip(
                    label: Text('$m min'),
                    selected: _minutes == m,
                    onSelected: (_) => setState(() => _minutes = m),
                  ),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text('From ${RuleEngine.clock(_start)}'),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text('To ${RuleEngine.clock(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var d = 1; d <= 7; d++)
                  Semantics(
                    label: _dayLabels[d - 1],
                    child: FilterChip(
                      showCheckmark: false,
                      padding: EdgeInsets.zero,
                      label: ExcludeSemantics(child: Text(_dayNames[d - 1])),
                      selected: _days.contains(d),
                      onSelected: (on) =>
                          setState(() => on ? _days.add(d) : _days.remove(d)),
                    ),
                  ),
              ],
            ),
            if (_start >= _end)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: Text(
                  'Runs past midnight into the next day.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
          const SectionHeader('If two rules cover the same app'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Normal priority')),
              ButtonSegment(value: 1, label: Text('High priority')),
            ],
            selected: {_priority},
            onSelectionChanged: (s) => setState(() => _priority = s.first),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'The higher priority rule applies. If they match, the stricter '
            'one does.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SectionHeader('What will happen'),
          UCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  canRun
                      ? Icons.notifications_active_outlined
                      : Icons.info_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    _valid
                        ? engine.describe(draft)
                        : 'Choose at least one app${_schedule ? ' and one day' : ''}.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          FilledButton(
            onPressed: _valid ? () => _saveAndClose(draft) : null,
            child: const Text('Save rule'),
          ),
          if (existing != null) ...[
            const SectionHeader('Exceptions for today'),
            if (RuleEngine.isPaused(existing, now))
              OutlinedButton(
                onPressed: () =>
                    _saveAndClose(draft.copyWith(pausedDay: () => null)),
                child: const Text('Resume today'),
              )
            else
              OutlinedButton(
                onPressed: () =>
                    _saveAndClose(draft.copyWith(pausedDay: () => dayKey(now))),
                child: const Text('Pause for today'),
              ),
            if (!_schedule) ...[
              const SizedBox(height: Space.sm),
              OutlinedButton(
                onPressed: () => _saveAndClose(
                  draft.copyWith(
                    extensionDay: dayKey(now),
                    extensionMinutes:
                        (existing.extensionDay == dayKey(now)
                            ? existing.extensionMinutes
                            : 0) +
                        5,
                  ),
                ),
                child: const Text('5 more minutes today'),
              ),
            ],
            const SizedBox(height: Space.sm),
            Text(
              'Exceptions end by themselves at midnight.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.lg),
            TextButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await ref.read(rulesProvider.notifier).remove(existing.id);
                navigator.pop();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete rule'),
            ),
          ],
        ],
      ),
    );
  }
}
