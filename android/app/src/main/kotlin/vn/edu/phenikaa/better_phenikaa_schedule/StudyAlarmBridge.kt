package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.AlarmClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

// Delegates to the device's real Clock app. BPA never schedules its own alarm.
internal object StudyAlarmBridge {
    private const val CHANNEL = "better_phenikaa/study_alarm"

    fun attach(activity: Activity, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "setAlarm") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val hour = call.argument<Int>("hour")
            val minute = call.argument<Int>("minute")
            if (hour == null || hour !in 0..23 || minute == null || minute !in 0..59) {
                result.error("invalid_time", "Giờ báo thức không hợp lệ.", null)
                return@setMethodCallHandler
            }
            val label = (call.argument<String>("label") ?: "BPA - Lịch học")
                .take(120)
            val request = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_MESSAGE, label)
                // Request no Clock editor or navigation. Some OEM clocks may
                // deviate from the platform contract; verify on the device.
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
            }
            try {
                activity.startActivity(request)
                // This confirms Android accepted the Intent dispatch, not that
                // a third-party Clock has persisted the alarm.
                result.success(true)
            } catch (_: ActivityNotFoundException) {
                result.error("no_clock", "Không tìm thấy ứng dụng Đồng hồ.", null)
            } catch (error: SecurityException) {
                result.error("clock_denied", error.message ?: "Đồng hồ từ chối yêu cầu.", null)
            } catch (error: Exception) {
                result.error("clock_failed", error.message ?: "Không thể gửi lệnh báo thức.", null)
            }
        }
    }
}
