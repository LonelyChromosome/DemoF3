package vn.edu.phenikaa.better_phenikaa_schedule

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class NativeSemesterVerifierTest {
    private val registration = """
        {"id":"2026_2027_1","name":"2026_2027_1","subjects":[
          {"name":"Thiết kế web nâng cao","classes":[
            {"name":"WEB-2026-LT","startsOn":"2026-08-17","endsOn":"2026-11-01"}
          ]},
          {"name":"Toán cao cấp","classes":[]}
        ]}
    """.trimIndent()

    private fun envelope(date: String = "23/09/2026", section: String = "WEB-2026-LT") = """
        {"name":"Sinh viên","response":{"Success":true,"Data":[
          {"PHANLOAI":"LICHHOC","TENHOCPHAN":"Thiết kế web nâng cao",
           "TENLOPHOCPHAN":"$section","NGAYHOC":"$date",
           "GIOBATDAU":7,"PHUTBATDAU":0,"GIOKETTHUC":9,"PHUTKETTHUC":0,
           "PHONGHOC_TEN":"A1"}
        ]}}
    """.trimIndent()

    @Test fun aRegisteredSubjectWithoutScheduleIsKept() {
        val result = NativeSemesterVerifier.verify(envelope(), registration, "")
        val semester = JSONObject(result.semester)
        val subjects = semester.getJSONArray("subjects")
        assertEquals(2, subjects.length())
        assertEquals(0, subjects.getJSONObject(1).getJSONArray("studySchedules").length())
        val subject = subjects.getJSONObject(0)
        val rawId = subject.getJSONArray("studySchedules").getJSONObject(0).getString("id")
        assertEquals(true, rawId.startsWith("class|"))
        assertEquals(1, JSONObject(result.widgetSnapshot).getJSONArray("classes").length())
    }

    @Test fun aSameNameOldClassCannotBeLinked() {
        assertThrows(IllegalArgumentException::class.java) {
            NativeSemesterVerifier.verify(envelope(section = "WEB-2025-LT"), registration, "")
        }
    }

    @Test fun aPartialResponseDoesNotOverwriteThePreviousSnapshot() {
        val malformed = envelope().replace("\"TENLOPHOCPHAN\":\"WEB-2026-LT\",", "")
        assertThrows(IllegalArgumentException::class.java) {
            NativeSemesterVerifier.verify(malformed, registration, "")
        }
    }
}
