import ManagedSettings
import ManagedSettingsUI
import UIKit

/// What the user sees in place of a restricted app.
class UnscrollShieldConfiguration: ShieldConfigurationDataSource {
  private func shield() -> ShieldConfiguration {
    ShieldConfiguration(
      backgroundBlurStyle: .systemMaterial,
      title: ShieldConfiguration.Label(text: "Paused by Unscroll", color: .label),
      subtitle: ShieldConfiguration.Label(
        text: "You chose to restrict this. You can change it in Unscroll at any time.",
        color: .secondaryLabel),
      primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .white)
    )
  }

  override func configuration(shielding application: Application) -> ShieldConfiguration {
    shield()
  }

  override func configuration(
    shielding application: Application, in category: ActivityCategory
  ) -> ShieldConfiguration { shield() }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { shield() }

  override func configuration(
    shielding webDomain: WebDomain, in category: ActivityCategory
  ) -> ShieldConfiguration { shield() }
}
