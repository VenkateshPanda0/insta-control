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
        val usage = if (permissions.hasUsageAccess()) {
            entry(
                "supportedWithLimitations", "android",
                "Measured by Android. Covers apps you can open from the launcher; Android may " +
                    "keep less than seven days of history.",
            )
        } else {
            entry("requiresAuthorization", "none", "Allow usage access in Permissions to see your usage.")
        }
        val reminders = when {
            !permissions.hasUsageAccess() ->
                entry("requiresAuthorization", "none", "Needs usage access to know when a budget is reached.")
            !permissions.notificationsEnabled() ->
                entry("requiresAuthorization", "none", "Allow notifications in Permissions to get reminders.")
            else -> entry(
                "supportedWithLimitations", "android",
                "Android checks budgets in the background about every 15 minutes, and less often " +
                    "when saving battery, so a reminder can arrive late.",
            )
        }
        return mapOf(
            "usageReporting" to usage,
            "appSelection" to entry("supported", "none", "Shows apps you can open from the launcher."),
            "appBlocking" to entry(
                "unavailable", "android",
                "Android has no official app-blocking API for apps like Unscroll. The known " +
                    "workarounds (accessibility services, screen overlays) are restricted by " +
                    "Google Play policy, so Unscroll does not use them.",
            ),
            "scheduledRestrictions" to entry(
                "unavailable", "android", "Depends on app blocking, which Android does not offer.",
            ),
            "launchInterception" to entry(
                "unavailable", "android",
                "Android does not offer a supported way for a wellbeing app to step in " +
                    "whenever another app opens.",
            ),
            "inAppSectionControl" to entry(
                "unavailable", "thirdPartyApp",
                "Other apps do not let outside apps change or hide parts of their screens.",
            ),
            "reminders" to reminders,
            "focusSessions" to notBuilt("Focus sessions are not built into this version yet."),
        )
    }

    private fun notBuilt(reason: String) = entry("unavailable", "unscrollBuild", reason)

    private fun entry(status: String, source: String, reason: String) =
        mapOf("status" to status, "source" to source, "reason" to reason)
}
