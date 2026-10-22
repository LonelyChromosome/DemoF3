package vn.edu.phenikaa.better_phenikaa_schedule.findbike

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings

/** Permission state is independent of opt-in and timetable availability. */
object VehiclePermissions {
    private fun granted(context: Context, permission: String) =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    fun runtime(context: Context): Array<String> = buildList {
        if (!granted(context, Manifest.permission.ACCESS_FINE_LOCATION)) {
            // Request coarse + fine together, including after an approximate-only grant.
            add(Manifest.permission.ACCESS_FINE_LOCATION)
            add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        if (Build.VERSION.SDK_INT >= 29 && !granted(context, Manifest.permission.ACTIVITY_RECOGNITION))
            add(Manifest.permission.ACTIVITY_RECOGNITION)
        if (Build.VERSION.SDK_INT >= 33 && !granted(context, Manifest.permission.POST_NOTIFICATIONS))
            add(Manifest.permission.POST_NOTIFICATIONS)
    }.toTypedArray()
    fun snapshot(context: Context): Map<String, Any> = mapOf(
        "motion" to (Build.VERSION.SDK_INT < 29 || granted(context, Manifest.permission.ACTIVITY_RECOGNITION)),
        "notifications" to (Build.VERSION.SDK_INT < 33 || granted(context, Manifest.permission.POST_NOTIFICATIONS)),
        "setupSeen" to context.getSharedPreferences("bpa_vehicle_demo_v1", 0).getBoolean("permissionSetupSeen", false)
    )
    fun markSeen(context: Context) {
        context.getSharedPreferences("bpa_vehicle_demo_v1", 0).edit().putBoolean("permissionSetupSeen", true).apply()
    }
    fun appSettings(context: Context) = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        Uri.parse("package:" + context.packageName))
    fun notificationSettings(context: Context): Intent =
        if (Build.VERSION.SDK_INT >= 30) Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
            .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                ComponentName(context, VehicleExitNotificationListener::class.java).flattenToString())
        else Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
}
