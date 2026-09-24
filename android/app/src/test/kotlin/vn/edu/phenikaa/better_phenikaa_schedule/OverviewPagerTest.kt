package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Test

class OverviewPagerTest {
    private fun items(count: Int): List<WidgetClass> = (0 until count).map { index ->
        WidgetClass(
            id = "$index",
            subject = "Môn $index",
            room = "A$index",
            time = "07:00 - 09:00",
            startAt = "2026-09-23T07:00:00",
            endAt = "2026-09-23T09:00:00",
            dateKey = "2026-09-23",
        )
    }

    @Test fun everySubjectIsVisibleExactlyOnceAcrossPages() {
        for (height in listOf(160, 240, 360, 424, 540)) {
            val size = OverviewPager.pageSize(height)
            for (count in listOf(0, 1, 2, 4, 5, 6, 17, 101)) {
                val source = items(count)
                val pages = (0..OverviewPager.lastPage(count, size)).flatMap { page ->
                    OverviewPager.visible(source, page, size)
                }
                assertEquals(source, pages)
                assertEquals(0, OverviewPager.clamp(-1, count, size))
                assertEquals(
                    OverviewPager.lastPage(count, size),
                    OverviewPager.clamp(Int.MAX_VALUE, count, size),
                )
            }
        }
    }

    @Test fun fiveCompactRowsFitTheLargeWidgetAndTheLastPageNeverLoops() {
        assertEquals(1, OverviewPager.pageSize(160))
        assertEquals(5, OverviewPager.pageSize(424))
        assertEquals(listOf("5", "6"), OverviewPager.visible(items(7), 1, 5).map { it.id })
        assertEquals(1, OverviewPager.clamp(50, 7, 5))
    }
}
