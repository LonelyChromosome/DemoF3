package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context

internal object SmallWidgetMode {
    private const val PREFS = "better_phenikaa_small_widget_mode"

    fun isExam(context: Context, widgetId: Int): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean("exam_$widgetId", false)

    fun toggle(context: Context, widgetId: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("exam_$widgetId", !isExam(context, widgetId))
            .apply()
    }

    fun clear(context: Context, widgetId: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove("exam_$widgetId").apply()
    }
}
