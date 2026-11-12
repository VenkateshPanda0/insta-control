package app.unscroll.unscroll.usage

/** One foreground-related event, already reduced from Android's UsageEvents. */
data class ForegroundEvent(
    val packageName: String,
    val className: String,
    val kind: Kind,
    val timestamp: Long,
) {
    enum class Kind { RESUMED, PAUSED, ALL_STOPPED }
}

/**
 * Turns foreground events into time-in-foreground per app per day.
 * Pure Kotlin so it can be unit tested without a device.
 */
object UsageAggregator {

    /**
     * @param events sorted by timestamp.
     * @param dayStarts start of each local day, ascending. Day i runs from
     *   dayStarts[i] to dayStarts[i + 1]; the last day runs to [now].
     * @return for each day, a map of package name to milliseconds in foreground.
     */
    fun aggregate(
        events: List<ForegroundEvent>,
        dayStarts: List<Long>,
        now: Long,
    ): List<Map<String, Long>> {
        val days = List(dayStarts.size) { HashMap<String, Long>() }
        // package -> activities currently resumed; package -> when it came to front
        val active = HashMap<String, MutableSet<String>>()
        val openedAt = HashMap<String, Long>()

        fun close(pkg: String, end: Long) {
            val start = openedAt.remove(pkg) ?: return
            addInterval(days, dayStarts, now, pkg, start, end)
        }

        for (event in events) {
            when (event.kind) {
                ForegroundEvent.Kind.RESUMED -> {
                    val set = active.getOrPut(event.packageName) { HashSet() }
                    if (set.isEmpty()) openedAt[event.packageName] = event.timestamp
                    set.add(event.className)
                }
                ForegroundEvent.Kind.PAUSED -> {
                    val set = active[event.packageName] ?: continue
                    set.remove(event.className)
                    if (set.isEmpty()) close(event.packageName, event.timestamp)
                }
                ForegroundEvent.Kind.ALL_STOPPED -> {
                    for (pkg in openedAt.keys.toList()) close(pkg, event.timestamp)
                    active.clear()
                }
            }
        }
        // Whatever is still in front is counted up to now.
        for (pkg in openedAt.keys.toList()) close(pkg, now)
        return days
    }

    private fun addInterval(
        days: List<HashMap<String, Long>>,
        dayStarts: List<Long>,
        now: Long,
        pkg: String,
        start: Long,
        end: Long,
    ) {
        for (i in dayStarts.indices) {
            val dayStart = dayStarts[i]
            val dayEnd = if (i + 1 < dayStarts.size) dayStarts[i + 1] else now
            val from = maxOf(start, dayStart)
            val to = minOf(end, dayEnd)
            if (to > from) days[i][pkg] = (days[i][pkg] ?: 0L) + (to - from)
        }
    }
}
