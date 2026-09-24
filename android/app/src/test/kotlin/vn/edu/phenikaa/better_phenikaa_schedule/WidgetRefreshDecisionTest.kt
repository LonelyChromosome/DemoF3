package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetRefreshDecisionTest {
    @Test fun widgetModesUseSeparateKeysPerWidgetId() {
        assertNotEquals(SmallWidgetMode.key(11), SmallWidgetMode.key(12))
        assertNotEquals(
            WidgetRefreshDecision.overviewModeKey(11),
            WidgetRefreshDecision.overviewModeKey(12),
        )
        assertNotEquals(
            WidgetRefreshDecision.overviewPageKey(11),
            WidgetRefreshDecision.overviewPageKey(12),
        )
    }

    @Test fun themeAndDataRefreshKeepTheSmallStackPosition() {
        assertFalse(WidgetRefreshDecision.resetSmallPosition(false, false))
        assertTrue(WidgetRefreshDecision.resetSmallPosition(true, false))
        assertTrue(WidgetRefreshDecision.resetSmallPosition(false, true))
    }

    @Test fun overviewRefreshKeepsPageUntilTheLastPageChanges() {
        assertEquals(1, WidgetRefreshDecision.overviewPage(1, 8, 5))
        assertEquals(0, WidgetRefreshDecision.overviewPage(1, 2, 5))
        assertEquals(0, WidgetRefreshDecision.overviewPage(0, 0, 5))
    }

    @Test fun nativeWidgetCourseLabelsKeepClassCodesAndDropAttendance() {
        assertEquals(
            "Phân tích và thiết kế phần mềm",
            widgetSubjectName("Môn Phân tích và thiết kế phần mềm-1-1-26(N08)"),
        )
        assertEquals(
            "Phân tích và thiết kế phần mềm-1-1-26(N08)",
            widgetClassName("Phân tích và thiết kế phần mềm-1-1-26(N08)<br>Vắng mặt<br>"),
        )
        assertNotEquals(
            widgetClassName("Kỹ thuật phần mềm-1-1-26(COUR02.LT5)<br>"),
            widgetClassName("Kỹ thuật phần mềm-1-1-26(COUR02)<br>"),
        )
    }

    @Test fun calendarDateIsPreservedUntilTheLocalDayChanges() {
        assertEquals("2026-09-25", WidgetRefreshDecision.selectedDate("2026-09-25", "2026-09-24"))
        assertEquals("2026-09-24", WidgetRefreshDecision.selectedDate("invalid", "2026-09-24"))
        assertFalse(WidgetRefreshDecision.dayChanged("2026-09-24", "2026-09-24"))
        assertTrue(WidgetRefreshDecision.dayChanged("2026-09-24", "2026-09-25"))
    }
}
