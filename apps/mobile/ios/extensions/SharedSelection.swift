import FamilyControls
import Foundation
import ManagedSettings

/// Add this file to every extension target. Reads what the main app saved
/// through the shared App Group and applies or clears shields.
enum SharedSelection {
  static let defaults = UserDefaults(suiteName: "group.app.unscroll.unscroll")
  private static let store = ManagedSettingsStore()

  static func load() -> FamilyActivitySelection {
    guard let data = defaults?.data(forKey: "selection"),
      let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    else { return FamilyActivitySelection() }
    return selection
  }

  static func applyShield() {
    let selection = load()
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
}
