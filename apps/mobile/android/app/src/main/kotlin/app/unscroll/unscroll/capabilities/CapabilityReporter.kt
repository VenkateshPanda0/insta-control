package app.unscroll.unscroll.capabilities

import android.os.Build
import app.unscroll.unscroll.permissions.PermissionGateway

/**
 * Tells the Flutter layer what this device and this build can really do.
 * A feature is only reported as usable once its native implementation exists.
 */
class CapabilityReporter(private val permissions: PermissionGateway) {

    fun report(): Map<String, Any> = mapOf(
        "platform" to "Android",
        "osVersion" to "${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
        "permissions" to permissions.states(),
        "capabilities" to capabilities(),
    )

    private fun capabilities(): Map<String, Map<String, String>> {
        val usageNote = if (permissions.hasUsageAccess()) {
            "Usage access is allowed. Reading and showing usage is not built into this version yet."
        } else {
            "Needs usage access, and reading usage is not built into this version yet."
        }
        return mapOf(
            "usageReporting" to notBuilt(usageNote),
            "appSelection" to notBuilt(
                "Android can list installed apps. The app picker is not built into this version yet.",
            ),
            "appBlocking" to notBuilt(
                "Android has no single official app-blocking API for apps like Unscroll. " +
                    "The approach is still being assessed against Google Play policy.",
            ),
            "scheduledRestrictions" to notBuilt("Depends on app restrictions, which are not built yet."),
            "launchInterception" to entry(
                "unavailable", "android",
                "Android does not offer a supported way for a wellbeing app to step in " +
                    "whenever another app opens.",
            ),
            "inAppSectionControl" to entry(
                "unavailable", "thirdPartyApp",
                "Other apps do not let outside apps change or hide parts of their screens.",
            ),
            "reminders" to notBuilt("Reminder notifications are not built into this version yet."),
            "focusSessions" to notBuilt("Focus sessions are not built into this version yet."),
        )
    }

    private fun notBuilt(reason: String) = entry("unavailable", "unscrollBuild", reason)

    private fun entry(status: String, source: String, reason: String) =
        mapOf("status" to status, "source" to source, "reason" to reason)
}
