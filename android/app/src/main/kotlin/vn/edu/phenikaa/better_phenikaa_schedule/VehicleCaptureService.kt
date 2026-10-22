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
    private fun pref(context: Context, demo:Boolean=false) =
        context.getSharedPreferences(if(demo)"bpa_vehicle_TEST_v2" else "bpa_vehicle_demo_v1",Context.MODE_PRIVATE)
    private fun file(context: Context, demo:Boolean=false) =
        File(context.filesDir,if(demo)"vehicle_TEST_trace.csv" else "vehicle_trace.csv")
    fun isEnabled(context: Context) = pref(context).getBoolean("enabled", false)
    fun enabled(context: Context, value: Boolean) {
        pref(context).edit().putBoolean("enabled", value).apply()
    }
    fun hasParked(context: Context,demo:Boolean=false): Boolean =
        pref(context,demo).contains("parkLat") && pref(context,demo).contains("parkLon")
    fun parkLat(context: Context,demo:Boolean=false): Double? =
        if(hasParked(context,demo)) java.lang.Double.longBitsToDouble(pref(context,demo).getLong("parkLat",0)) else null
    fun parkLon(context: Context,demo:Boolean=false): Double? =
        if(hasParked(context,demo)) java.lang.Double.longBitsToDouble(pref(context,demo).getLong("parkLon",0)) else null

    fun setWindows(context: Context, windows: List<Map<String, Any>>) {
        val array = JSONArray()
        for(window in windows.take(400)){
            val start=(window["start"] as? Number)?.toLong()?:continue
            val end=(window["end"] as? Number)?.toLong()?:continue
            if(end>start)array.put(org.json.JSONObject()
                .put("start",start).put("end",end)
                .put("name",(window["name"] as? String)?.take(120)?:"Môn học"))
        }
        pref(context).edit().putString("windows", array.toString()).apply()
    }
    fun activeWindows(context:Context,now:Long=System.currentTimeMillis()):Boolean{
        val raw=pref(context).getString("windows","[]")?:"[]"
        val array=runCatching{JSONArray(raw)}.getOrElse{return false}
        val rearmAt=pref(context).getLong("rearmAt",0L)
        for(i in 0 until array.length()){
            val item=array.optJSONObject(i)?:continue
            val start=item.optLong("start")
            val end=item.optLong("end")
            if(start>rearmAt&&now>=start-120L*60_000L&&now<=end+120L*60_000L)
                return true
        }
        return false
    }
    fun inClassWindow(context:Context)=activeWindows(context)
    fun scheduleRows(context:Context):List<Map<String,Any>>{
        val raw=pref(context).getString("windows","[]")?:"[]"
        val arr=runCatching{JSONArray(raw)}.getOrElse{return emptyList()}
        val now=System.currentTimeMillis()
        val locked=hasParked(context)
        val rearmAt=pref(context).getLong("rearmAt",0L)
        val rows=ArrayList<Map<String,Any>>()
        for(i in 0 until arr.length()){
            val o=arr.optJSONObject(i)?:continue
            val start=o.optLong("start")
            val end=o.optLong("end")
            if(end<now-6*60L*60_000L||start>now+7*24L*60*60_000L)continue
            val available=!locked&&start>rearmAt&&now>=start-120L*60_000L&&now<=end+120L*60_000L
            rows.add(mapOf("name" to o.optString("name","Môn học"),
                "start" to start,"end" to end,"available" to available,
                "status" to if(locked)"Đã đỗ xe" else if(start<=rearmAt)"Đã khóa phiên cũ" else
                    if(now<start-120L*60_000L)"Chưa đến giờ" else if(now>end+120L*60_000L)"Đã qua" else "Đang chờ"))
        }
        return rows.sortedBy{it["start"] as Long}.take(40)
    }
    fun nextWaitStart(context:Context,now:Long=System.currentTimeMillis()):Long?{
        val raw=pref(context).getString("windows","[]")?:"[]"
        val arr=runCatching{JSONArray(raw)}.getOrElse{return null}
        val rearmAt=pref(context).getLong("rearmAt",0L)
        var next:Long?=null
        for(i in 0 until arr.length()){
            val item=arr.optJSONObject(i)?:continue
            val start=item.optLong("start")
            if(start<=rearmAt)continue
            val trigger=start-120L*60_000L
            if(trigger>now&&(next==null||trigger<next))next=trigger
        }
        return next
    }
    fun nextWindowExpiry(context:Context,now:Long=System.currentTimeMillis()):Long?{
        val arr=scheduleData(context)
        val rearmAt=pref(context).getLong("rearmAt",0L)
        var expiry:Long?=null
        for(i in 0 until arr.length()){
            val item=arr.optJSONObject(i)?:continue
            val start=item.optLong("start")
            val end=item.optLong("end")
            if(start<=rearmAt||now<start-120L*60_000L||now>end)continue
            if(expiry==null||end<expiry)expiry=end
        }
        return expiry
    }
    @Synchronized fun rearmReal(context:Context){
        pref(context).edit().remove("parkLat").remove("parkLon").remove("parkedAt")
            .putBoolean("tracking",false)
            .putLong("rearmAt",System.currentTimeMillis()).apply()
    }
    fun sendEnterNotification(context:Context,demo:Boolean=false){
        val manager=context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel="bpa_vehicle_enter"
        if(Build.VERSION.SDK_INT>=26)
            manager.createNotificationChannel(NotificationChannel(channel,
                "Xe vào phạm vi",NotificationManager.IMPORTANCE_DEFAULT))
        if(Build.VERSION.SDK_INT>=33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)
            return
        val open=PendingIntent.getActivity(context,8012,
            Intent(context,MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        manager.notify(if(demo)8890 else 8870,Notification.Builder(context,channel)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle(if(demo)"[TEST] Xe vào phạm vi" else "Xe đã vào phạm vi trường")
            .setContentText("Find My Bike bắt đầu ghi hành trình")
            .setAutoCancel(true).setContentIntent(open).build())
    }
    @Synchronized fun begin(context: Context,demo:Boolean=false) {
        file(context,demo).parentFile?.mkdirs()
        file(context,demo).writeText("")
        pref(context,demo).edit().remove("parkLat").remove("parkLon")
            .putBoolean("tracking", true).putLong("parkedAt", 0).apply()
    }
    fun parkAgeMs(context: Context): Long {
        val timestamp = pref(context).getLong("parkedAt",0L)
        return if(timestamp<=0)Long.MAX_VALUE else
            (System.currentTimeMillis()-timestamp).coerceAtLeast(0L)
    }
    fun isTracking(context: Context,demo:Boolean=false): Boolean =
        pref(context,demo).getBoolean("tracking",false)
    @Synchronized fun expireUnparkedSession(context:Context){
        if(hasParked(context))return
        file(context).delete()
        pref(context).edit().putBoolean("tracking",false).apply()
    }
    @Synchronized fun append(context: Context, location: Location,demo:Boolean=false) {
        if (!isTracking(context,demo)) return
        file(context,demo).appendText(String.format(Locale.US,
            "%.9f,%.9f,%d,%.1f\n", location.latitude,location.longitude,
            location.time,if(location.hasAccuracy())location.accuracy else 999f))
    }
    @Synchronized fun saveParked(context: Context, lat: Double, lon: Double,demo:Boolean=false) {
        pref(context,demo).edit()
            .putLong("parkLat", java.lang.Double.doubleToRawLongBits(lat))
            .putLong("parkLon", java.lang.Double.doubleToRawLongBits(lon))
            .putLong("parkedAt",System.currentTimeMillis())
            .putBoolean("tracking",false).apply()
    }
    @Synchronized fun recentStableTestParking(context:Context):Pair<Double,Double>? {
        val source=file(context,true)
        if(!source.isFile)return null
        data class Gps(val lat:Double,val lon:Double,val at:Long,val accuracy:Float)
        val points=source.readLines().takeLast(70).mapNotNull{ row ->
            val v=row.split(",")
            if(v.size<4)return@mapNotNull null
            val lat=v[0].toDoubleOrNull()?:return@mapNotNull null
            val lon=v[1].toDoubleOrNull()?:return@mapNotNull null
            val time=v[2].toLongOrNull()?:return@mapNotNull null
            val accuracy=v[3].toFloatOrNull()?:return@mapNotNull null
            if(!lat.isFinite()||!lon.isFinite()||accuracy>30f||
                Math.abs(lat)>90||Math.abs(lon)>180)return@mapNotNull null
            Gps(lat,lon,time,accuracy)
        }
        if(points.size<2)return null
        val last=points.last()
        if(System.currentTimeMillis()-last.at !in 0L..30_000L)return null
        val anchor=Location("demo-anchor").apply {latitude=last.lat;longitude=last.lon}
        val stable=points.filter {point ->
            if(last.at-point.at !in 0L..15_000L)return@filter false
            val loc=Location("demo-sample").apply{latitude=point.lat;longitude=point.lon}
            loc.distanceTo(anchor)<=12f
        }
        if(stable.size<2)return null
        return stable.map{it.lat}.average() to stable.map{it.lon}.average()
    }
    @Synchronized fun resetDemoSession(context:Context){
        file(context,true).delete()
        pref(context,true).edit().remove("parkLat").remove("parkLon")
            .remove("parkedAt").putBoolean("tracking",false).apply()
    }
    fun sendParkNotification(context:Context,demo:Boolean=false){
        val manager=context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel="bpa_vehicle_parked"
        if(Build.VERSION.SDK_INT>=26)
            manager.createNotificationChannel(NotificationChannel(channel,
                "Đã đỗ xe",NotificationManager.IMPORTANCE_DEFAULT))
        if(Build.VERSION.SDK_INT>=33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)
            return
        val open=PendingIntent.getActivity(context,7791,
            Intent(context,MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        manager.notify(if(demo)8892 else 8872,Notification.Builder(context,channel)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle(if(demo)"[TEST] Đã xác định vị trí đỗ xe" else "Đã xác định vị trí đỗ xe")
            .setContentIntent(open).setAutoCancel(true).build())
    }
    fun route(context: Context,demo:Boolean=false): List<List<Double>> {
        val route = ArrayList<List<Double>>()
        val csv = file(context,demo)
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
    fun snapshot(context: Context,demo:Boolean=false): Map<String, Any?> {
        val p=pref(context,demo)
        val active=isEnabled(context)
        val foregroundLocation=context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==
            PackageManager.PERMISSION_GRANTED
        val backgroundLocation=Build.VERSION.SDK_INT<29 ||
            context.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)==
            PackageManager.PERMISSION_GRANTED
        return mapOf(
            "enabled" to active,
            "tracking" to isTracking(context,demo),
            "parked" to hasParked(context,demo),
            "parkLat" to parkLat(context,demo),
            "parkLon" to parkLon(context,demo),
            "parkedAt" to p.getLong("parkedAt",0L),
            "location" to foregroundLocation,
            "background" to backgroundLocation,
            "route" to route(context,demo),
            "waitingSubjects" to if(demo)emptyList<Map<String,Any>>() else scheduleRows(context),
            "nextWaitStart" to (if(demo)null else nextWaitStart(context)),
            "notificationAccess" to VehicleExitNotificationListener.hasPermission(context)
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
        val open=PendingIntent.getActivity(this,90,Intent(this,MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this,channelId)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Phương Tiện")
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
        if(newTrip)VehicleStore.sendEnterNotification(this,demoMode)
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
        if(!demoMode)VehicleLifecycle.armMotion(this)
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