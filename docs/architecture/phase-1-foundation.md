# Phase 1 — Shared app foundation

## What exists

| Area | Location (`apps/mobile/`) |
|---|---|
| Design system (tokens, light/dark theme, shared widgets) | `lib/core/design_system/` |
| Navigation (5 tabs, onboarding redirect) | `lib/core/navigation/` |
| Capability registry and device report model | `lib/core/platform_capabilities/` |
| Permission service | `lib/core/permissions/` |
| Local settings storage | `lib/core/storage/` |
| Onboarding (6 steps) | `lib/features/onboarding/` |
| Home, Apps, Focus, Insights, Settings | `lib/features/*` |
| Android channel (Kotlin) | `android/app/src/main/kotlin/app/unscroll/unscroll/` |
| iOS channel (Swift) | `ios/Runner/AppDelegate.swift` |
| Tests | `test/` |

## How capabilities work

1. The native layer answers `getPlatformReport` on the `app.unscroll/platform`
   method channel with the OS version, permission states, and a status for each
   feature (`supported`, `supportedWithLimitations`, `experimental`,
   `requiresAuthorization`, `unavailable`) plus a reason and limitation source.
2. `PlatformReport.fromMap` parses it defensively; unknown or malformed entries
   are dropped.
3. `CapabilityRegistry` treats anything not reported as unavailable. Screens ask
   the registry before showing a control, and show `CapabilityNotice` (no switch)
   when a feature is not usable.
4. The report is re-fetched whenever the app returns to the foreground, so
   permission changes made in system settings are picked up.

A native feature is only reported as usable once its implementation exists. In
Phase 1 every enforcement and reporting feature is therefore reported as
unavailable with the source "Not in this version yet" or the real OS/third-party
limitation.

## Compatibility matrix (Phase 1 state)

| Feature | iOS | Android | API | Permission | Fallback | Readiness |
|---|---|---|---|---|---|---|
| Screen-time reporting | Not built (needs iOS 16+, Family Controls entitlement, DeviceActivityReport extension) | Not built (UsageStatsManager) | DeviceActivity / UsageStatsManager | Screen Time / Usage access | Empty state, no numbers shown | Phase 2 |
| Choosing installed apps | Not built (FamilyActivityPicker, opaque tokens) | Not built (PackageManager) | FamilyControls / PackageManager | Screen Time / none | Preset list saved locally | Phase 2 |
| App restrictions | Not built (ManagedSettings shields) | Not built; no single official API, approach under policy review | ManagedSettings / TBD | Screen Time / TBD | Reminders | Phase 2 |
| Scheduled restrictions | Not built (DeviceActivity schedules) | Not built | DeviceActivity / AlarmManager, WorkManager | as above | Reminders | Phase 2–3 |
| Launch interception | Unavailable (iOS); shields are the supported route | Unavailable (Android) | none | — | Open the app from inside Unscroll | By design |
| Hiding sections inside other apps | Unavailable (third-party app) | Unavailable (third-party app) | none | — | Following feed, timed sessions, whole-app limits | By design |
| Reminders | Not built | Not built | UserNotifications / NotificationManager | Notifications | — | Phase 3 |
| Focus sessions | Not built | Not built | — | — | — | Phase 3 |
| Permission status and requests | Built, not yet run on a device | Built, compiled | AuthorizationCenter, UNUserNotificationCenter / AppOpsManager, POST_NOTIFICATIONS | — | — | Needs device test |

## Decisions

- **Storage:** settings are one JSON document in `shared_preferences` behind a
  `SettingsStore` interface. A SQLite database (Drift) is deferred until rules,
  sessions and goals need relational storage.
- **`packages/`:** not created yet. The capability and storage code is pure Dart
  and can move into `packages/platform_contracts` when the rule engine arrives.
- **iOS Swift lives in `AppDelegate.swift`** for now, because adding new files
  or extension targets needs Xcode to edit the project file safely.
- **App list in onboarding is a set of preset labels**, not installed apps. The
  UI says so.

## Validation status

- `flutter analyze`: clean.
- `flutter test`: 9 tests pass (registry parsing, storage, onboarding flow, tab
  navigation, no switch for unavailable features, data deletion). Widget tests
  use a fake native layer.
- Android: `flutter build apk --debug` succeeds. Not run on a device or emulator.
- iOS: not compiled (needs macOS and Xcode). The Swift code is unverified.
