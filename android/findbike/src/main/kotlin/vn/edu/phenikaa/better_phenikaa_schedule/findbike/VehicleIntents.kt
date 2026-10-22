package vn.edu.phenikaa.better_phenikaa_schedule.findbike

import android.content.Context
import android.content.Intent

internal object VehicleIntents {
    fun openApp(context: Context): Intent =
        context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                .setPackage(context.packageName)
}
