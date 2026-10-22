package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.Notification
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.Locale

/** Only Android notifications from the official Phenikaa Uni app can re-arm REAL sessions. */
class VehicleExitNotificationListener:NotificationListenerService(){
    override fun onNotificationPosted(sbn:StatusBarNotification?){
        if(sbn!=null)process(applicationContext,sbn)
    }
    override fun onListenerConnected(){
        super.onListenerConnected()
        // Recover a delayed/unread exit notification if the listener reconnects.
        runCatching{activeNotifications?.forEach {process(applicationContext,it)}}
    }
    companion object {
        private const val PHENIKAA_PACKAGE="phx.smartschool.phenikaauniversity"
        private val platePattern=Regex("""\b\d{2}-[A-Z]{1,3}-\d{3,5}(?:\.\d{2})?\b""")
        private const val PREFS="bpa_vehicle_exit_notices_v1"
        fun hasPermission(context:Context):Boolean{
            val component=ComponentName(context,VehicleExitNotificationListener::class.java)
            if(Build.VERSION.SDK_INT>=27){
                val nm=context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                return nm.isNotificationListenerAccessGranted(component)
            }
            val value=Settings.Secure.getString(context.contentResolver,"enabled_notification_listeners")?:""
            return value.contains(component.flattenToString())
        }
        @Synchronized private fun process(context:Context,sbn:StatusBarNotification){
            if(sbn.packageName!=PHENIKAA_PACKAGE)return
            val extras=sbn.notification.extras
            val title=(extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?:"").trim()
            val text=(extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?:"")+
                " "+(extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?:"")
            val plate=platePattern.find(text.uppercase(Locale.ROOT))?.value
            val prefs=context.getSharedPreferences(PREFS,Context.MODE_PRIVATE)
            if(title.equals("Xe vào cổng",ignoreCase=true)){
                if(plate!=null)prefs.edit().putString("lastEntryPlate",plate).apply()
                return
            }
            if(!title.equals("Xe ra cổng",ignoreCase=true))return
            if(!VehicleStore.isEnabled(context)||!VehicleStore.hasParked(context))return
            val parkedAt=context.getSharedPreferences("bpa_vehicle_demo_v1",Context.MODE_PRIVATE)
                .getLong("parkedAt",0L)
            val now=System.currentTimeMillis()
            // Never unlock on stale notifications from an earlier parking session.
            if(parkedAt<=0L||sbn.postTime<parkedAt||sbn.postTime>now+60_000L||
                now-sbn.postTime>6L*60L*60_000L)return
            // If an entry plate was observed, the exit MUST match it.
            val expected=prefs.getString("lastEntryPlate",null)
            if(expected!=null && (plate==null||expected!=plate))return
            VehicleStore.rearmReal(context)
            prefs.edit().remove("lastEntryPlate")
                .putLong("lastConfirmedExit",now).apply()
            VehicleLifecycle.armNext(context)
        }
    }
}
