package vn.edu.phenikaa.better_phenikaa_schedule

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.location.Priority
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Native bridge isolated from QLĐT, themes, widget renderers and updater. */
class VehicleBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel=MethodChannel(messenger,"better_phenikaa/vehicle")
    private val fused=LocationServices.getFusedLocationProviderClient(activity)
    private var navCallback:LocationCallback?=null
    private var navFix:Location?=null
    private var lastRequest=0L
    init { channel.setMethodCallHandler(::handle) }
    private fun handle(call:MethodCall,result:MethodChannel.Result) {
        try {
            when(call.method) {
                "state" -> result.success(VehicleStore.snapshot(activity))
                "notificationAccess" ->
                    result.success(VehicleExitNotificationListener.hasPermission(activity))
                "requestNotificationAccess" -> {
                    activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "enable" -> {
                    VehicleStore.enabled(activity,true)
                    requestPermissions()
                    VehicleLifecycle.armNext(activity)
                    result.success(VehicleStore.snapshot(activity))
                }
                "permissions" -> {
                    requestPermissions()
                    result.success(VehicleStore.snapshot(activity))
                }
                "permissionSettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:" + activity.packageName)))
                    result.success(null)
                }
                "schedule" -> {
                    val windows=call.argument<List<Map<String,Any>>>("windows") ?: emptyList()
                    VehicleStore.setWindows(activity,windows)
                    if(windows.isNotEmpty()&&!VehicleStore.isEnabled(activity)){
                        VehicleStore.enabled(activity,true)
                        requestPermissions()
                    }
                    VehicleLifecycle.armNext(activity)
                    result.success(null)
                }
                "manualReset" -> {
                    // User-only recovery: stop a stuck live run, clear its old
                    // position and reassess future timetable sessions.
                    activity.stopService(Intent(activity,VehicleCaptureService::class.java))
                    VehicleStore.manualResetReal(activity)
                    VehicleLifecycle.armNext(activity)
                    result.success(VehicleStore.snapshot(activity))
                }
                "startNav" -> { startNavigation(); result.success(null) }
                "nav" -> { watchdog(); result.success(navSnapshot()) }
                "stopNav" -> { stopNavigation(); result.success(null) }
                else -> result.notImplemented()
            }
        } catch(error:Exception) {
            result.error("vehicle",error.message ?: "Không thể truy cập vị trí",null)
        }
    }
    private fun hasPermission():Boolean =
        activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==
            PackageManager.PERMISSION_GRANTED ||
        activity.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)==
            PackageManager.PERMISSION_GRANTED
    private fun requestPermissions() {
        if(!VehicleStore.isEnabled(activity))return
        val missing=ArrayList<String>()
        if(!hasPermission()){
            missing.add(Manifest.permission.ACCESS_FINE_LOCATION)
            missing.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        if(Build.VERSION.SDK_INT>=29 &&
            activity.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION)!=PackageManager.PERMISSION_GRANTED)
            missing.add(Manifest.permission.ACTIVITY_RECOGNITION)
        if(Build.VERSION.SDK_INT>=33 &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)
            missing.add(Manifest.permission.POST_NOTIFICATIONS)
        if(missing.isNotEmpty())activity.requestPermissions(missing.toTypedArray(),7419)
    }
    fun permissionsUpdated(code:Int) {
        if(code==7419 && VehicleStore.isEnabled(activity))VehicleLifecycle.armNext(activity)
    }
    private fun acceptFix(loc:Location?,cached:Boolean=false) {
        if(loc==null || !loc.latitude.isFinite() || !loc.longitude.isFinite())return
        val ageMs=((SystemClock.elapsedRealtimeNanos()-loc.elapsedRealtimeNanos)/1_000_000L)
        if(ageMs<0 || ageMs>(if(cached) 20*60_000L else 90_000L))return
        if(loc.hasAccuracy() && loc.accuracy>(if(cached) 350f else 120f))return
        if(navFix!=null && navFix!!.elapsedRealtimeNanos>loc.elapsedRealtimeNanos)return
        navFix=Location(loc)
    }
    private fun navSnapshot(demo:Boolean=false):Map<String,Any?> {
        val loc=navFix
        val snapshot=HashMap<String,Any?>()
        snapshot["parkLat"]=VehicleStore.parkLat(activity,demo)
        snapshot["parkLon"]=VehicleStore.parkLon(activity,demo)
        if(loc!=null){
            snapshot["lat"]=loc.latitude
            snapshot["lon"]=loc.longitude
            snapshot["accuracy"]=if(loc.hasAccuracy())loc.accuracy.toDouble() else 999.0
            snapshot["ageMs"]=((SystemClock.elapsedRealtimeNanos()-loc.elapsedRealtimeNanos)/
                1_000_000).coerceAtLeast(0L)
        }
        return snapshot
    }
    private fun startNavigation() {
        if(!hasPermission() || !VehicleStore.isEnabled(activity) || navCallback!=null)return
        lastRequest=SystemClock.elapsedRealtime()
        try {
            fused.lastLocation.addOnSuccessListener {acceptFix(it,true)}
            val request=LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY,900L)
                .setMinUpdateIntervalMillis(400L).setMinUpdateDistanceMeters(0f).build()
            val callback=object:LocationCallback() {
                override fun onLocationResult(result:LocationResult) {
                    result.locations.forEach {acceptFix(it)}
                }
            }
            navCallback=callback
            fused.requestLocationUpdates(request,callback,activity.mainLooper)
                .addOnFailureListener {navCallback=null}
            fused.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY,CancellationTokenSource().token)
                .addOnSuccessListener {acceptFix(it)}
        } catch(_:SecurityException){navCallback=null}
    }
    private fun watchdog() {
        if(navCallback==null){startNavigation();return}
        val age=navFix?.let{(SystemClock.elapsedRealtimeNanos()-it.elapsedRealtimeNanos)/
            1_000_000} ?: Long.MAX_VALUE
        if(age>12_000 && SystemClock.elapsedRealtime()-lastRequest>18_000){
            stopNavigation();startNavigation()
        }
    }
    private fun stopNavigation() {
        navCallback?.let {fused.removeLocationUpdates(it)}
        navCallback=null
    }
    fun close() {
        stopNavigation()
        channel.setMethodCallHandler(null)
    }
    companion object {
        private val gates=VehicleLifecycle.gates
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
    }
}
class VehicleFenceReceiver:BroadcastReceiver(){
    override fun onReceive(context:Context,intent:Intent){
        if(!VehicleStore.isEnabled(context))return
        val event=GeofencingEvent.fromIntent(intent)?:return
        if(event.hasError())return
        if(event.geofenceTransition==Geofence.GEOFENCE_TRANSITION_ENTER)
            VehicleLifecycle.enter(context)
    }
}
class VehicleBootReceiver:BroadcastReceiver(){
    override fun onReceive(context:Context,intent:Intent) {
        if(intent.action==Intent.ACTION_BOOT_COMPLETED ||
            intent.action==Intent.ACTION_MY_PACKAGE_REPLACED)
            VehicleLifecycle.armNext(context)
    }
}