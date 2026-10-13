package vn.edu.phenikaa.better_phenikaa_schedule

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BpaVerifiedAttendanceFilterTest {
    private fun registration(): String {
        val classes = JSONArray()
        for (type in listOf("LT5", "TH5")) {
            classes.put(JSONObject()
                .put("name", "Kỹ thuật phần mềm-1-1-26(COUR02.$type)")
                .put("startsOn", "2026-08-17")
                .put("endsOn", "2026-11-01"))
        }
        return JSONObject()
            .put("id", "2026_2027_1")
            .put("name", "2026_2027_1")
            .put("subjects", JSONArray().put(JSONObject()
                .put("name", "Kỹ thuật phần mềm")
                .put("classes", classes)))
            .toString()
    }

    private fun row(type: String, room: String): JSONObject {
        return JSONObject()
            .put("PHANLOAI", "LICHHOC")
            .put("TENHOCPHAN", "Môn Kỹ thuật phần mềm-1-1-26(COUR02.$type)")
            .put("TENLOPHOCPHAN", "Kỹ thuật phần mềm-1-1-26(COUR02.$type)")
            .put("NGAYHOC", "23/09/2026")
            .put("GIOBATDAU", 7)
            .put("PHUTBATDAU", 0)
            .put("GIOKETTHUC", 9)
            .put("PHUTKETTHUC", 0)
            .put("PHONGHOC_TEN", room)
            .put("SOTIET", 3)
            .put("THONGTINCHUYENCAN", "Vắng mặt(3)")
    }

    private fun envelope(rows: JSONArray): String {
        return JSONObject().put("name", "Sinh viên").put(
            "response", JSONObject().put("Success", true).put("Data", rows),
        ).toString()
    }

    @Test fun filtersOnlyNativeVerifiedRowsWithoutChangingScheduleSnapshot() {
        val raw = envelope(JSONArray()
            .put(row("LT5", "A1"))
            .put(row("TH5", "A2")))
        val verified = NativeSemesterVerifier.verify(raw, registration(), "")
        val timetable = verified.appSnapshot
        val filtered = JSONObject(BpaVerifiedAttendanceFilter.fromVerifiedEnvelope(
            raw, timetable,
        )).getJSONObject("response").getJSONArray("Data")
        assertEquals(2, filtered.length())
        assertEquals("LT", filtered.getJSONObject(0).getString("THUOCTINH_TEN"))
        assertEquals("TH", filtered.getJSONObject(1).getString("THUOCTINH_TEN"))
        assertEquals(2, JSONObject(timetable).getJSONArray("records").length())
        assertFalse(timetable.contains("THONGTINCHUYENCAN"))
        // A later forged/unregistered lesson cannot join the filtered result,
        // even when QLĐT returns it alongside two authorised classes.
        val extra = envelope(JSONArray()
            .put(row("LT5", "A1"))
            .put(row("TH5", "A2"))
            .put(row("TH4", "A3")))
        val limited = JSONObject(BpaVerifiedAttendanceFilter.fromVerifiedEnvelope(
            extra, timetable,
        )).getJSONObject("response").getJSONArray("Data")
        assertEquals(2, limited.length())
        assertTrue(limited.getJSONObject(0).getString("ID").startsWith("class|"))
    }

    @Test fun doesNotInferTHFromVietnameseWordsOrMissingTypeLabel() {
        val json = JSONObject()
            .put("records", JSONArray().put(
                JSONObject().put("id",
                    "class|23/09/2026|Thiết kế web nâng cao|7:0|B1|WEB-2026")
                    .put("isExam", false),
            )).toString()
        val raw = envelope(JSONArray().put(
            row("LT5", "B1")
                .put("TENHOCPHAN", "Thiết kế web nâng cao")
                .put("TENLOPHOCPHAN", "WEB-2026")
                .remove("THUOCTINH_TEN"),
        ))
        val filtered = JSONObject(BpaVerifiedAttendanceFilter.fromVerifiedEnvelope(
            raw, json,
        )).getJSONObject("response").getJSONArray("Data")
        assertEquals(1, filtered.length())
        assertEquals("LT", filtered.getJSONObject(0).getString("THUOCTINH_TEN"))
    }
}
