package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf

internal object WidgetManualSync {
    fun request(context: Context) {
        // A tap always repairs the visible widget immediately, even if the
        // network task is already running or eventually fails.
        WidgetRefreshCoordinator.manualRefresh(context.applicationContext)
        WidgetSyncIndicator.start(context.applicationContext)
        val work = OneTimeWorkRequestBuilder<QldtDailySyncWorker>()
            .setInputData(workDataOf("manual" to true))
            .build()
        WorkManager.getInstance(context.applicationContext)
            .enqueueUniqueWork("better_phenikaa_widget_reload", ExistingWorkPolicy.KEEP, work)
    }
}
