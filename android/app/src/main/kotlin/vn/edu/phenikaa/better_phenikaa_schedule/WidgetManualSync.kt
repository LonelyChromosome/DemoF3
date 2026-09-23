package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf

internal object WidgetManualSync {
    fun request(context: Context) {
        val work = OneTimeWorkRequestBuilder<QldtDailySyncWorker>()
            .setInputData(workDataOf("manual" to true))
            .build()
        WorkManager.getInstance(context.applicationContext)
            .enqueueUniqueWork("better_phenikaa_widget_reload", ExistingWorkPolicy.KEEP, work)
    }
}
