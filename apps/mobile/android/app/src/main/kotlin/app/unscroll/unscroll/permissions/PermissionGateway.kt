package app.unscroll.unscroll.permissions

import android.Manifest
import android.app.Activity
import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings

/** Reads real permission state from Android and starts the system flows to change it. */
class PermissionGateway(private val activity: Activity) {

    fun states(): Map<String, String> = mapOf(
        USAGE_ACCESS to if (hasUsageAccess()) GRANTED else DENIED,
        NOTIFICATIONS to notificationState(),
    )

    fun hasUsageAccess(): Boolean = hasUsageAccess(activity)

    fun notificationsEnabled(): Boolean {
        val manager = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.areNotificationsEnabled()
    }

    private fun notificationState(): String = when {
        notificationsEnabled() -> GRANTED
        needsRuntimePrompt() && !prefs().getBoolean(ASKED_NOTIFICATIONS, false) -> NOT_DETERMINED
        else -> DENIED
    }

    private fun needsRuntimePrompt() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU

    private fun prefs() = activity.getSharedPreferences("unscroll_native", Context.MODE_PRIVATE)

    /**
     * Returns an outcome immediately, or null when a runtime prompt was shown
     * and the answer will arrive in [onRequestPermissionsResult].
     */
    fun request(permission: String?): Map<String, String>? = when (permission) {
        USAGE_ACCESS -> open(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        NOTIFICATIONS -> when {
            notificationsEnabled() -> mapOf("outcome" to "granted")
            needsRuntimePrompt() && !prefs().getBoolean(ASKED_NOTIFICATIONS, false) -> {
                prefs().edit().putBoolean(ASKED_NOTIFICATIONS, true).apply()
                activity.requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_REQUEST,
                )
                null
            }
            else -> open(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName),
            )
        }
        else -> mapOf("outcome" to "failed", "message" to "Unknown permission.")
    }

    fun outcomeFor(grantResults: IntArray): Map<String, String> =
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            mapOf("outcome" to "granted")
        } else {
            mapOf("outcome" to "denied")
        }

    private fun open(intent: Intent): Map<String, String> = try {
        activity.startActivity(intent)
        mapOf("outcome" to "openedSettings")
    } catch (e: Exception) {
        mapOf("outcome" to "failed", "message" to "Could not open system settings.")
    }

    companion object {
        fun hasUsageAccess(context: Context): Boolean {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName,
                )
            }
            return mode == AppOpsManager.MODE_ALLOWED
        }


        const val NOTIFICATION_REQUEST = 4101
        const val USAGE_ACCESS = "usageAccess"
        const val NOTIFICATIONS = "notifications"
        private const val GRANTED = "granted"
        private const val DENIED = "denied"
        private const val NOT_DETERMINED = "notDetermined"
        private const val ASKED_NOTIFICATIONS = "asked_notifications"
    }
}
