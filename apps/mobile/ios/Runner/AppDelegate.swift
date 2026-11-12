import Flutter
import UIKit
import UserNotifications

#if canImport(FamilyControls)
import FamilyControls
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    PlatformChannel.register(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// Tells the Flutter layer what this device and this build can really do.
/// A feature is only reported as usable once its native implementation exists.
enum PlatformChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.unscroll/platform", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getPlatformReport":
        report(result)
      case "requestPermission":
        let args = call.arguments as? [String: Any]
        requestPermission(args?["permission"] as? String, result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: Report

  private static func report(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let notifications: String
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral: notifications = "granted"
      case .denied: notifications = "denied"
      case .notDetermined: notifications = "notDetermined"
      @unknown default: notifications = "unavailable"
      }
      DispatchQueue.main.async {
        result([
          "platform": "iOS",
          "osVersion": UIDevice.current.systemVersion,
          "permissions": [
            "screenTime": screenTimeState(),
            "notifications": notifications,
          ],
          "capabilities": capabilities(),
        ])
      }
    }
  }

  private static func screenTimeState() -> String {
    #if canImport(FamilyControls)
    if #available(iOS 16.0, *) {
      switch AuthorizationCenter.shared.authorizationStatus {
      case .approved: return "granted"
      case .denied: return "denied"
      case .notDetermined: return "notDetermined"
      @unknown default: return "unavailable"
      }
    }
    #endif
    return "unavailable"
  }

  private static func capabilities() -> [String: [String: String]] {
    let screenTime: [String: String]
    if #available(iOS 16.0, *) {
      screenTime = entry(
        "unavailable", "unscrollBuild",
        "Uses Apple's Screen Time tools, which need Apple's Family Controls entitlement. "
          + "This is not built into this version yet.")
    } else {
      screenTime = entry(
        "unavailable", "ios",
        "Needs iOS 16 or later for Screen Time access on your own device.")
    }
    return [
      "usageReporting": screenTime,
      "appSelection": screenTime,
      "appBlocking": screenTime,
      "scheduledRestrictions": screenTime,
      "launchInterception": entry(
        "unavailable", "ios",
        "iOS does not let an app step in whenever another app opens. "
          + "Screen Time shields on apps you choose are the supported route."),
      "inAppSectionControl": entry(
        "unavailable", "thirdPartyApp",
        "Other apps do not let outside apps change or hide parts of their screens."),
      "reminders": entry(
        "unavailable", "unscrollBuild",
        "Reminder notifications are not built into this version yet."),
      "focusSessions": entry(
        "unavailable", "unscrollBuild",
        "Focus sessions are not built into this version yet."),
    ]
  }

  private static func entry(_ status: String, _ source: String, _ reason: String) -> [String: String] {
    return ["status": status, "source": source, "reason": reason]
  }

  // MARK: Permission requests

  private static func requestPermission(_ permission: String?, _ result: @escaping FlutterResult) {
    switch permission {
    case "notifications":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
        granted, error in
        DispatchQueue.main.async {
          if let error = error {
            result(["outcome": "failed", "message": error.localizedDescription])
          } else {
            result(["outcome": granted ? "granted" : "denied"])
          }
        }
      }
    case "screenTime":
      requestScreenTime(result)
    default:
      result(["outcome": "failed", "message": "Unknown permission."])
    }
  }

  private static func requestScreenTime(_ result: @escaping FlutterResult) {
    #if canImport(FamilyControls)
    if #available(iOS 16.0, *) {
      Task { @MainActor in
        do {
          try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
          result(["outcome": "granted"])
        } catch {
          result([
            "outcome": "failed",
            "message": "Screen Time access could not be granted. This build may not include "
              + "Apple's Family Controls entitlement.",
          ])
        }
      }
      return
    }
    #endif
    result(["outcome": "failed", "message": "Screen Time access needs iOS 16 or later."])
  }
}
