package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Uses Android's date-change broadcast; no exact alarm or background loop. */
class WidgetDayChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val appContext = context.applicationContext
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val state = appContext.getSharedPreferences("better_phenikaa_widget_day", Context.MODE_PRIVATE)
        val previous = state.getString("last_day", null)
        state.edit().putString("last_day", today).apply()
        if (WidgetRefreshDecision.dayChanged(previous, today)) {
            WidgetRefreshCoordinator.refreshToday(appContext)
        } else {
            WidgetRefreshCoordinator.refreshData(appContext)
        }
    }
}
