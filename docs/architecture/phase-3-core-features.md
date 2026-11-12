# Phase 3 — Core user features

## What was built

| Feature | Code (`apps/mobile/lib/`) |
|---|---|
| Rule model and engine (pure Dart) | `core/rule_engine/` |
| Rule list and rule builder | `features/rules/` |
| Focus modes, sessions, history | `core/focus/`, `features/focus_modes/` |
| Goals and progress | `core/goals/`, `features/goals/` |
| State and persistence | `app/providers.dart`, `core/storage/json_store.dart` |
| Android plan runner, quiet-hours logic, session notification | `android/.../reminders/` |
| iOS session notification, capability updates | `ios/Runner/AppDelegate.swift` |

## Rule engine

A rule is **target + trigger + exception**; the **action** is chosen by the
engine from what the device can really do.

- **Target:** Android — chosen installed apps. iOS — the apps chosen in Apple's
  picker (opaque tokens).
- **Trigger:** daily time used (minutes) or time of day (days + start/end,
  may run past midnight).
- **Action:** restrict if the device supports background restriction, else
  remind if reminders are usable, else none. Today that means *remind* on
  Android and *none* on iOS (see limitations).
- **Exceptions:** pause for today; "5 more minutes today" for usage rules. Both
  expire at midnight without the app being opened.
- **Priority and conflicts:** when two usage rules cover the same app, the
  higher priority wins; on a tie the stricter limit wins; then the lower id.
  The losing rule shows a note. Time-of-day rules never conflict; each one
  reminds once per window.
- **Preview wording:** `RuleEngine.describe` produces the sentence shown before
  saving and on the rule card. A reminder-only rule is never described as a
  block, and a rule that cannot run says so and gives the device's reason.
- **Compilation:** `RuleEngine.compile` turns the rules into a `NativePlan`
  with two bodies: `today` (with today's pauses/extensions, valid only for that
  date) and `base`. The Android worker uses `today` only when the date matches.

## Focus modes

- Five built-in modes (Study 25 min, Work 50, Deep Focus 90, Social 15,
  Sleep 8 h) and unlimited custom modes (name, duration, optional restriction).
- A session stores its end time, so it survives the app being closed. It is
  recorded as complete the next time Unscroll is visible after the end time.
- Ending early: immediate in Gentle mode, a confirmation in Balanced, and a
  more deliberate confirmation in Strict.
- If notifications are allowed, one notification is scheduled for the end
  (WorkManager on Android, so timing is approximate; `UNUserNotificationCenter`
  on iOS).
- **iOS restriction:** a mode with "restrict" turns the Screen Time shield on at
  the start and off when the session ends *inside Unscroll*. Without the monitor
  extension the shield cannot lift by itself, and the session card says so.
- **Android:** sessions are a timer and history only; nothing is restricted.

## Goals

- "Screen time under X a day" (needs measured usage; shows "can't be tracked
  yet" on iOS) and "Focus for X a day" (works on both platforms).
- Progress shows today, days met in the last week, and an optional streak
  (Settings > Show streaks). Streaks count completed days only.

## Storage

Rules, focus data and goals are JSON documents in local preferences
(`rules.v1`, `focus.v1`, `goals.v1`). Drift/SQLite was not introduced; the data
is small and has no relational queries yet. "Delete all Unscroll data" ends any
session, cancels its notification, clears the native plan and wipes everything.

## Limitations and deferred items

- **iOS usage and time-of-day rules can be saved but do not run.** They need the
  DeviceActivity monitor extension target (see `ios/extensions/README.md`).
- **Android rules remind; they never block.** Checks run about every 15 minutes.
- Not built: Pomodoro break cycles, scheduled/automatic focus sessions, mode
  icons and accent colours, weekly budgets, opening delays, a focus-mode rule
  trigger, per-rule custom exception lengths.
- Android `minSdk` is now 26 (Android 8.0).

## Validation status

- `flutter analyze`: clean. `flutter test`: 45 pass (fake native layer, movable
  test clock).
- Kotlin unit tests: 7 pass (usage aggregation, schedule windows).
- `flutter build apk --debug`: succeeds.
- Not done: any run on an Android device or emulator; any iOS compile or run.
  Reminder delivery, quiet-hours notifications, session-end notifications and
  the iOS session shield are untested on real hardware.
