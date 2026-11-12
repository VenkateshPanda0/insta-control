package app.unscroll.unscroll.usage

import app.unscroll.unscroll.usage.ForegroundEvent.Kind.ALL_STOPPED
import app.unscroll.unscroll.usage.ForegroundEvent.Kind.PAUSED
import app.unscroll.unscroll.usage.ForegroundEvent.Kind.RESUMED
import org.junit.Assert.assertEquals
import org.junit.Test

class UsageAggregatorTest {
    private fun e(pkg: String, cls: String, kind: ForegroundEvent.Kind, t: Long) =
        ForegroundEvent(pkg, cls, kind, t)

    @Test
    fun sumsSeparateSessions() {
        val days = UsageAggregator.aggregate(
            listOf(
                e("a", "Main", RESUMED, 100), e("a", "Main", PAUSED, 400),
                e("b", "Main", RESUMED, 400), e("b", "Main", PAUSED, 500),
                e("a", "Main", RESUMED, 600), e("a", "Main", PAUSED, 650),
            ),
            dayStarts = listOf(0), now = 1000,
        )
        assertEquals(mapOf("a" to 350L, "b" to 100L), days[0])
    }

    @Test
    fun overlappingActivitiesInOneAppAreNotDoubleCountedOrCutShort() {
        // Second screen resumes before the first reports paused.
        val days = UsageAggregator.aggregate(
            listOf(
                e("a", "One", RESUMED, 100), e("a", "Two", RESUMED, 200),
                e("a", "One", PAUSED, 210), e("a", "Two", PAUSED, 500),
            ),
            dayStarts = listOf(0), now = 1000,
        )
        assertEquals(400L, days[0]["a"])
    }

    @Test
    fun sessionCrossingMidnightIsSplitBetweenDays() {
        val days = UsageAggregator.aggregate(
            listOf(e("a", "Main", RESUMED, 900), e("a", "Main", PAUSED, 1300)),
            dayStarts = listOf(0, 1000), now = 2000,
        )
        assertEquals(100L, days[0]["a"])
        assertEquals(300L, days[1]["a"])
    }

    @Test
    fun appStillOpenIsCountedUntilNow() {
        val days = UsageAggregator.aggregate(
            listOf(e("a", "Main", RESUMED, 700)), dayStarts = listOf(0), now = 1000,
        )
        assertEquals(300L, days[0]["a"])
    }

    @Test
    fun screenOffEndsOpenSessionsAndStrayPausesAreIgnored() {
        val days = UsageAggregator.aggregate(
            listOf(
                e("b", "Main", PAUSED, 50),
                e("a", "Main", RESUMED, 100),
                e("", "", ALL_STOPPED, 300),
                e("a", "Main", PAUSED, 900),
            ),
            dayStarts = listOf(0), now = 1000,
        )
        assertEquals(mapOf("a" to 200L), days[0])
    }
}
