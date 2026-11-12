import Flutter
import UIKit
import UserNotifications

#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
import SwiftUI
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
      case "scheduleSessionEnd":
        let args = call.arguments as? [String: Any]
        let atMs = (args?["atMs"] as? NSNumber)?.doubleValue ?? 0
        scheduleSessionEnd(atMs: atMs, title: args?["title"] as? String ?? "Focus session finished")
        result(nil)
      case "cancelSessionEnd":
        UNUserNotificationCenter.current()
          .removePendingNotificationRequests(withIdentifiers: [sessionEndId])
        result(nil)
      case "presentAppPicker", "getSelectionSummary", "setShieldActive":
        #if canImport(FamilyControls)
        if #available(iOS 16.0, *) {
          switch call.method {
          case "presentAppPicker":
            ScreenTime.presentPicker(result)
          case "setShieldActive":
            let args = call.arguments as? [String: Any]
            ScreenTime.setShieldActive(args?["active"] as? Bool ?? false)
            result(ScreenTime.summary())
          default:
            result(ScreenTime.summary())
          }
          return
        }
        #endif
        result(FlutterError(code: "unavailable", message: "Needs iOS 16 or later.", details: nil))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: Focus session notification

  private static let sessionEndId = "session-end"

  /// Delivered by iOS only if the user has allowed notifications.
  private static func scheduleSessionEnd(atMs: Double, title: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = "Open Unscroll to see your session."
    content.sound = .default
    let seconds = max(1, atMs / 1000 - Date().timeIntervalSince1970)
    let request = UNNotificationRequest(
      identifier: sessionEndId, content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
    UNUserNotificationCenter.current().add(request)
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
    let needsExtension = entry(
      "unavailable", "unscrollBuild",
      "Needs Unscroll's Screen Time extensions, which are not part of this build yet.")
    var selection = entry(
      "unavailable", "ios", "Needs iOS 16 or later for Screen Time access on your own device.")
    if #available(iOS 16.0, *) {
      if screenTimeState() == "granted" {
        selection = entry(
          "experimental", "none",
          "Uses Apple's Screen Time. Not yet verified on a physical iPhone.")
      } else {
        selection = entry(
          "requiresAuthorization", "none", "Allow Screen Time access in Permissions first.")
      }
    }
    return [
      "usageReporting": needsExtension,
      "appSelection": selection,
      "appBlocking": selection,
      "scheduledRestrictions": needsExtension,
      "launchInterception": entry(
        "unavailable", "ios",
        "iOS does not let an app step in whenever another app opens. "
          + "Screen Time shields on apps you choose are the supported route."),
      "inAppSectionControl": entry(
        "unavailable", "thirdPartyApp",
        "Other apps do not let outside apps change or hide parts of their screens."),
      "reminders": entry(
        "unavailable", "unscrollBuild",
        "Usage and time-of-day rules need Unscroll's Screen Time extensions, which are not "
          + "part of this build yet."),
      "focusSessions": entry(
        "supportedWithLimitations", "ios",
        "Timer and history. A mode can restrict your chosen apps while Screen Time access "
          + "is allowed; when time is up, open Unscroll to lift the restriction."),
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

#if canImport(FamilyControls)
/// App selection and shields through Apple's Screen Time frameworks.
/// The chosen apps are opaque tokens: Unscroll can count them and hand them
/// back to the system, but cannot see which apps they are.
@available(iOS 16.0, *)
enum ScreenTime {
  /// Shared with the extensions once the App Group is configured.
  static let defaults = UserDefaults(suiteName: "group.app.unscroll.unscroll") ?? .standard
  private static let selectionKey = "selection"
  private static let shieldKey = "shieldActive"
  private static let store = ManagedSettingsStore()

  static func loadSelection() -> FamilyActivitySelection {
    guard let data = defaults.data(forKey: selectionKey),
      let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    else { return FamilyActivitySelection() }
    return selection
  }

  static func saveSelection(_ selection: FamilyActivitySelection) {
    defaults.set(try? PropertyListEncoder().encode(selection), forKey: selectionKey)
    if defaults.bool(forKey: shieldKey) { applyShield() }
  }

  static func setShieldActive(_ active: Bool) {
    defaults.set(active, forKey: shieldKey)
    if active { applyShield() } else { clearShield() }
  }

  static func applyShield() {
    let selection = loadSelection()
    store.shield.applications =
      selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories =
      selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
  }

  static func clearShield() {
    store.shield.applications = nil
    store.shield.applicationCategories = nil
    store.shield.webDomains = nil
  }

  static func summary() -> [String: Any] {
    let selection = loadSelection()
    return [
      "apps": selection.applicationTokens.count,
      "categories": selection.categoryTokens.count,
      "webDomains": selection.webDomainTokens.count,
      "shieldActive": defaults.bool(forKey: shieldKey),
    ]
  }

  static func presentPicker(_ result: @escaping FlutterResult) {
    let root = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }
      .first?.rootViewController
    guard let presenter = root else {
      result(FlutterError(code: "no_window", message: "Could not show the app picker.", details: nil))
      return
    }
    var host: UIViewController?
    let screen = PickerScreen(selection: loadSelection()) { chosen in
      if let chosen = chosen { saveSelection(chosen) }
      host?.dismiss(animated: true) { result(summary()) }
    }
    let controller = UIHostingController(rootView: screen)
    controller.isModalInPresentation = true
    host = controller
    presenter.present(controller, animated: true)
  }
}

@available(iOS 16.0, *)
private struct PickerScreen: View {
  @State var selection: FamilyActivitySelection
  let onFinish: (FamilyActivitySelection?) -> Void

  var body: some View {
    NavigationView {
      FamilyActivityPicker(selection: $selection)
        .navigationTitle("Choose apps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { onFinish(nil) }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { onFinish(selection) }
          }
        }
    }
  }
}
#endif
