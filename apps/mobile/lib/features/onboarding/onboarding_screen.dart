import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/design_system/tokens.dart';
import '../../core/storage/app_settings.dart';
import '../../shared/catalog.dart';
import '../../shared/permission_list.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 6;
  final _controller = PageController();
  int _page = 0;
  final _goals = <String>{};
  final _presets = <String>{};
  FrictionMode _friction = FrictionMode.gentle;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) => _controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  Future<void> _finish() => ref
      .read(settingsProvider.notifier)
      .update(
        (s) => s.copyWith(
          onboardingComplete: true,
          goals: {..._goals},
          managedPresets: {..._presets},
          frictionMode: _friction,
        ),
      );

  void _toggle(Set<String> set, String id) =>
      setState(() => set.contains(id) ? set.remove(id) : set.add(id));

  @override
  Widget build(BuildContext context) {
    final last = _page == _pageCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.md,
                Space.lg,
                0,
              ),
              child: Semantics(
                label: 'Step ${_page + 1} of $_pageCount',
                child: LinearProgressIndicator(
                  value: (_page + 1) / _pageCount,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  const _Page(
                    title: 'Unscroll',
                    subtitle: 'Use what matters. Block what distracts.',
                    children: [
                      _Bullet(
                        Icons.tune,
                        'Set limits and focus times that fit how you actually '
                        'use your phone.',
                      ),
                      _Bullet(
                        Icons.lock_outline,
                        'No account. Your data stays on this device.',
                      ),
                      _Bullet(
                        Icons.verified_outlined,
                        'Unscroll only shows controls your device can really '
                        'enforce, and tells you when it cannot.',
                      ),
                    ],
                  ),
                  _Page(
                    title: 'What would you like to change?',
                    subtitle:
                        'Pick any that apply. You can change these later.',
                    children: [
                      for (final g in goalOptions)
                        _ChoiceTile(
                          title: g.title,
                          selected: _goals.contains(g.id),
                          onTap: () => _toggle(_goals, g.id),
                        ),
                    ],
                  ),
                  _Page(
                    title: 'Which apps pull you in?',
                    subtitle:
                        'These are saved as your starting list. Linking them '
                        'to the apps installed on this device comes in a '
                        'later version.',
                    children: [
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.sm,
                        children: [
                          for (final p in appPresets)
                            FilterChip(
                              avatar: Icon(p.icon, size: 18),
                              label: Text(p.name),
                              selected: _presets.contains(p.id),
                              onSelected: (_) => _toggle(_presets, p.id),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const _Page(
                    title: 'Permissions',
                    subtitle:
                        'Each one is optional and can be turned off later. '
                        'Unscroll never reads messages, passwords or your '
                        'screen.',
                    children: [PermissionList()],
                  ),
                  _Page(
                    title: 'How firm should Unscroll be?',
                    subtitle: 'Every restriction stays visible and reversible.',
                    children: [
                      for (final m in FrictionMode.values)
                        _ChoiceTile(
                          title: m.title,
                          subtitle: m.summary,
                          selected: _friction == m,
                          onTap: () => setState(() => _friction = m),
                        ),
                    ],
                  ),
                  _Page(
                    title: 'You\'re set up',
                    subtitle:
                        'Your choices are saved on this device. Settings shows '
                        'exactly what Unscroll can and cannot do on this '
                        'phone.',
                    children: [
                      _Bullet(
                        Icons.flag_outlined,
                        _goals.isEmpty
                            ? 'No goals chosen yet'
                            : '${_goals.length} goal(s) chosen',
                      ),
                      _Bullet(
                        Icons.apps_outlined,
                        _presets.isEmpty
                            ? 'No apps chosen yet'
                            : '${_presets.length} app(s) on your list',
                      ),
                      _Bullet(Icons.shield_outlined, '${_friction.title} mode'),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _go(_page - 1),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: last ? _finish : () => _go(_page + 1),
                    child: Text(
                      last
                          ? 'Open Unscroll'
                          : (_page == 0 ? 'Get started' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        const SizedBox(height: Space.lg),
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineMedium),
        ),
        const SizedBox(height: Space.sm),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.lg),
        ...children,
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: Space.md),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    ),
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected
              ? scheme.secondaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Radii.control),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: onTap,
            title: Text(title),
            subtitle: subtitle == null ? null : Text(subtitle!),
            trailing: Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? scheme.primary : scheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}
