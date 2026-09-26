package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ExamChangeNotifierTest {
    private val semester = """{"subjects":[
        {"examSchedules":[{},{}]}, {"examSchedules":[]}
    ]}"""

    @Test fun firstVerifiedImportIsNotAChange() {
        assertNull(ExamChangeNotifier.messageFor(semester, """{"initial":true}"""))
    }

    @Test fun laterSyncSummarizesAnyExamChange() {
        assertEquals("Bạn có 2 thay đổi lịch thi. Mở lịch thi để kiểm tra.",
            ExamChangeNotifier.messageFor(semester,
                """{"initial":false,"exams":{"added":1,"modified":1,"removed":0}}"""))
        assertEquals("Bạn có 1 thay đổi lịch thi. Mở lịch thi để kiểm tra.",
            ExamChangeNotifier.messageFor(semester,
                """{"initial":false,"exams":{"added":0,"modified":0,"removed":1}}"""))
    }
}
