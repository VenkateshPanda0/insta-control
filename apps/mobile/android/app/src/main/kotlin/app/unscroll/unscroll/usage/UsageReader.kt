package app.unscroll.unscroll.usage

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import app.unscroll.unscroll.apps.InstalledApps
import java.util.Calendar

/** Reads measured foreground time from Android's own usage records. */
class UsageReader(private val context: Context) {

    /** Local-midnight starts for the last [count] days, oldest first (handles DST). */
    private fun dayStarts(count: Int): List<Long> {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, -(count - 1))
        }
        return List(count) { cal.timeInMillis.also { cal.add(Calendar.DAY_OF_YEAR, 1) } }
    }

    private fun usageByDay(dayCount: Int): Pair<List<Long>, List<Map<String, Long>>> {
        val starts = dayStarts(dayCount)
        val now = System.currentTimeMillis()
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val raw = manager.queryEvents(starts.first(), now)
        val events = ArrayList<ForegroundEvent>()
        val event = UsageEvents.Event()
        while (raw.hasNextEvent()) {
            raw.getNextEvent(event)
            val kind = when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> ForegroundEvent.Kind.RESUMED
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED -> ForegroundEvent.Kind.PAUSED
                UsageEvents.Event.SCREEN_NON_INTERACTIVE,
                UsageEvents.Event.DEVICE_SHUTDOWN -> ForegroundEvent.Kind.ALL_STOPPED
                else -> continue
            }
            events.add(
                ForegroundEvent(event.packageName ?: "", event.className ?: "", kind, event.timeStamp),
            )
        }
        return starts to UsageAggregator.aggregate(events, starts, now)
    }

    /** Today's foreground milliseconds per package. */
    fun todayByPackage(): Map<String, Long> = usageByDay(1).second.first()

    /**
     * Seven days of totals plus today's per-app breakdown. Only apps the user
     * can open from the launcher are counted, and Unscroll itself is left out.
     */
    fun report(): Map<String, Any> {
        val labels = InstalledApps(context).labels()
        val (starts, days) = usageByDay(7)
        val dayList = starts.indices.map { i ->
            mapOf(
                "start" to starts[i],
                "totalMs" to days[i].filterKeys { it in labels }.values.sum(),
            )
        }
        val todayApps = days.last()
            .filterKeys { it in labels }
            .entries.sortedByDescending { it.value }
            .map { mapOf("package" to it.key, "label" to labels.getValue(it.key), "ms" to it.value) }
        return mapOf("days" to dayList, "todayApps" to todayApps)
    }
}
