package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context

internal enum class AssistantPack {
    normal, serious, playful, affectionate, flirtatious, academic;
}

internal enum class AssistantEvent {
    sync_stale, study_changed, exam_changed, study_and_exam_changed,
    exam_in_days, exam_tomorrow, exam_period_active,
    exam_notice,
}

/** The native workers use the same selection as Flutter's AssistantSelection. */
internal object AssistantText {
    fun selected(context: Context): AssistantPack {
        val stored = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.better_phenikaa_assistant_pack_v1", null)
        return AssistantPack.entries.firstOrNull { it.name == stored } ?: AssistantPack.normal
    }

    fun of(event: AssistantEvent, pack: AssistantPack, days: Int = 0, examCount: Int = 1): String {
        // Missing pack entries intentionally fall back to the normal wording.
        return when (event) {
            AssistantEvent.sync_stale -> "Bạn nên đồng bộ lại để đảm bảo tính chính xác của dữ liệu."
            AssistantEvent.study_changed -> "Lịch học đã thay đổi. Mở ứng dụng để xem chi tiết."
            AssistantEvent.exam_changed -> "Lịch thi đã thay đổi. Mở ứng dụng để xem chi tiết."
            AssistantEvent.study_and_exam_changed ->
                "Lịch học và lịch thi đã thay đổi. Mở ứng dụng để xem chi tiết."
            AssistantEvent.exam_in_days ->
                if (examCount > 1) "$days ngày nữa bạn có $examCount môn thi."
                else "$days ngày nữa bạn có một môn thi."
            AssistantEvent.exam_tomorrow ->
                if (examCount > 1) "Ngày mai bạn có $examCount môn thi."
                else "Ngày mai bạn có một môn thi."
            AssistantEvent.exam_period_active ->
                "Bạn đang trong kỳ thi. Hãy vào Lịch thi để kiểm tra."
            AssistantEvent.exam_notice ->
                "Bạn có $examCount thay đổi lịch thi. Mở lịch thi để kiểm tra."
        }
    }

    fun titleOf(event: AssistantEvent, pack: AssistantPack): String = when (event) {
        AssistantEvent.sync_stale -> "Đã lâu chưa đồng bộ"
        AssistantEvent.study_changed, AssistantEvent.exam_changed,
        AssistantEvent.study_and_exam_changed, AssistantEvent.exam_notice ->
            "Lịch học kỳ thay đổi"
        AssistantEvent.exam_in_days, AssistantEvent.exam_tomorrow -> "Nhắc lịch thi"
        AssistantEvent.exam_period_active -> "Lịch thi"
    }
}
