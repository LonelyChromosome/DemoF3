package vn.edu.phenikaa.better_phenikaa_schedule

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject

/** A new exam stays visible until the student opens the exam page. */
internal object ExamChangeNotifier {
    private const val PREFS = "better_phenikaa_exam_changes"
    private const val MESSAGE = "message"
    private const val NOTIFIED = "notified"
    private const val INITIALIZED = "initialized"
    private const val CHANNEL = "new_exam_schedule"
    private const val NOTIFICATION_ID = 2817

    fun messageFor(semesterJson: String, differenceJson: String): String? {
        val difference = JSONObject(differenceJson)
        val count = if (difference.optBoolean("initial")) {
            val subjects = JSONObject(semesterJson).getJSONArray("subjects")
            (0 until subjects.length()).sumOf { index ->
                subjects.getJSONObject(index).getJSONArray("examSchedules").length()
            }
        } else {
            val exams = difference.getJSONObject("exams")
            exams.optInt("added") + exams.optInt("modified")
        }
        return if (count > 0) "Bạn có $count lịch thi mới. Mở lịch thi để kiểm tra." else null
    }

    fun record(context: Context, semesterJson: String, differenceJson: String) {
        val message = messageFor(semesterJson, differenceJson) ?: return
        if (!context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(MESSAGE, message).putBoolean(NOTIFIED, false)
                .putBoolean(INITIALIZED, true).commit()) return
        WidgetRefreshCoordinator.refreshData(context)
        publishPending(context)
    }

    fun pending(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(MESSAGE, null)

    fun recoverExisting(context: Context) {
        if (context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(INITIALIZED, false)) return
        val semester = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.better_phenikaa_current_semester_v1", null) ?: return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(INITIALIZED, true).commit()
        runCatching { record(context, semester, """{"initial":true}""") }
    }

    fun acknowledge(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove(MESSAGE).remove(NOTIFIED).putBoolean(INITIALIZED, true).apply()
        context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
        WidgetRefreshCoordinator.refreshData(context)
    }

    fun clear(context: Context) {
        acknowledge(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    fun publishPending(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val message = prefs.getString(MESSAGE, null) ?: return
        if (prefs.getBoolean(NOTIFIED, false)) return
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL, "Lịch thi mới", NotificationManager.IMPORTANCE_HIGH,
            ))
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val openApp = launch?.let {
            PendingIntent.getActivity(context, NOTIFICATION_ID, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        manager.notify(NOTIFICATION_ID, NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Bạn có lịch thi mới")
            .setContentText(message)
            .setAutoCancel(true)
            .setContentIntent(openApp)
            .build())
        prefs.edit().putBoolean(NOTIFIED, true).apply()
    }
}
