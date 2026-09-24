package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetTimelineDateTest {
    private fun item(date: String) = WidgetClass(
        id = date, subject = "Môn học", room = "A6", time = "09:30 - 12:10",
        startAt = "${date}T09:30:00", endAt = "${date}T12:10:00", dateKey = date,
    )

    @Test fun newlyPlacedWidgetStartsAtSelectedDateAndKeepsUpcomingSwipeItems() {
        val visible = WidgetTimeline.fromDate(
            listOf(item("2026-08-17"), item("2026-09-25"), item("2026-09-28")),
            "2026-09-25",
        )
        assertEquals(listOf("2026-09-25", "2026-09-28"), visible.map { it.dateKey })
        assertEquals(0, WidgetTimeline.arrange(
            visible, "2026-09-25", "2026-09-25", "2026-09-25T08:00:00",
        ).selectedIndex)
    }

    @Test fun manuallyChosenPastDateIsStillAvailable() {
        assertEquals(listOf("2026-08-17", "2026-09-25"),
            WidgetTimeline.fromDate(listOf(item("2026-08-17"), item("2026-09-25")),
                "2026-08-17").map { it.dateKey })
    }

    @Test fun downwardSwipeFromTodayMovesToNextDayAndStopsAtEnd() {
        val ordered = WidgetTimeline.arrange(
            WidgetTimeline.fromDate(
                listOf(item("2026-09-24"), item("2026-09-25"), item("2026-10-31")),
                "2026-09-24",
            ),
            "2026-09-24", "2026-09-24", "2026-09-24T08:00:00",
        )
        val stack = WidgetTimeline.forDownwardSwipe(ordered)
        assertEquals(listOf("2026-10-31", "2026-09-25", "2026-09-24"),
            stack.items.map { it.dateKey })
        assertEquals(2, stack.selectedIndex)
        assertEquals("2026-09-25", stack.items[stack.selectedIndex - 1].dateKey)
        assertEquals("2026-10-31", stack.items.first().dateKey)
    }
}
