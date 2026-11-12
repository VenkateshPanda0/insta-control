import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/design_system/widgets.dart';
import '../../core/navigation/router.dart';
import '../../core/rule_engine/engine.dart';
import '../../core/rule_engine/rule.dart';
import 'rule_builder_screen.dart';

/// Rule list with honest status for each rule on this device.
class RulesSection extends ConsumerWidget {
  const RulesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesProvider);
    final engine = ref.watch(ruleEngineProvider);
    final now = ref.read(clockProvider)();
    final overridden = engine.overridden(rules, now);
    final theme = Theme.of(context);

    String status(Rule rule) {
      if (engine.actionFor(rule) == EffectiveAction.none) {
        return 'Can\'t run here yet';
      }
      if (!rule.enabled) return 'Off';
      if (RuleEngine.isPaused(rule, now)) return 'Paused today';
      final trigger = rule.trigger;
      if (trigger is ScheduleTrigger &&
          RuleEngine.activeWindowStart(trigger, now) != null) {
        return 'In effect now';
      }
      if (rule.extensionDay == dayKey(now) && rule.extensionMinutes > 0) {
        return '+${rule.extensionMinutes} min today';
      }
      return engine.actionFor(rule) == EffectiveAction.restrict
          ? 'Restricts'
          : 'Reminder';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rules.isEmpty)
          const EmptyState(
            icon: Icons.rule,
            title: 'No rules yet',
            message:
                'A rule says which apps, when, and what Unscroll should do.',
          ),
        for (final rule in rules)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: UCard(
              onTap: () => context.go(
                Routes.ruleBuilder,
                extra: RuleBuilderArgs(rule: rule),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusPill(
                          status(rule),
                          positive:
                              rule.enabled &&
                              engine.actionFor(rule) != EffectiveAction.none &&
                              !RuleEngine.isPaused(rule, now),
                        ),
                        const SizedBox(height: Space.sm),
                        Text(engine.describe(rule)),
                        if (overridden[rule.id] case final winner?) ...[
                          const SizedBox(height: Space.xs),
                          Text(
                            'Another rule takes priority for some of these apps: '
                            '${RuleEngine.triggerText(rules.firstWhere((r) => r.id == winner).trigger)}.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // No switch for a rule this device cannot run.
                  if (engine.actionFor(rule) != EffectiveAction.none)
                    Switch(
                      value: rule.enabled,
                      onChanged: (on) => ref
                          .read(rulesProvider.notifier)
                          .save(rule.copyWith(enabled: on)),
                    ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => context.go(Routes.ruleBuilder),
          icon: const Icon(Icons.add),
          label: const Text('New rule'),
        ),
      ],
    );
  }
}
