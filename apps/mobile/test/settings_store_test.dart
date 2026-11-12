import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unscroll/core/storage/app_settings.dart';

void main() {
  test('settings survive a save and reload', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsSettingsStore(prefs);
    expect(store.load().onboardingComplete, isFalse);

    await store.save(
      const AppSettings(
        onboardingComplete: true,
        themeMode: AppThemeMode.dark,
        goals: {'better_sleep'},
        managedPresets: {'instagram', 'youtube'},
        frictionMode: FrictionMode.strict,
      ),
    );
    final loaded = PrefsSettingsStore(prefs).load();
    expect(loaded.onboardingComplete, isTrue);
    expect(loaded.themeMode, AppThemeMode.dark);
    expect(loaded.goals, {'better_sleep'});
    expect(loaded.managedPresets, {'instagram', 'youtube'});
    expect(loaded.frictionMode, FrictionMode.strict);

    await store.deleteAll();
    expect(store.load().onboardingComplete, isFalse);
    expect(store.load().managedPresets, isEmpty);
  });

  test('corrupt or unexpected data falls back to defaults', () async {
    SharedPreferences.setMockInitialValues({'settings.v1': '{not json'});
    var store = PrefsSettingsStore(await SharedPreferences.getInstance());
    expect(store.load().onboardingComplete, isFalse);

    SharedPreferences.setMockInitialValues({
      'settings.v1': '{"themeMode":"neon","goals":"x","frictionMode":3}',
    });
    store = PrefsSettingsStore(await SharedPreferences.getInstance());
    final s = store.load();
    expect(s.themeMode, AppThemeMode.system);
    expect(s.goals, isEmpty);
    expect(s.frictionMode, FrictionMode.gentle);
  });
}
