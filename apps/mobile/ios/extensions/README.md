# iOS Screen Time extensions (not yet part of the Xcode project)

These sources are written but **not compiled or tested**. Adding extension
targets needs Xcode on a Mac. Until then the app reports scheduled restrictions
and usage reports as unavailable on iOS.

To wire them up in Xcode:

1. Register the App Group `group.app.unscroll.unscroll` and add it to the Runner
   target and every extension target.
2. Add four targets (File > New > Target) and replace each template source with
   the file here; add `SharedSelection.swift` to the monitor target.
   - Device Activity Monitor Extension → `DeviceActivityMonitor/`
   - Shield Configuration Extension → `ShieldConfiguration/`
   - Shield Action Extension → `ShieldAction/`
   - Device Activity Report Extension → `DeviceActivityReport/`
3. Add the Family Controls capability to each target. Development builds work
   with the development entitlement; App Store and TestFlight distribution
   needs Apple to approve the Family Controls (Distribution) entitlement for
   every bundle ID.
4. Set each extension's deployment target to iOS 16.0.
5. Test on a physical iPhone. Screen Time APIs do not work fully in the simulator.
