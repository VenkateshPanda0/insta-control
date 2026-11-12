import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../features/app_controls/app_picker_screen.dart';
import '../../features/app_controls/apps_screen.dart';
import '../../features/dashboard/home_screen.dart';
import '../../features/focus_modes/focus_screen.dart';
import '../../features/insights/insights_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/rules/rule_builder_screen.dart';
import '../../features/settings/capabilities_screen.dart';
import '../../features/settings/permissions_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'shell.dart';

abstract final class Routes {
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const apps = '/apps';
  static const appPicker = '/apps/pick';
  static const ruleBuilder = '/apps/rule';
  static const focus = '/focus';
  static const insights = '/insights';
  static const settings = '/settings';
  static const capabilities = '/settings/capabilities';
  static const permissions = '/settings/permissions';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever onboarding completes or data is deleted.
  final onboarded = ValueNotifier<bool>(
    ref.read(settingsProvider).onboardingComplete,
  );
  ref.listen(
    settingsProvider.select((s) => s.onboardingComplete),
    (_, next) => onboarded.value = next,
  );
  ref.onDispose(onboarded.dispose);

  StatefulShellBranch branch(
    String path,
    Widget screen, [
    List<RouteBase>? sub,
  ]) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => screen, routes: sub ?? [])],
  );

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: onboarded,
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == Routes.onboarding;
      if (!onboarded.value) return atOnboarding ? null : Routes.onboarding;
      return atOnboarding ? Routes.home : null;
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          branch(Routes.home, const HomeScreen()),
          branch(Routes.apps, const AppsScreen(), [
            GoRoute(path: 'pick', builder: (_, _) => const AppPickerScreen()),
            GoRoute(
              path: 'rule',
              builder: (_, state) =>
                  RuleBuilderScreen(args: state.extra as RuleBuilderArgs?),
            ),
          ]),
          branch(Routes.focus, const FocusScreen()),
          branch(Routes.insights, const InsightsScreen()),
          branch(Routes.settings, const SettingsScreen(), [
            GoRoute(
              path: 'capabilities',
              builder: (_, _) => const CapabilitiesScreen(),
            ),
            GoRoute(
              path: 'permissions',
              builder: (_, _) => const PermissionsScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
