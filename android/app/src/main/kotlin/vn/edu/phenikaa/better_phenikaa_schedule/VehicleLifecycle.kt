package vn.edu.phenikaa.better_phenikaa_schedule

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
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlin.math.max

/**
 * Real session scheduling and RE-ARM. No timer for leaving school:
 * park -> confirmed vehicle activity -> outside both 100m entrance geofences.
 * Android may defer background geofence and activity callbacks.
 */
object VehicleLifecycle {
    val gates=arrayOf(
        doubleArrayOf(20.962668790883644,105.74871859259113),
        doubleArrayOf(20.959607109088672,105.74789745697416)
    )
    private const val PREF="vehicle_lifecycle_real_v1"
    private fun preferences(context:Context)=context.getSharedPreferences(PREF,Context.MODE_PRIVATE)
    private fun action(context:Context,code:Int,cls:Class<out BroadcastReceiver>,action:String):PendingIntent{
        val flags=PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        return PendingIntent.getBroadcast(context,code,Intent(context,cls).setAction(action),flags)
    }
    fun armNext(context:Context){
        if(!VehicleStore.isEnabled(context))return
        val alarm=context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending=action(context,8221,VehicleScheduleReceiver::class.java,"bpa.vehicle.schedule")
        alarm.cancel(pending)
        if(!VehicleStore.hasParked(context)){
            VehicleBridge.registerFences(context)
            if(VehicleStore.activeWindows(context))tryStartHere(context)
            VehicleStore.nextWaitStart(context)?.let { next ->
                // No exact-alarm special permission or manual scheduling required.
                alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,next,pending)
            }
        }else armMotion(context)
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
                .addOnSuccessListener { location ->
                    if(location!=null&&fresh(location)&&location.hasAccuracy()&&location.accuracy<=45f&&
                        gates.any{gate->
                            val ref=Location("gate").apply{latitude=gate[0];longitude=gate[1]}
                            location.distanceTo(ref)<=max(0f,100f-location.accuracy)
                        })enter(context)
                }
        }catch(_:SecurityException){}
    }
    private fun fresh(location:Location):Boolean {
        val age=(SystemClock.elapsedRealtimeNanos()-location.elapsedRealtimeNanos)/1_000_000L
        return age in 0L..90_000L
    }
    fun armMotion(context:Context){
        if(!VehicleStore.hasParked(context)||!VehicleStore.isEnabled(context))return
        if(Build.VERSION.SDK_INT>=29 &&
            context.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION)!=PackageManager.PERMISSION_GRANTED)return
        try{
            val pending=action(context,8222,VehicleMotionReceiver::class.java,"bpa.vehicle.motion")
            ActivityRecognition.getClient(context).requestActivityUpdates(12000L,pending)
        }catch(_:SecurityException){}
    }
    private fun disarmMotion(context:Context){
        try{
            val pending=action(context,8222,VehicleMotionReceiver::class.java,"bpa.vehicle.motion")
            ActivityRecognition.getClient(context).removeActivityUpdates(pending)
        }catch(_:Exception){}
    }
    fun clearVehicleMotion(context:Context){
        preferences(context).edit().remove("vehicleSince").apply()
    }
    fun recordVehicleMotion(context:Context,confidence:Int){
        if(!VehicleStore.hasParked(context)||confidence<70)return
        preferences(context).edit().putLong("vehicleSince",System.currentTimeMillis()).apply()
        maybeRearm(context,null)
    }
    fun maybeRearm(context:Context,observed:Location?){
        if(!VehicleStore.hasParked(context))return
        val recognized=preferences(context).getLong("vehicleSince",0)
        if(System.currentTimeMillis()-recognized !in 0L..180_000L)return
        if(observed!=null&&fresh(observed)){
            evaluate(context,observed)
            return
        }
        if(context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED)return
        try{
            LocationServices.getFusedLocationProviderClient(context)
                .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY,CancellationTokenSource().token)
                .addOnSuccessListener{loc->if(loc!=null)evaluate(context,loc)}
        }catch(_:SecurityException){}
    }
    private fun evaluate(context:Context,location:Location){
        if(!VehicleStore.hasParked(context)||!fresh(location)||
            !location.hasAccuracy()||location.accuracy>40f)return
        // An exit from one geofence isn't enough; user must be outside
        // both entrance zones with an accuracy margin.
        val outside=gates.all{gate->
            val ref=Location("gate").apply{latitude=gate[0];longitude=gate[1]}
            location.distanceTo(ref)>100f+location.accuracy
        }
        if(!outside)return
        val motion=preferences(context).getLong("vehicleSince",0L)
        if(System.currentTimeMillis()-motion !in 0L..180_000L)return
        VehicleStore.rearmReal(context)
        preferences(context).edit().remove("vehicleSince").apply()
        disarmMotion(context)
        armNext(context)
    }
}
class VehicleScheduleReceiver:BroadcastReceiver(){
    override fun onReceive(context:Context,intent:Intent){
        if(intent.action=="bpa.vehicle.schedule")VehicleLifecycle.armNext(context)
    }
}
class VehicleMotionReceiver:BroadcastReceiver(){
    override fun onReceive(context:Context,intent:Intent){
        if(!VehicleStore.hasParked(context))return
        val result=ActivityRecognitionResult.extractResult(intent)?:return
        val activity=result.mostProbableActivity
        if(activity.type==DetectedActivity.IN_VEHICLE ||
            activity.type==DetectedActivity.ON_BICYCLE)
            VehicleLifecycle.recordVehicleMotion(context,activity.confidence)
        else if(activity.confidence>=70 &&
            (activity.type==DetectedActivity.WALKING||
             activity.type==DetectedActivity.RUNNING||
             activity.type==DetectedActivity.ON_FOOT||
             activity.type==DetectedActivity.STILL))
            VehicleLifecycle.clearVehicleMotion(context)
    }
}
