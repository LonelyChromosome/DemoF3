package vn.edu.phenikaa.better_phenikaa_schedule.findbike

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.SystemClock
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlin.math.max

/**
 * Event-driven Find My Bike:
 * - Waiting: local BPA timetable + entrance geofence
 * - Tracking: GPS and physical steps until bike is parked
 * - Parked: NO GPS, motion recognition or polling; waits for authenticated
 *   Phenikaa Uni "Xe ra cổng" Android notification.
 */
object VehicleLifecycle {
    val gates=arrayOf(
        doubleArrayOf(20.962668790883644,105.74871859259113),
        doubleArrayOf(20.959607109088672,105.74789745697416)
    )
        fun registerFences(context:Context) {
            if(!VehicleStore.isEnabled(context) ||
                context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED)return
            val fences=gates.mapIndexed {i,gate ->
                Geofence.Builder().setRequestId("bpa_vehicle_gate_"+i)
                    .setCircularRegion(gate[0],gate[1],100f)
                    .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
                    .setExpirationDuration(Geofence.NEVER_EXPIRE)
                    .setNotificationResponsiveness(4000).build()
            }
            val request=GeofencingRequest.Builder()
                .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                .addGeofences(fences).build()
            val pending=PendingIntent.getBroadcast(context,7819,
                Intent(context,VehicleFenceReceiver::class.java).setAction("bpa.vehicle.gate"),
                PendingIntent.FLAG_UPDATE_CURRENT or
                (if(Build.VERSION.SDK_INT>=31)PendingIntent.FLAG_MUTABLE else 0))
            try {
                LocationServices.getGeofencingClient(context).addGeofences(request,pending)
            } catch(_:SecurityException){}
        }
    fun armNext(context:Context){
        if(!VehicleStore.isEnabled(context))return
        val alarm=context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending=PendingIntent.getBroadcast(context,8221,
            Intent(context,VehicleScheduleReceiver::class.java)
                .setAction("bpa.vehicle.schedule"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarm.cancel(pending)
        // In PARKED state, notification listener alone handles RE-ARM.
        if(VehicleStore.hasParked(context))return
        if(VehicleStore.isTracking(context)&&!VehicleStore.activeWindows(context)){
            VehicleStore.expireUnparkedSession(context)
            context.stopService(Intent(context,VehicleCaptureService::class.java))
        }
        registerFences(context)
        if(VehicleStore.activeWindows(context))tryStartHere(context)
        val nextStart=VehicleStore.nextWaitStart(context)
        val nextEnd=VehicleStore.nextWindowExpiry(context)
        val next=listOfNotNull(nextStart,nextEnd).minOrNull()
        if(next!=null)
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,
                (next+1000L).coerceAtLeast(System.currentTimeMillis()+1000L),pending)
    }
    fun enter(context:Context){
        if(!VehicleStore.isEnabled(context)||VehicleStore.hasParked(context)||
            VehicleStore.isTracking(context)||!VehicleStore.inClassWindow(context))return
        if(context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED)return
        if(Build.VERSION.SDK_INT>=29 &&
            context.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)!=PackageManager.PERMISSION_GRANTED)return
        try{
            val intent=Intent(context,VehicleCaptureService::class.java).setAction("start")
            if(Build.VERSION.SDK_INT>=26)context.startForegroundService(intent)
            else context.startService(intent)
        }catch(_:Exception){}
    }
    fun tryStartHere(context:Context){
        if(!VehicleStore.activeWindows(context)||VehicleStore.hasParked(context)||
            VehicleStore.isTracking(context))return
        if(context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED)return
        try{
            LocationServices.getFusedLocationProviderClient(context)
                .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY,CancellationTokenSource().token)
                .addOnSuccessListener{loc->
                    if(loc!=null&&fresh(loc)&&loc.hasAccuracy()&&loc.accuracy<=45f&&
                        gates.any{gate->
                            val ref=Location("gate").apply{latitude=gate[0];longitude=gate[1]}
                            loc.distanceTo(ref)<=max(0f,100f-loc.accuracy)
                        })enter(context)
                }
        }catch(_:SecurityException){}
    }
    private fun fresh(location:Location):Boolean {
        val age=(SystemClock.elapsedRealtimeNanos()-location.elapsedRealtimeNanos)/1_000_000L
        return age in 0L..90_000L
    }
}
class VehicleScheduleReceiver:BroadcastReceiver(){
    override fun onReceive(context:Context,intent:Intent){
        if(intent.action=="bpa.vehicle.schedule")VehicleLifecycle.armNext(context)
    }
}
