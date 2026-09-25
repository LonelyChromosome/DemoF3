package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ExamChangeNotifierTest {
    private val semester = """{"subjects":[
        {"examSchedules":[{},{}]}, {"examSchedules":[]}
    ]}"""

    @Test fun firstVerifiedImportAnnouncesExistingExams() {
        assertEquals("Bạn có 2 lịch thi mới. Mở lịch thi để kiểm tra.",
            ExamChangeNotifier.messageFor(semester, """{"initial":true}"""))
    }

    @Test fun laterSyncOnlyAnnouncesNewOrChangedExam() {
        assertEquals("Bạn có 2 lịch thi mới. Mở lịch thi để kiểm tra.",
            ExamChangeNotifier.messageFor(semester,
                """{"initial":false,"exams":{"added":1,"modified":1,"removed":0}}"""))
        assertNull(ExamChangeNotifier.messageFor(semester,
            """{"initial":false,"exams":{"added":0,"modified":0,"removed":1}}"""))
    }
}
