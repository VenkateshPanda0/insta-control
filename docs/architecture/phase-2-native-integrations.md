# Phase 2 — Native screen-time integrations

## Android (compiles; not yet run on a device)

| Piece | File (`apps/mobile/android/app/src/main/kotlin/app/unscroll/unscroll/`) |
|---|---|
| Foreground-time calculation (pure Kotlin, unit tested) | `usage/UsageAggregator.kt` |
| Reading `UsageStatsManager` events, 7 days + today per app | `usage/UsageReader.kt` |
| Launchable installed apps | `apps/InstalledApps.kt` |
| Daily budget reminders (WorkManager, notification) | `reminders/BudgetReminders.kt` |
| Capability report | `capabilities/CapabilityReporter.kt` |

- **Usage** comes from `queryEvents` (resume/pause/stop, screen off, shutdown),
  split at local midnight. Only apps with a launcher icon are counted; Unscroll
  itself is excluded. Android may retain fewer than seven days of events, in
  which case older days read as zero.
- **App list** uses a `<queries>` launcher intent, not `QUERY_ALL_PACKAGES`.
- **Reminders:** a 15-minute periodic WorkManager job (the platform minimum;
  Doze can delay it) compares today's usage with saved budgets and posts one
  notification per app per day. WorkManager re-schedules itself after reboot.
- **Blocking assessment:** Android has no official blocking API for third-party
  wellbeing apps. Accessibility services and overlays are restricted by Google
  Play policy, so they are not used. App blocking, scheduled restrictions and
  launch interception are reported as unavailable (Android limitation), and
  budget reminders are the supported alternative.

## iOS (written; not compiled or run — needs macOS, Xcode, a physical iPhone)

| Piece | File (`apps/mobile/ios/`) |
|---|---|
| Authorization, app picker, shields, capability report | `Runner/AppDelegate.swift` |
| Family Controls entitlement | `Runner/Runner.entitlements` |
| Monitor, shield UI, shield action, report extensions | `extensions/` (sources only, see its README) |

- **App selection:** `FamilyActivityPicker`; the selection is stored as opaque
  tokens on the native side. Flutter only receives counts.
- **Restriction:** `ManagedSettingsStore.shield` on the chosen apps, categories
  and web domains, toggled from the Apps tab.
- **Not active yet:** scheduled restrictions (DeviceActivity monitor extension)
  and usage reports (DeviceActivityReport extension) need extension targets and
  an App Group added in Xcode. The app reports both as unavailable until then.
- App selection and shields are reported as **experimental** once Screen Time
  access is granted, because they have not been verified on a device.
- Distribution needs Apple to approve the Family Controls (Distribution)
  entitlement for the app and each extension.

## Flutter

- `lib/core/platform_capabilities/native_services.dart`: `UsageReportingService`,
  `ApplicationSelectionService`, `RestrictionService` and their method-channel
  implementation. Failures return null/empty; nothing throws into the UI.
- `lib/core/usage/usage_models.dart`: measured usage models.
- Home shows today's total and top apps; Insights shows a 7-day chart and
  today's per-app list. Both only when usage reporting is usable.
- Apps tab: Android app picker and per-app budget sheet; iOS picker summary and
  a "Restrict chosen apps now" switch that only appears when blocking is usable
  and something is selected.

## Compatibility matrix (after Phase 2)

| Feature | iOS | Android |
|---|---|---|
| Screen-time reporting | Unavailable until report extension target is added | Supported with limitations (needs usage access) |
| Choosing apps | Experimental (needs Screen Time access, iOS 16+) | Supported |
| App restrictions | Experimental (shield toggle) | Unavailable — Android limitation |
| Scheduled restrictions | Unavailable until monitor extension target is added | Unavailable — Android limitation |
| Budget reminders | Unavailable until monitor extension target is added | Supported with limitations (may arrive late) |
| Launch interception | Unavailable — iOS limitation | Unavailable — Android limitation |
| Hiding sections inside other apps | Unavailable — third-party app | Unavailable — third-party app |
| Focus sessions | Not built (Phase 3) | Not built (Phase 3) |

## Validation status

- `flutter analyze`: clean. `flutter test`: 17 pass (fake native layer).
- Kotlin unit tests (`./gradlew :app:testDebugUnitTest`): 5 pass.
- `flutter build apk --debug`: succeeds.
- Not done: any run on an Android device or emulator; any iOS compile or run.

## Device test checklist

Android: grant/revoke usage access and see Home update on return; compare
totals with Digital Wellbeing; set a 15-minute budget and confirm one
notification; reboot and confirm reminders continue; change time zone.

iOS: grant Screen Time access; pick apps; toggle the shield and open a chosen
app; revoke access in Settings and confirm the controls disappear.
