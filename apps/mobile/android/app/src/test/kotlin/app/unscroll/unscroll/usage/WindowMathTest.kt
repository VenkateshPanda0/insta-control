package app.unscroll.unscroll.usage

import app.unscroll.unscroll.reminders.WindowMath
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime

class WindowMathTest {
    private val zone = ZoneId.of("Europe/London")
    private fun at(day: Int, hour: Int, minute: Int = 0) =
        ZonedDateTime.of(2026, 11, day, hour, minute, 0, 0, zone)
    private val weekdays = setOf(1, 2, 3, 4, 5)

    @Test
    fun sameDayWindow() {
        // 12 Nov 2026 is a Thursday.
        assertEquals(at(12, 9), WindowMath.activeStart(setOf(4), 540, 1020, at(12, 10)))
        assertNull(WindowMath.activeStart(setOf(4), 540, 1020, at(12, 17)))
        assertNull(WindowMath.activeStart(setOf(4), 540, 1020, at(13, 10)))
    }

    @Test
    fun overnightWindowBelongsToTheDayItStarts() {
        assertEquals(at(13, 23), WindowMath.activeStart(weekdays, 1380, 420, at(13, 23, 30)))
        assertEquals(at(13, 23), WindowMath.activeStart(weekdays, 1380, 420, at(14, 2)))
        assertNull(WindowMath.activeStart(weekdays, 1380, 420, at(14, 23, 30)))
        assertNull(WindowMath.activeStart(weekdays, 1380, 420, at(16, 2)))
        assertNull(WindowMath.activeStart(weekdays, 1380, 420, at(12, 12)))
    }
}
