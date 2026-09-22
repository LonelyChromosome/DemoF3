package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.webkit.CookieManager
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.Calendar
import java.util.concurrent.TimeUnit

object DailySyncScheduler {
    fun enable(context: Context): Long {
        val appContext = context.applicationContext
        appContext.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(ENABLED_KEY, true)
            .apply()
        CookieManager.getInstance().flush()

        val initialDelayMillis = initialDelayUntilSixAm()
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = PeriodicWorkRequestBuilder<QldtDailySyncWorker>(
            REPEAT_INTERVAL_HOURS,
            TimeUnit.HOURS,
        )
            .setInitialDelay(initialDelayMillis, TimeUnit.MILLISECONDS)
            .setConstraints(constraints)
            .addTag(WORK_TAG)
            .build()

        WorkManager.getInstance(appContext).enqueueUniquePeriodicWork(
            UNIQUE_WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
        return initialDelayMillis
    }

    fun disable(context: Context) {
        val appContext = context.applicationContext
        appContext.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(ENABLED_KEY, false)
            .apply()
        WorkManager.getInstance(appContext).cancelUniqueWork(UNIQUE_WORK_NAME)
    }

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getBoolean(ENABLED_KEY, false)

    fun recordSuccess(context: Context, completedAtMillis: Long) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putLong(LAST_SUCCESS_KEY, completedAtMillis)
            .remove(LAST_ERROR_KEY)
            .apply()
    }

    fun recordFailure(context: Context, message: String) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(LAST_ERROR_KEY, message.take(MAX_ERROR_LENGTH))
            .apply()
    }

    internal fun initialDelayUntilSixAm(now: Calendar = Calendar.getInstance()): Long {
        val nextRun = now.clone() as Calendar
        nextRun.set(Calendar.HOUR_OF_DAY, SYNC_HOUR)
        nextRun.set(Calendar.MINUTE, 0)
        nextRun.set(Calendar.SECOND, 0)
        nextRun.set(Calendar.MILLISECOND, 0)
        if (!nextRun.after(now)) {
            nextRun.add(Calendar.DAY_OF_YEAR, 1)
        }
        return (nextRun.timeInMillis - now.timeInMillis).coerceAtLeast(0L)
    }

    private const val PREFERENCES = "better_phenikaa_daily_sync"
    private const val ENABLED_KEY = "enabled"
    private const val LAST_SUCCESS_KEY = "last_success"
    private const val LAST_ERROR_KEY = "last_error"
    private const val UNIQUE_WORK_NAME = "better_phenikaa_daily_qldt_sync"
    private const val WORK_TAG = "daily_qldt_sync"
    private const val SYNC_HOUR = 6
    private const val REPEAT_INTERVAL_HOURS = 24L
    private const val MAX_ERROR_LENGTH = 240
}
