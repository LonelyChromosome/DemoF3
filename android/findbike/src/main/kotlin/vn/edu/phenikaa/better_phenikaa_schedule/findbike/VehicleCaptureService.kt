package vn.edu.phenikaa.better_phenikaa_schedule.findbike

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import org.json.JSONArray
import java.io.File
import java.util.Locale

class VehicleCaptureService : Service(), LocationListener, SensorEventListener {
    private lateinit var locationManager:LocationManager
    private lateinit var sensorManager:SensorManager
    private var stepSensor:Sensor?=null
    private val recent=ArrayDeque<Location>()
    private var firstStepAt:Long=0L
    private var firstWalkingPoint:Location?=null
    private var stepCount=0
    private var previousStepAt=0L
    private var lastFixAt=0L
    private var lastGoodFix:Location?=null
    private val handler=Handler(Looper.getMainLooper())
    private val channelId="bpa_vehicle_tracking"
    private val successChannelId="bpa_vehicle_parked"
    private var demoMode=false
    override fun onBind(intent:Intent?):IBinder?=null
    override fun onCreate() {
        super.onCreate()
        locationManager=getSystemService(LOCATION_SERVICE) as LocationManager
        sensorManager=getSystemService(SENSOR_SERVICE) as SensorManager
        stepSensor=sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        createChannels()
    }
    private fun createChannels() {
        val manager=getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT>=26) {
            manager.createNotificationChannel(NotificationChannel(channelId,"Định vị xe",NotificationManager.IMPORTANCE_MIN))
            manager.createNotificationChannel(NotificationChannel(successChannelId,"Đã đỗ xe",NotificationManager.IMPORTANCE_DEFAULT))
        }
    }
    private fun ongoing():Notification {
        val open=PendingIntent.getActivity(this,90,VehicleIntents.openApp(this),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this,channelId)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Xe cộ")
            .setContentText("Đang ghi hành trình")
            .setOngoing(true).setContentIntent(open).build()
    }
    override fun onStartCommand(intent:Intent?,flags:Int,startId:Int):Int {
        if(intent?.action=="bpa.demo.walk"){
            if(packageName.endsWith(".vehicle.demo19.events")&&demoMode&&VehicleStore.isTracking(this,true)){
                for(i in 0..6)handler.postDelayed({
                    if(VehicleStore.isTracking(this,true))onWalkingStep(SystemClock.elapsedRealtime())
                },i*1280L)
            }
            return START_STICKY
        }
        val requestDemo=intent?.action=="bpa.demo.start"
        if(requestDemo && !packageName.endsWith(".vehicle.demo19.events"))return START_NOT_STICKY
        if(!requestDemo && demoMode)return START_STICKY
        if(requestDemo && !demoMode && VehicleStore.isTracking(this))
            return START_NOT_STICKY
        demoMode=requestDemo
        if (!VehicleStore.isEnabled(this) || VehicleStore.hasParked(this,demoMode)) {
            stopSelf()
            return START_NOT_STICKY
        }
        // The OS requires an ongoing notification while foreground location is in use.
        startForeground(8871,ongoing())
        val newTrip=!VehicleStore.isTracking(this,demoMode)
        if (newTrip) VehicleStore.begin(this,demoMode)
        try {
            if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED) {
                stopSelf()
                return START_NOT_STICKY
            }
            locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER,1100L,0f,this,Looper.getMainLooper())
            if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
                locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER,2500L,0f,this,Looper.getMainLooper())
        } catch (_:Exception) {}
        stepSensor?.let {
            if (Build.VERSION.SDK_INT<29 ||
                checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION)==PackageManager.PERMISSION_GRANTED) {
                sensorManager.registerListener(this,it,SensorManager.SENSOR_DELAY_NORMAL)
            }
        }
        // Only parking completion sends a user-facing alert.
        return START_STICKY
    }
    override fun onLocationChanged(location:Location) {
        if (!VehicleStore.isTracking(this,demoMode)) return
        // No bike detected by the end of its last eligible class:
        // expire this *vehicle* tracking session, never edit attendance data.
        if(!demoMode&&!VehicleStore.activeWindows(this)){
            VehicleStore.expireUnparkedSession(this)
            stopSelf()
            VehicleLifecycle.armNext(this)
            return
        }
        if (location.hasAccuracy() && location.accuracy>45f) return
        if (location.time<=lastFixAt || !location.latitude.isFinite() || !location.longitude.isFinite()) return
        if (lastGoodFix!=null && location.distanceTo(lastGoodFix!!)>75f &&
            location.time-lastFixAt<4000) return
        lastFixAt=location.time
        lastGoodFix=Location(location)
        VehicleStore.append(this,location,demoMode)
        recent.addLast(Location(location))
        while(recent.size>45 || (recent.isNotEmpty() && location.time-recent.first().time>60_000))
            recent.removeFirst()
        maybePark()
    }
    override fun onSensorChanged(event:SensorEvent) {
        if(event.sensor.type!=Sensor.TYPE_STEP_DETECTOR || !VehicleStore.isTracking(this,demoMode))return
        if(!demoMode&&!VehicleStore.activeWindows(this)){
            VehicleStore.expireUnparkedSession(this)
            stopSelf()
            VehicleLifecycle.armNext(this)
            return
        }
        onWalkingStep(SystemClock.elapsedRealtime())
    }
    private fun onWalkingStep(now:Long) {
        if(now-previousStepAt>4500) {
            firstStepAt=now
            firstWalkingPoint=lastGoodFix?.let(::Location)
            stepCount=1
        } else {
            stepCount++
        }
        previousStepAt=now
        maybePark()
    }
    private fun maybePark() {
        val started=firstStepAt
        if(started==0L||stepCount<5||SystemClock.elapsedRealtime()-started<7000L ||
            SystemClock.elapsedRealtime()-previousStepAt>2500L) return
        // Look at the STATIONARY vehicle position just before steps commenced.
        // Do not simply use the last GPS fix, which can be after walking away.
        val foot=firstWalkingPoint ?:return
        val before=recent.filter { it.time<=foot.time+1800 &&
            it.time>=foot.time-20_000 && it.hasAccuracy() && it.accuracy<=30f }
        if(before.size<2)return
        val base=before.last()
        val cluster=before.filter { it.distanceTo(base)<=9f }
        if(cluster.size<2)return
        val lat=cluster.map { it.latitude }.average()
        val lon=cluster.map { it.longitude }.average()
        if(!lat.isFinite()||!lon.isFinite())return
        VehicleStore.saveParked(this,lat,lon,demoMode)
        VehicleStore.sendParkNotification(this,demoMode)
        if(!demoMode)VehicleLifecycle.armNext(this)
        stopSelf()
    }
    override fun onAccuracyChanged(sensor:Sensor?,accuracy:Int){}
    @Deprecated("LocationListener")
    override fun onStatusChanged(provider:String?,status:Int,extras:Bundle?){}
    override fun onDestroy() {
        runCatching {locationManager.removeUpdates(this)}
        sensorManager.unregisterListener(this)
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}