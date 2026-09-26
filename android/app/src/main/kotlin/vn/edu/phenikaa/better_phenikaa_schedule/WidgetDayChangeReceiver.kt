package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** An explicit one-shot midnight alarm survives background broadcast restrictions. */
class WidgetDayChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val appContext = context.applicationContext
        scheduleNext(appContext)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val state = appContext.getSharedPreferences("better_phenikaa_widget_day", Context.MODE_PRIVATE)
        val previous = state.getString("last_day", null)
        if (intent?.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            WidgetRefreshDecision.dayChanged(previous, today)) {
            WidgetRefreshCoordinator.refreshToday(appContext)
        } else {
            WidgetRefreshCoordinator.refreshData(appContext)
        }
        state.edit().putString("last_day", today).commit()
    }

    companion object {
        private const val ACTION_MIDNIGHT =
            "vn.edu.phenikaa.better_phenikaa_schedule.WIDGET_MIDNIGHT"

        internal fun nextMidnight(now: Calendar = Calendar.getInstance()): Long =
            (now.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis

        fun scheduleNext(context: Context) {
            val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pending = PendingIntent.getBroadcast(context, 0,
                Intent(context, WidgetDayChangeReceiver::class.java).setAction(ACTION_MIDNIGHT),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val target = nextMidnight()
            manager.cancel(pending)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !manager.canScheduleExactAlarms()) {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target, pending)
            } else {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target, pending)
                    } else {
                        manager.setExact(AlarmManager.RTC_WAKEUP, target, pending)
                    }
                } catch (_: SecurityException) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target, pending)
                    } else {
                        manager.set(AlarmManager.RTC_WAKEUP, target, pending)
                    }
                }
            }
        }
    }
}
