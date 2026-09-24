package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf

internal object WidgetManualSync {
    const val WORK_NAME = "better_phenikaa_widget_reload"

    fun request(context: Context) {
        // A tap always repairs the visible widget immediately, even if the
        // network task is already running or eventually fails.
        val token = WidgetSyncIndicator.start(context.applicationContext)
        WidgetRefreshCoordinator.manualRefresh(context.applicationContext)
        val work = OneTimeWorkRequestBuilder<QldtDailySyncWorker>()
            .setInputData(workDataOf("manual" to true, "sync_token" to token))
            .build()
        WorkManager.getInstance(context.applicationContext)
            .enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.REPLACE, work)
    }
}
