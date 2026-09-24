package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.text.SimpleDateFormat
import java.util.Locale

class ExamReminderPlannerTest {
    private fun semester(date: String = "2026-12-10T08:00:00.000", room: String = "C3") = """
        {"subjects":[{"subjectId":"stable","name":"Thiết kế web nâng cao",
        "examSchedules":[{"id":"exam","startAt":"$date","endAt":"2026-12-10T10:00:00.000",
        "room":"$room","className":"WEB-2026-LT","examForm":""}]}]}
    """.trimIndent()

    private val now = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse("2026-12-01")!!.time

    @Test fun firstAndIdenticalSyncDoNotDuplicateReminders() {
        val first = ExamReminderPlanner.plan(semester(), now, emptySet(), emptySet())
        assertEquals(listOf(7, 3, 1), first.schedule.map { it.daysBefore })
        val keys = first.schedule.map { it.key }.toSet()
        val repeated = ExamReminderPlanner.plan(semester(), now, keys, emptySet())
        assertTrue(repeated.schedule.isEmpty())
        assertTrue(repeated.cancel.isEmpty())
    }

    @Test fun aMovedOrCancelledExamCancelsAllOldReminders() {
        val original = ExamReminderPlanner.plan(semester(), now, emptySet(), emptySet())
        val keys = original.schedule.map { it.key }.toSet()
        val moved = ExamReminderPlanner.plan(semester("2026-12-15T09:00:00.000"), now, keys, emptySet())
        assertEquals(keys, moved.cancel)
        assertEquals(3, moved.schedule.size)
        val cancelled = ExamReminderPlanner.plan("""{"subjects":[]}""", now, keys, emptySet())
        assertEquals(keys, cancelled.cancel)
    }

    @Test fun deliveredMilestoneIsNeverScheduledAgain() {
        val first = ExamReminderPlanner.plan(semester(), now, emptySet(), emptySet())
        val delivered = setOf(first.schedule.first().key)
        val repeated = ExamReminderPlanner.plan(semester(), now, emptySet(), delivered)
        assertEquals(2, repeated.schedule.size)
    }
}
