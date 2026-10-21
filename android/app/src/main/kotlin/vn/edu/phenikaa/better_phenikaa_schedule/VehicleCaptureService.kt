package vn.edu.phenikaa.better_phenikaa_schedule

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

/** All data is in a separate debug APK package. Never uses hardcoded test vehicle points. */
object VehicleStore {
    private fun pref(context: Context) = context.getSharedPreferences("bpa_vehicle_demo_v1", Context.MODE_PRIVATE)
    private fun file(context: Context) = File(context.filesDir, "vehicle_trace.csv")
    fun isEnabled(context: Context) = pref(context).getBoolean("enabled", false)
    fun enabled(context: Context, value: Boolean) {
        pref(context).edit().putBoolean("enabled", value).apply()
    }
    fun hasParked(context: Context): Boolean =
        pref(context).contains("parkLat") && pref(context).contains("parkLon")
    fun parkLat(context: Context): Double? =
        if (hasParked(context)) java.lang.Double.longBitsToDouble(pref(context).getLong("parkLat", 0)) else null
    fun parkLon(context: Context): Double? =
        if (hasParked(context)) java.lang.Double.longBitsToDouble(pref(context).getLong("parkLon", 0)) else null

    fun setWindows(context: Context, windows: List<Map<String, Any>>) {
        val array = JSONArray()
        for (window in windows.take(400)) {
            val start = (window["start"] as? Number)?.toLong() ?: continue
            val end = (window["end"] as? Number)?.toLong() ?: continue
            if (end > start) array.put(JSONArray().put(start).put(end))
        }
        pref(context).edit().putString("windows", array.toString()).apply()
    }
    fun inClassWindow(context: Context): Boolean {
        val raw = pref(context).getString("windows", "[]") ?: "[]"
        val list = runCatching { JSONArray(raw) }.getOrElse { return true }
        if (list.length() == 0) return true
        val now = System.currentTimeMillis()
        for (i in 0 until list.length()) {
            val pair = list.optJSONArray(i) ?: continue
            // University arrival can be substantially earlier than the first session.
            if (now >= pair.optLong(0) - 120L * 60_000 &&
                now <= pair.optLong(1) + 120L * 60_000) return true
        }
        return false
    }
    @Synchronized fun begin(context: Context) {
        file(context).parentFile?.mkdirs()
        file(context).writeText("")
        pref(context).edit().remove("parkLat").remove("parkLon")
            .putBoolean("tracking", true).putLong("parkedAt", 0).apply()
    }
    fun isTracking(context: Context): Boolean = pref(context).getBoolean("tracking", false)
    @Synchronized fun append(context: Context, location: Location) {
        if (!isTracking(context)) return
        file(context).appendText(String.format(Locale.US,
            "%.9f,%.9f,%d,%.1f\n", location.latitude,location.longitude,
            location.time,if(location.hasAccuracy())location.accuracy else 999f))
    }
    @Synchronized fun saveParked(context: Context, lat: Double, lon: Double) {
        pref(context).edit()
            .putLong("parkLat", java.lang.Double.doubleToRawLongBits(lat))
            .putLong("parkLon", java.lang.Double.doubleToRawLongBits(lon))
            .putLong("parkedAt",System.currentTimeMillis())
            .putBoolean("tracking",false).apply()
    }
    fun route(context: Context): List<List<Double>> {
        val route = ArrayList<List<Double>>()
        val csv = file(context)
        if (!csv.isFile) return route
        csv.useLines { lines ->
            lines.take(4000).forEach { line ->
                val columns=line.split(",")
                if (columns.size>=2) {
                    val lat=columns[0].toDoubleOrNull()
                    val lon=columns[1].toDoubleOrNull()
                    if (lat!=null&&lon!=null&&lat.isFinite()&&lon.isFinite())
                        route.add(listOf(lat,lon))
                }
            }
        }
        return route
    }
    fun snapshot(context: Context): Map<String, Any?> {
        val p=pref(context)
        val active=isEnabled(context)
        val foregroundLocation=context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==
            PackageManager.PERMISSION_GRANTED
        val backgroundLocation=Build.VERSION.SDK_INT<29 ||
            context.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)==
            PackageManager.PERMISSION_GRANTED
        return mapOf(
            "enabled" to active,
            "tracking" to isTracking(context),
            "parked" to hasParked(context),
            "parkLat" to parkLat(context),
            "parkLon" to parkLon(context),
            "parkedAt" to p.getLong("parkedAt",0L),
            "location" to foregroundLocation,
            "background" to backgroundLocation,
            "route" to route(context)
        )
    }
}
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
        val open=PendingIntent.getActivity(this,90,Intent(this,MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this,channelId)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Phương Tiện")
            .setContentText("Đang ghi hành trình")
            .setOngoing(true).setContentIntent(open).build()
    }
    override fun onStartCommand(intent:Intent?,flags:Int,startId:Int):Int {
        if (!VehicleStore.isEnabled(this) || VehicleStore.hasParked(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        // The OS requires an ongoing notification while foreground location is in use.
        startForeground(8871,ongoing())
        if (!VehicleStore.isTracking(this)) VehicleStore.begin(this)
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
        return START_STICKY
    }
    override fun onLocationChanged(location:Location) {
        if (!VehicleStore.isTracking(this)) return
        if (location.hasAccuracy() && location.accuracy>45f) return
        if (location.time<=lastFixAt || !location.latitude.isFinite() || !location.longitude.isFinite()) return
        if (lastGoodFix!=null && location.distanceTo(lastGoodFix!!)>75f &&
            location.time-lastFixAt<4000) return
        lastFixAt=location.time
        lastGoodFix=Location(location)
        VehicleStore.append(this,location)
        recent.addLast(Location(location))
        while(recent.size>45 || (recent.isNotEmpty() && location.time-recent.first().time>60_000))
            recent.removeFirst()
        maybePark()
    }
    override fun onSensorChanged(event:SensorEvent) {
        if(event.sensor.type!=Sensor.TYPE_STEP_DETECTOR || !VehicleStore.isTracking(this))return
        val now=SystemClock.elapsedRealtime()
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
        VehicleStore.saveParked(this,lat,lon)
        val manager=getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val intent=PendingIntent.getActivity(this,7791,Intent(this,MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        manager.notify(8872,Notification.Builder(this,successChannelId)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Đã xác định vị trí đỗ xe")
            .setContentIntent(intent).setAutoCancel(true).build())
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