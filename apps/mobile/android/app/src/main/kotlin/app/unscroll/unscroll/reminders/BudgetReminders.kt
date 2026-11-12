package app.unscroll.unscroll.reminders

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import app.unscroll.unscroll.R
import app.unscroll.unscroll.permissions.PermissionGateway
import app.unscroll.unscroll.usage.UsageReader
import org.json.JSONObject
import java.time.LocalDate
import java.util.concurrent.TimeUnit

/**
 * Daily budget reminders. A periodic background check compares today's
 * measured usage with the budgets the user set and posts one notification per
 * app per day. This reminds; it does not block anything.
 */
object BudgetReminders {
    private const val PREFS = "unscroll_budgets"
    private const val KEY_BUDGETS = "budgets"
    private const val KEY_NOTIFIED_DAY = "notified_day"
    private const val KEY_NOTIFIED = "notified"
    private const val WORK_NAME = "budget-check"
    private const val CHANNEL = "budgets"

    /** @param budgets package -> {label, minutes} */
    fun sync(context: Context, budgets: Map<String, Map<String, Any?>>) {
        val json = JSONObject()
        for ((pkg, value) in budgets) {
            val minutes = (value["minutes"] as? Number)?.toInt() ?: continue
            if (minutes <= 0) continue
            json.put(
                pkg,
                JSONObject().put("label", value["label"] as? String ?: pkg).put("minutes", minutes),
            )
        }
        prefs(context).edit().putString(KEY_BUDGETS, json.toString()).apply()
        val work = WorkManager.getInstance(context)
        if (json.length() == 0) {
            work.cancelUniqueWork(WORK_NAME)
        } else {
            // 15 minutes is the shortest interval Android allows for periodic work.
            work.enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<BudgetWorker>(15, TimeUnit.MINUTES).build(),
            )
        }
    }

    fun check(context: Context) {
        if (!PermissionGateway.hasUsageAccess(context) || !canNotify(context)) return
        val prefs = prefs(context)
        val budgets = JSONObject(prefs.getString(KEY_BUDGETS, "{}") ?: "{}")
        if (budgets.length() == 0) return

        val today = LocalDate.now().toString()
        val notified = if (prefs.getString(KEY_NOTIFIED_DAY, null) == today) {
            HashSet(prefs.getStringSet(KEY_NOTIFIED, emptySet()) ?: emptySet())
        } else {
            HashSet()
        }
        val usage = UsageReader(context).todayByPackage()
        for (pkg in budgets.keys()) {
            if (pkg in notified) continue
            val budget = budgets.getJSONObject(pkg)
            val minutes = budget.getInt("minutes")
            val usedMinutes = (usage[pkg] ?: 0L) / 60_000
            if (usedMinutes < minutes) continue
            notify(context, pkg, budget.getString("label"), minutes)
            notified.add(pkg)
        }
        prefs.edit().putString(KEY_NOTIFIED_DAY, today).putStringSet(KEY_NOTIFIED, notified).apply()
    }

    private fun canNotify(context: Context): Boolean {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!manager.areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun notify(context: Context, pkg: String, label: String, minutes: Int) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Budget reminders", NotificationManager.IMPORTANCE_DEFAULT),
            )
        }
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("$label budget reached")
            .setContentText("You've used $label for $minutes minutes today.")
            .setAutoCancel(true)
            .build()
        manager.notify(pkg.hashCode(), notification)
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

class BudgetWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        return try {
            BudgetReminders.check(applicationContext)
            Result.success()
        } catch (e: Exception) {
            // Permission revoked or usage records unavailable: try again next period.
            Result.success()
        }
    }
}
