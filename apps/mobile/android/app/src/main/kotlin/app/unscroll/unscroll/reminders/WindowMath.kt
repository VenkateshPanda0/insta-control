package app.unscroll.unscroll.reminders

import java.time.ZonedDateTime

/** Pure schedule-window logic, mirrored by the Dart rule engine and unit tested. */
object WindowMath {
    /**
     * Start of the window instance containing [now], or null when outside it.
     * [days] uses 1 = Monday … 7 = Sunday and refers to the day the window
     * starts; a window whose end is not after its start runs past midnight.
     */
    fun activeStart(days: Set<Int>, start: Int, end: Int, now: ZonedDateTime): ZonedDateTime? {
        val minute = now.hour * 60 + now.minute
        val today = now.toLocalDate()
        fun at(daysBack: Long) =
            today.minusDays(daysBack).atTime(start / 60, start % 60).atZone(now.zone)
        if (start < end) {
            return if (minute in start until end && today.dayOfWeek.value in days) at(0) else null
        }
        if (minute >= start && today.dayOfWeek.value in days) return at(0)
        if (minute < end && today.minusDays(1).dayOfWeek.value in days) return at(1)
        return null
    }
}
