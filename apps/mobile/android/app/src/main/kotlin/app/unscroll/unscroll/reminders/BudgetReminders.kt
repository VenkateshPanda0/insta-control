package app.unscroll.unscroll.reminders

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import app.unscroll.unscroll.R
import app.unscroll.unscroll.permissions.PermissionGateway
import app.unscroll.unscroll.usage.UsageReader
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZonedDateTime
import java.util.concurrent.TimeUnit

/**
 * Runs the plan compiled by the Dart rule engine: daily budget reminders and
 * quiet-hours reminders. A periodic background check compares measured usage
 * with the plan and posts at most one notification per app per day (budgets)
 * or per rule per window (quiet hours). This reminds; it does not block.
 */
object BudgetReminders {
    private const val PREFS = "unscroll_budgets"
    private const val KEY_PLAN = "plan"
    private const val KEY_NOTIFIED_DAY = "notified_day"
    private const val KEY_NOTIFIED = "notified"
    private const val KEY_NOTIFIED_WINDOWS = "notified_windows"
    private const val WORK_NAME = "budget-check"
    private const val SESSION_WORK = "session-end"
    private const val CHANNEL = "budgets"
    private const val FOCUS_CHANNEL = "focus"

    /** @param plan {day, today: {budgets, windows}, base: {budgets, windows}} */
    fun sync(context: Context, plan: Map<String, Any?>) {
        val json = JSONObject(plan)
        prefs(context).edit().putString(KEY_PLAN, json.toString()).apply()
        val work = WorkManager.getInstance(context)
        val base = json.optJSONObject("base")
        val today = json.optJSONObject("today")
        val empty = listOf(base, today).all {
            it == null || ((it.optJSONObject("budgets")?.length() ?: 0) == 0 &&
                (it.optJSONArray("windows")?.length() ?: 0) == 0)
        }
        if (empty) {
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
        val plan = JSONObject(prefs.getString(KEY_PLAN, "{}") ?: "{}")
        val today = LocalDate.now().toString()
        // Pauses and extensions are only valid on the day they were compiled for.
        val body = (if (plan.optString("day") == today) plan.optJSONObject("today") else null)
            ?: plan.optJSONObject("base") ?: return
        val reader = UsageReader(context)

        // Daily budgets.
        val budgets = body.optJSONObject("budgets") ?: JSONObject()
        if (budgets.length() > 0) {
            val notified = if (prefs.getString(KEY_NOTIFIED_DAY, null) == today) {
                HashSet(prefs.getStringSet(KEY_NOTIFIED, emptySet()) ?: emptySet())
            } else {
                HashSet()
            }
            val usage = reader.todayByPackage()
            for (pkg in budgets.keys()) {
                val budget = budgets.getJSONObject(pkg)
                val minutes = budget.getInt("minutes")
                // Keyed by limit, so "5 more minutes" earns one more reminder.
                val key = "$pkg@$minutes"
                if (key in notified || (usage[pkg] ?: 0L) / 60_000 < minutes) continue
                val label = budget.optString("label", pkg)
                notify(
                    context, CHANNEL, "Budget reminders", pkg.hashCode(),
                    "$label budget reached", "You've used $label for $minutes minutes today.",
                )
                notified.add(key)
            }
            prefs.edit().putString(KEY_NOTIFIED_DAY, today).putStringSet(KEY_NOTIFIED, notified).apply()
        }

        // Quiet hours.
        val windows = body.optJSONArray("windows") ?: return
        val now = ZonedDateTime.now()
        val cutoff = now.minusDays(2).toInstant().toEpochMilli()
        val seen = HashSet(
            (prefs.getStringSet(KEY_NOTIFIED_WINDOWS, emptySet()) ?: emptySet())
                .filter { (it.substringAfterLast('@').toLongOrNull() ?: 0L) > cutoff },
        )
        for (i in 0 until windows.length()) {
            val window = windows.getJSONObject(i)
            val days = window.getJSONArray("days").let { a -> (0 until a.length()).map { a.getInt(it) }.toSet() }
            val start = WindowMath.activeStart(days, window.getInt("start"), window.getInt("end"), now)
                ?: continue
            val startMs = start.toInstant().toEpochMilli()
            val key = "${window.getString("id")}@$startMs"
            if (key in seen) continue
            val apps = window.getJSONObject("apps")
            val usage = reader.usageSince(startMs)
            val used = apps.keys().asSequence()
                .filter { (usage[it] ?: 0L) >= 60_000 }
                .map { apps.getString(it) }
                .toList()
            if (used.isEmpty()) continue
            notify(
                context, CHANNEL, "Budget reminders", key.hashCode(),
                "Quiet hours", "You planned to stay off ${used.joinToString(", ")} right now.",
            )
            seen.add(key)
        }
        prefs.edit().putStringSet(KEY_NOTIFIED_WINDOWS, seen).apply()
    }

    /** One notification when a focus session's time is up. Timing is approximate. */
    fun scheduleSessionEnd(context: Context, atMs: Long, title: String) {
        val delay = (atMs - System.currentTimeMillis()).coerceAtLeast(0)
        WorkManager.getInstance(context).enqueueUniqueWork(
            SESSION_WORK,
            ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<SessionEndWorker>()
                .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                .setInputData(Data.Builder().putString("title", title).build())
                .build(),
        )
    }

    fun cancelSessionEnd(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(SESSION_WORK)
    }

    fun notifySessionEnd(context: Context, title: String) {
        if (!canNotify(context)) return
        notify(context, FOCUS_CHANNEL, "Focus sessions", 7001, title, "Open Unscroll to see your session.")
    }

    private fun canNotify(context: Context): Boolean {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!manager.areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun notify(
        context: Context, channel: String, channelName: String, id: Int, title: String, text: String,
    ) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(channel, channelName, NotificationManager.IMPORTANCE_DEFAULT),
        )
        val notification = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
            .build()
        manager.notify(id, notification)
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

class BudgetWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        try {
            BudgetReminders.check(applicationContext)
        } catch (e: Exception) {
            // Permission revoked or usage records unavailable: try again next period.
        }
        return Result.success()
    }
}

class SessionEndWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        BudgetReminders.notifySessionEnd(
            applicationContext, inputData.getString("title") ?: "Focus session finished",
        )
        return Result.success()
    }
}
