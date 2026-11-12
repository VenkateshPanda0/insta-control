import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions/permission_service.dart';
import '../core/platform_capabilities/capability.dart';
import '../core/platform_capabilities/capability_registry.dart';
import '../core/platform_capabilities/native_services.dart';
import '../core/platform_capabilities/platform_capability_service.dart';
import '../core/focus/focus_models.dart';
import '../core/goals/goals.dart';
import '../core/rule_engine/engine.dart';
import '../core/rule_engine/rule.dart';
import '../core/storage/app_settings.dart';
import '../core/storage/json_store.dart';
import '../core/usage/usage_models.dart';

/// Overridden in `main` (and in tests) with a real store.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('settingsStoreProvider not overridden'),
);

/// Overridden in `main` (and in tests).
final jsonStoreProvider = Provider<JsonStore>(
  (ref) => throw UnimplementedError('jsonStoreProvider not overridden'),
);

/// Injectable clock so time-based behaviour can be tested.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final capabilityServiceProvider = Provider<PlatformCapabilityService>(
  (ref) => const MethodChannelCapabilityService(),
);

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const MethodChannelPermissionService(),
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsStoreProvider).load();

  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    await ref.read(settingsStoreProvider).save(state);
  }

  /// Deletes everything Unscroll stored and switches off whatever it had
  /// switched on (session restriction, pending notification, reminders).
  Future<void> deleteAllData() async {
    await ref.read(focusProvider.notifier).end();
    await ref.read(restrictionServiceProvider).cancelSessionEnd();
    await ref.read(settingsStoreProvider).deleteAll();
    ref.read(rulesProvider.notifier).reset();
    ref.read(focusProvider.notifier).reset();
    ref.read(goalsProvider.notifier).reset();
    state = const AppSettings();
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class PlatformReportController extends AsyncNotifier<PlatformReport> {
  @override
  Future<PlatformReport> build() =>
      ref.read(capabilityServiceProvider).fetchReport();

  Future<void> refresh() async {
    state = AsyncData(await ref.read(capabilityServiceProvider).fetchReport());
  }

  Future<PermissionRequestResult> requestPermission(
    AppPermission permission,
  ) async {
    final result = await ref
        .read(permissionServiceProvider)
        .request(permission);
    await refresh();
    return result;
  }
}

final platformReportProvider =
    AsyncNotifierProvider<PlatformReportController, PlatformReport>(
      PlatformReportController.new,
    );

/// Until the device has answered, everything is treated as unavailable.
final capabilityRegistryProvider = Provider<CapabilityRegistry>((ref) {
  final report = ref.watch(platformReportProvider).value;
  return CapabilityRegistry(
    report ?? const PlatformReport.unreachable('Checking this device…'),
  );
});

const _native = MethodChannelNativeServices();

final usageServiceProvider = Provider<UsageReportingService>((ref) => _native);
final appSelectionServiceProvider = Provider<ApplicationSelectionService>(
  (ref) => _native,
);
final restrictionServiceProvider = Provider<RestrictionService>(
  (ref) => _native,
);

/// Measured usage, or null when the device cannot provide it. Re-read
/// whenever the device report changes (for example after returning to the app).
final usageReportProvider = FutureProvider<UsageReport?>((ref) async {
  final registry = ref.watch(capabilityRegistryProvider);
  if (!registry.of(FeatureId.usageReporting).isUsable) return null;
  return ref.read(usageServiceProvider).fetchUsage();
});

final installedAppsProvider = FutureProvider.autoDispose<List<InstalledApp>>(
  (ref) => ref.read(appSelectionServiceProvider).listInstalledApps(),
);

/// iOS Screen Time selection counts and shield state.
class TokenSelectionController extends AsyncNotifier<TokenSelectionSummary?> {
  @override
  Future<TokenSelectionSummary?> build() =>
      ref.read(appSelectionServiceProvider).selectionSummary();

  Future<void> pick() async {
    final next = await ref
        .read(appSelectionServiceProvider)
        .presentSystemPicker();
    if (next != null) state = AsyncData(next);
  }

  Future<void> setShieldActive(bool active) async {
    final next = await ref
        .read(restrictionServiceProvider)
        .setShieldActive(active);
    if (next != null) state = AsyncData(next);
  }
}

final tokenSelectionProvider =
    AsyncNotifierProvider<TokenSelectionController, TokenSelectionSummary?>(
      TokenSelectionController.new,
    );

// ---- Rules ---------------------------------------------------------------

final ruleEngineProvider = Provider<RuleEngine>((ref) {
  final registry = ref.watch(capabilityRegistryProvider);
  final reminders = registry.of(FeatureId.reminders);
  return RuleEngine(
    EngineCapabilities(
      backgroundRestrict: registry.of(FeatureId.scheduledRestrictions).isUsable,
      reminders: reminders.isUsable,
      unavailableReason: reminders.reason,
    ),
  );
});

class RulesController extends Notifier<List<Rule>> {
  static const _key = 'rules.v1';

  @override
  List<Rule> build() {
    final raw = ref.read(jsonStoreProvider).read(_key);
    if (raw is List) {
      return [for (final item in raw) ?Rule.fromJson(item)];
    }
    // First run after Phase 2: turn per-app budgets into rules.
    return [
      for (final e in ref.read(settingsProvider).managedApps.entries)
        if (e.value.dailyLimitMinutes != null)
          Rule(
            id: 'budget-${e.key}',
            targets: {e.key: e.value.label},
            trigger: DailyUsageTrigger(e.value.dailyLimitMinutes!),
          ),
    ];
  }

  Future<void> _set(List<Rule> rules) {
    state = rules;
    return ref.read(jsonStoreProvider).write(_key, [
      for (final r in rules) r.toJson(),
    ]);
  }

  Future<void> save(Rule rule) => _set([
    for (final r in state)
      if (r.id != rule.id) r,
    rule,
  ]);

  Future<void> remove(String id) => _set([
    for (final r in state)
      if (r.id != id) r,
  ]);

  /// Drops an app from every rule; rules left with no target are removed.
  Future<void> removeTarget(String packageName) => _set([
    for (final r in state)
      if (!r.targets.containsKey(packageName))
        r
      else if (r.targets.length > 1)
        r.copyWith(targets: {...r.targets}..remove(packageName)),
  ]);

  void reset() => state = const [];
}

final rulesProvider = NotifierProvider<RulesController, List<Rule>>(
  RulesController.new,
);

/// Keeps the native background check in step with the saved rules. Re-runs
/// when rules or device capabilities change (including on app resume).
final planSyncProvider = Provider<void>((ref) {
  final plan = ref
      .watch(ruleEngineProvider)
      .compile(ref.watch(rulesProvider), ref.read(clockProvider)());
  ref.read(restrictionServiceProvider).syncPlan(plan);
});

// ---- Focus ---------------------------------------------------------------

class FocusController extends Notifier<FocusState> {
  static const _key = 'focus.v1';
  static const _historyLimit = 200;

  @override
  FocusState build() =>
      FocusState.fromJson(ref.read(jsonStoreProvider).read(_key));

  Future<void> _set(FocusState next) {
    state = next;
    return ref.read(jsonStoreProvider).write(_key, next.toJson());
  }

  DateTime _now() => ref.read(clockProvider)();

  Future<void> start(FocusMode mode) async {
    if (state.active != null) return;
    final restrictions = ref.read(restrictionServiceProvider);
    var restricting = false;
    if (mode.restrictApps &&
        ref
            .read(capabilityRegistryProvider)
            .of(FeatureId.appBlocking)
            .isUsable) {
      // Load the selection if the Apps tab has not been opened yet.
      final selection = await ref.read(tokenSelectionProvider.future);
      // Only take ownership of the restriction if it was not already on.
      if (selection != null && !selection.isEmpty && !selection.shieldActive) {
        await ref.read(tokenSelectionProvider.notifier).setShieldActive(true);
        restricting = true;
      }
    }
    final now = _now();
    final endsAt = now.add(Duration(minutes: mode.minutes));
    await _set(
      FocusState(
        customModes: state.customModes,
        history: state.history,
        active: ActiveSession(
          modeName: mode.name,
          startedAt: now,
          endsAt: endsAt,
          restricting: restricting,
        ),
      ),
    );
    await restrictions.scheduleSessionEnd(endsAt, mode.name);
  }

  /// Ends the session now (early), or records it as complete if time is up.
  Future<void> end() async {
    final session = state.active;
    if (session == null) return;
    final now = _now();
    final completed = !now.isBefore(session.endsAt);
    final planned = session.endsAt.difference(session.startedAt).inMinutes;
    final actual = completed
        ? planned
        : now.difference(session.startedAt).inMinutes.clamp(0, planned);
    if (session.restricting) {
      await ref.read(tokenSelectionProvider.notifier).setShieldActive(false);
    }
    if (!completed) {
      await ref.read(restrictionServiceProvider).cancelSessionEnd();
    }
    await _set(
      FocusState(
        customModes: state.customModes,
        history: [
          SessionRecord(
            modeName: session.modeName,
            startedAt: session.startedAt,
            plannedMinutes: planned,
            actualMinutes: actual,
            completed: completed,
          ),
          ...state.history,
        ].take(_historyLimit).toList(),
      ),
    );
  }

  /// Call whenever the app is visible: closes a session whose time is up.
  Future<void> finishIfDue() async {
    final session = state.active;
    if (session != null && !_now().isBefore(session.endsAt)) await end();
  }

  Future<void> addMode(FocusMode mode) => _set(
    FocusState(
      customModes: [...state.customModes, mode],
      active: state.active,
      history: state.history,
    ),
  );

  Future<void> removeMode(String id) => _set(
    FocusState(
      customModes: [
        for (final m in state.customModes)
          if (m.id != id) m,
      ],
      active: state.active,
      history: state.history,
    ),
  );

  void reset() => state = const FocusState();
}

final focusProvider = NotifierProvider<FocusController, FocusState>(
  FocusController.new,
);

// ---- Goals ---------------------------------------------------------------

class GoalsController extends Notifier<List<Goal>> {
  static const _key = 'goals.v1';

  @override
  List<Goal> build() {
    final raw = ref.read(jsonStoreProvider).read(_key);
    return [
      if (raw is List)
        for (final item in raw) ?Goal.fromJson(item),
    ];
  }

  Future<void> _set(List<Goal> goals) {
    state = goals;
    return ref.read(jsonStoreProvider).write(_key, [
      for (final g in goals) g.toJson(),
    ]);
  }

  Future<void> add(Goal goal) => _set([...state, goal]);
  Future<void> remove(String id) => _set([
    for (final g in state)
      if (g.id != id) g,
  ]);

  void reset() => state = const [];
}

final goalsProvider = NotifierProvider<GoalsController, List<Goal>>(
  GoalsController.new,
);

final goalProgressProvider = Provider.family<GoalProgress, Goal>(
  (ref, goal) => evaluateGoal(
    goal,
    usage: ref.watch(usageReportProvider).value,
    history: ref.watch(focusProvider.select((f) => f.history)),
    now: ref.read(clockProvider)(),
  ),
);
