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
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.WorkManager
import androidx.work.workDataOf
import java.util.concurrent.TimeUnit

internal object ExamReminderScheduler {
    private const val PREFS = "better_phenikaa_exam_reminders"
    private const val ACTIVE = "scheduled"
    private const val DELIVERED = "delivered"

    fun reconcile(context: Context, semesterJson: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val scheduled = prefs.getStringSet(ACTIVE, emptySet()).orEmpty().toSet()
        val delivered = prefs.getStringSet(DELIVERED, emptySet()).orEmpty().toSet()
        val plan = ExamReminderPlanner.plan(
            semesterJson, System.currentTimeMillis(), scheduled, delivered,
        )
        val next = (scheduled - plan.cancel) + plan.schedule.map { it.key }
        require(prefs.edit().putStringSet(ACTIVE, next).commit()) {
            "Không lưu được kế hoạch nhắc lịch thi."
        }
        val manager = WorkManager.getInstance(context)
        plan.cancel.forEach { manager.cancelUniqueWork(it) }
        plan.schedule.forEach { reminder ->
            val request = OneTimeWorkRequestBuilder<ExamReminderWorker>()
                .setInitialDelay(
                    (reminder.atMillis - System.currentTimeMillis()).coerceAtLeast(0L),
                    TimeUnit.MILLISECONDS,
                )
                .setInputData(workDataOf(
                    "key" to reminder.key,
                    "subject" to reminder.subject,
                    "days" to reminder.daysBefore,
                ))
                .build()
            manager.enqueueUniqueWork(reminder.key, ExistingWorkPolicy.KEEP, request)
        }
    }

    fun clear(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val keys = prefs.getStringSet(ACTIVE, emptySet()).orEmpty().toSet()
        prefs.edit().remove(ACTIVE).remove(DELIVERED).commit()
        keys.forEach { WorkManager.getInstance(context).cancelUniqueWork(it) }
    }

    fun deliver(context: Context, key: String, subject: String, days: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val active = prefs.getStringSet(ACTIVE, emptySet()).orEmpty().toSet()
        val delivered = prefs.getStringSet(DELIVERED, emptySet()).orEmpty().toSet()
        if (key !in active || key in delivered) return
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return
        if (!prefs.edit().putStringSet(DELIVERED, delivered + key)
                .putStringSet(ACTIVE, active - key).commit()) return
        val notifications = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notifications.createNotificationChannel(NotificationChannel(
                "exam_reminders", "Nhắc lịch thi", NotificationManager.IMPORTANCE_DEFAULT,
            ))
        }
        val openApp = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pending = openApp?.let {
            PendingIntent.getActivity(context, key.hashCode(), it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val notification = NotificationCompat.Builder(context, "exam_reminders")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Lịch thi sau $days ngày")
            .setContentText(subject)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        notifications.notify(key.hashCode(), notification)
    }
}

class ExamReminderWorker(context: Context, parameters: WorkerParameters) : Worker(context, parameters) {
    override fun doWork(): Result {
        val key = inputData.getString("key") ?: return Result.success()
        val subject = inputData.getString("subject") ?: return Result.success()
        val days = inputData.getInt("days", 0)
        if (days !in listOf(7, 3, 1)) return Result.success()
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return Result.retry()
        ExamReminderScheduler.deliver(applicationContext, key, subject, days)
        return Result.success()
    }
}
