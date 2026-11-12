package app.unscroll.unscroll.apps

import android.content.Context
import android.content.Intent

/** Apps the user can open from the launcher, excluding Unscroll itself. */
class InstalledApps(private val context: Context) {

    /** package name -> display name */
    fun labels(): Map<String, String> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .asSequence()
            .map { it.activityInfo }
            .filter { it.packageName != context.packageName }
            .associate { it.packageName to it.applicationInfo.loadLabel(pm).toString() }
    }

    fun list(): List<Map<String, String>> = labels().entries
        .sortedBy { it.value.lowercase() }
        .map { mapOf("package" to it.key, "label" to it.value) }
}
