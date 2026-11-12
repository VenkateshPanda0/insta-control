# Unscroll Android APK

`unscroll-1.0.0.apk` — release build of version 1.0.0 (build 1), for Android 8.0 or later.

## Install

1. Copy the APK to an Android phone (or download it there).
2. Open it and allow "Install unknown apps" for the app you opened it with.
3. Open Unscroll and follow setup. Allow **Usage access** and **Notifications**
   when asked if you want screen-time reports and reminders.

## What to know

- **For testing only.** It is signed with the Android debug key, so it can be
  installed directly but cannot be uploaded to Google Play.
- **Not yet run on a device.** The build and automated tests pass, but nobody
  has installed and used this APK on a phone or emulator yet.
- Rules on Android send reminders; they do not block apps.
- There is no iOS build here; that needs a Mac with Xcode.

## Rebuild

```bash
cd apps/mobile
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ../../apk/unscroll-1.0.0.apk
```
