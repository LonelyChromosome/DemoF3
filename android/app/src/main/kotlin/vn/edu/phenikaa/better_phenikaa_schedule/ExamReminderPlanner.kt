package vn.edu.phenikaa.better_phenikaa_schedule

import org.json.JSONObject
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

internal data class PlannedExamReminder(
    val key: String,
    val subject: String,
    val daysBefore: Int,
    val atMillis: Long,
)

internal data class ExamReminderPlan(
    val schedule: List<PlannedExamReminder>,
    val cancel: Set<String>,
)

internal object ExamReminderPlanner {
    fun plan(
        semesterJson: String,
        nowMillis: Long,
        scheduled: Set<String>,
        delivered: Set<String>,
    ): ExamReminderPlan {
        val semester = JSONObject(semesterJson)
        val subjects = semester.getJSONArray("subjects")
        val future = LinkedHashMap<String, PlannedExamReminder>()
        for (subjectIndex in 0 until subjects.length()) {
            val subject = subjects.getJSONObject(subjectIndex)
            val subjectId = subject.getString("subjectId")
            val name = subject.getString("name")
            val exams = subject.getJSONArray("examSchedules")
            for (examIndex in 0 until exams.length()) {
                val exam = exams.getJSONObject(examIndex)
                val startAt = exam.getString("startAt")
                require(startAt.length >= 16) { "Lịch thi thiếu ngày giờ." }
                val start = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.US).apply {
                    isLenient = false
                }.parse(startAt.take(16)) ?: throw IllegalArgumentException("Ngày thi không hợp lệ.")
                val identity = listOf(
                    subjectId, exam.getString("id"), startAt, exam.getString("endAt"),
                    exam.optString("room"), exam.optString("className"), exam.optString("examForm"),
                ).joinToString("|")
                for (days in listOf(7, 3, 1)) {
                    val calendar = Calendar.getInstance().apply {
                        time = start
                        add(Calendar.DAY_OF_YEAR, -days)
                    }
                    if (calendar.timeInMillis <= nowMillis) continue
                    val key = sha256("$identity|$days")
                    if (key in delivered) continue
                    future[key] = PlannedExamReminder(key, name, days, calendar.timeInMillis)
                }
            }
        }
        return ExamReminderPlan(
            future.values.filter { it.key !in scheduled },
            scheduled - future.keys,
        )
    }

    private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) }
}
