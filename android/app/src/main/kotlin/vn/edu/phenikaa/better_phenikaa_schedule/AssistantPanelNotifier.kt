package vn.edu.phenikaa.better_phenikaa_schedule

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Test-only heads-up mirror for the 18 assistant use cases.
 *
 * The public app never calls this object. The panel build uses it so every U
 * can be visually checked through the same Android heads-up notification
 * surface, even when the production use case normally belongs to an in-app
 * surface such as an empty state or sync banner.
 */
internal object AssistantPanelNotifier {
    private const val CHANNEL = "assistant_panel_heads_up_v1"
    private const val NOTIFICATION_BASE = 29_200

    fun publish(context: Context, useCase: Int): Boolean {
        if (useCase !in 1..18) return false
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }

        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL,
                "Kiểm tra trợ lí",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Thông báo kiểm tra 18 use case trợ lí"
                enableVibration(true)
            }
            manager.createNotificationChannel(channel)
        }

        val pack = AssistantText.selected(context)
        val template = AssistantCatalog.texts[pack.name]?.get(useCase)
            ?: AssistantCatalog.texts.getValue(AssistantPack.normal.name).getValue(useCase)
        val message = when (useCase) {
            9 -> template.replaceFirst("X", "5")
            11 -> template.replaceFirst("X", "5").replaceFirst("N", "2")
            else -> template
        }
        val title = when (useCase) {
            1 -> "Đã lâu chưa đồng bộ"
            2, 12, 13, 17, 18 -> "Đồng bộ QLĐT"
            3, 4, 5, 14 -> "Lịch học kỳ thay đổi"
            6, 7, 8, 9, 11 -> "Nhắc lịch thi"
            10, 15 -> "Lịch thi"
            16 -> "Lịch học"
            else -> "Better Phenikaa"
        }

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pending = launch?.let {
            PendingIntent.getActivity(
                context,
                NOTIFICATION_BASE + useCase,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()

        manager.notify(NOTIFICATION_BASE + useCase, notification)
        return true
    }
}
