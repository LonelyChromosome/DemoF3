package vn.edu.phenikaa.better_phenikaa_schedule

import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

/**
 * 1.7's optional native attendance view. It is fed ONLY rows already accepted
 * by NativeSemesterVerifier. It cannot enlarge or weaken the authoritative
 * subject/class/date comparison or change the v1.6 saved timetable snapshot.
 *
 * Preserve original TENHOCPHAN / TENLOPHOCPHAN long enough to identify TH
 * before widgetSubjectName strips QLĐT's component suffix.
 */
internal object BpaVerifiedAttendanceFilter {
    fun fromVerifiedEnvelope(rawEnvelope: String, verifiedAppSnapshot: String): String {
        val approved = JSONObject(verifiedAppSnapshot).getJSONArray("records")
        val acceptedIds = HashSet<String>()
        for (index in 0 until approved.length()) {
            val row = approved.getJSONObject(index)
            if (!row.optBoolean("isExam", false)) {
                acceptedIds.add(row.getString("id"))
            }
        }

        val envelope = JSONObject(rawEnvelope)
        val response = envelope.getJSONObject("response")
        require(response.optBoolean("Success", false)) {
            "QLĐT chưa xác nhận dữ liệu lịch."
        }
        val rows = response.getJSONArray("Data")
        val filtered = JSONArray()
        for (index in 0 until rows.length()) {
            val row = rows.optJSONObject(index) ?: continue
            if (row.optString("PHANLOAI").uppercase(Locale.ROOT) != "LICHHOC") continue
            val id = originalRecordId(row) ?: continue
            // Only a lesson whose FULL identifier survived native registration
            // verification may contribute to any student attendance total.
            if (id !in acceptedIds) continue

            val subject = row.optString("TENHOCPHAN")
            val className = row.optString("TENLOPHOCPHAN")
            val kind = classifyOriginal(
                subject, className, row.optString("THUOCTINH_TEN"),
                row.optString("PHONGHOC_TEN").ifBlank {
                    row.optString("TENPHONGHOC")
                },
            )
            // No personal identifiers/credentials or unrelated raw QLĐT data
            // are returned through the optional channel.
            val clean = JSONObject()
                .put("ID", id)
                .put("PHANLOAI", "LICHHOC")
                .put("TENHOCPHAN", subject)
                .put("TENLOPHOCPHAN", className)
                .put("THUOCTINH_TEN", kind)
                .put("NGAYHOC", row.optString("NGAYHOC"))
                .put("GIOBATDAU", row.opt("GIOBATDAU"))
                .put("PHUTBATDAU", row.opt("PHUTBATDAU"))
                .put("PHONGHOC_TEN", row.optString("PHONGHOC_TEN"))
                .put("TENPHONGHOC", row.optString("TENPHONGHOC"))
                .put("SOTIET", row.opt("SOTIET"))
                .put("TIETBATDAU", row.opt("TIETBATDAU"))
                .put("TIETKETTHUC", row.opt("TIETKETTHUC"))
                .put("THONGTINCHUYENCAN", row.opt("THONGTINCHUYENCAN"))
            filtered.put(clean)
        }
        return JSONObject().put(
            "response",
            JSONObject().put("Success", true).put("Data", filtered),
        ).toString()
    }

    private fun originalRecordId(item: JSONObject): String? {
        // Match the EXACT legacy QldtSnapshotEncoder ID construction. Do not
        // create an alternative fuzzy match that could admit another class.
        val subject = widgetSubjectName(item.optString("TENHOCPHAN"))
        val date = item.optString("NGAYHOC").trim()
        val rawClass = widgetClassName(item.optString("TENLOPHOCPHAN"))
        val startHour = numeric(item, "GIOBATDAU") ?: return null
        val startMinute = numeric(item, "PHUTBATDAU") ?: return null
        if (subject.isEmpty() || date.isEmpty() ||
            startHour !in 0..23 || startMinute !in 0..59) return null
        val room = item.optString("PHONGHOC_TEN").trim().ifEmpty {
            item.optString("TENPHONGHOC").trim()
        }
        return listOf(
            "class", date, subject, "$startHour:$startMinute", room, rawClass,
        ).joinToString("|")
    }

    private fun numeric(item: JSONObject, key: String): Int? {
        val raw = item.opt(key) ?: return null
        return when (raw) {
            is Int -> raw
            is Number -> raw.toInt()
            is String -> raw.trim().toIntOrNull()
            else -> null
        }
    }

    private val practiceCode = Regex(
        """(?:^|[\s.\-_/()])TH[0-9]*(?=$|[\s.\-_/()])""",
        RegexOption.IGNORE_CASE,
    )

    private val onlineCode = Regex(
        """(?:^|[\s.\-_/()])(?:ELN|ELEARNING|E-LEARNING)[0-9]*(?=$|[\s.\-_/()])""",
        RegexOption.IGNORE_CASE,
    )

    private fun classifyOriginal(
        rawSubject: String,
        rawClass: String,
        attribute: String,
        room: String,
    ): String {
        val attr = attribute.lowercase(Locale.ROOT)
        val location = room.lowercase(Locale.ROOT)
        if (listOf(attr, location, rawSubject.lowercase(Locale.ROOT),
                rawClass.lowercase(Locale.ROOT)).any {
                it.contains("elearning") || it.contains("e-learning") ||
                    it.contains("e learning")
            } || onlineCode.containsMatchIn(rawSubject) ||
            onlineCode.containsMatchIn(rawClass)) return "ELEARNING"
        if (practiceCode.containsMatchIn(rawSubject) ||
            practiceCode.containsMatchIn(rawClass) ||
            attr == "th" ||
            attr.contains("thực hành") ||
            attr.contains("thuc hanh")) return "TH"
        return "LT"
    }
}
