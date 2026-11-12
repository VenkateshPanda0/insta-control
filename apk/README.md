# Unscroll Android APK

`unscroll-1.0.1.apk` — release build of version 1.0.1 (build 2), for Android 8.0 or later.

## Install

1. Copy the APK to an Android phone (or download it there).
2. Open it and allow "Install unknown apps" for the app you opened it with.
3. Open Unscroll and follow setup. Allow **Usage access** and **Notifications**
   when asked if you want screen-time reports and reminders.

## What to know

- **For testing only.** It is signed with the Android debug key, so it can be
  installed directly but cannot be uploaded to Google Play.
- **Fix in 1.0.1:** version 1.0.0 crashed on launch (the release build removed a
  class that the reminder scheduler needs). 1.0.1 was installed and launched on
  an Android 11 emulator and shows the welcome screen. It has not been tried on
  a real phone yet, so please report anything that still fails.
- Rules on Android send reminders; they do not block apps.
- There is no iOS build here; that needs a Mac with Xcode.

## Rebuild

```bash
cd apps/mobile
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ../../apk/unscroll-1.0.1.apk
```
