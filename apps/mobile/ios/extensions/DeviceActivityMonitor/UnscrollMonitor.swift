import DeviceActivity

/// Runs in the background when a scheduled interval starts or ends, or when a
/// usage threshold is reached, and turns shields on or off.
class UnscrollMonitor: DeviceActivityMonitor {
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    // A "budget" activity only shields once its threshold is reached.
    if !activity.rawValue.hasPrefix("budget") { SharedSelection.applyShield() }
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    if SharedSelection.defaults?.bool(forKey: "shieldActive") != true {
      SharedSelection.clearShield()
    }
  }

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name, activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)
    SharedSelection.applyShield()
  }
}
