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

/** Local vehicle data; no QLĐT, attendance or theme writes. Keys are kept for compatibility. */
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

    private fun scheduleData(context:Context):JSONArray =
        runCatching{JSONArray(pref(context).getString("windows","[]")?:"[]")}
            .getOrElse{JSONArray()}
    fun setWindows(context:Context,windows:List<Map<String,Any>>){
        val now=System.currentTimeMillis()
        val array=JSONArray()
        for(window in windows.take(400)){
            val start=(window["start"] as? Number)?.toLong()?:continue
            val end=(window["end"] as? Number)?.toLong()?:continue
            val name=(window["name"] as? String)?.take(120)?:"Môn học"
            val kind=(window["kind"] as? String)?.uppercase(Locale.ROOT)?:""
            val text=(name+" "+((window["className"] as? String)?:"")+" "+
                ((window["room"] as? String)?:"")).lowercase(Locale.ROOT)
            val online=kind=="ELEARNING" || Regex(
                """(?:e[\s-]?learning|(?:^|[\s.\-_/()])eln[0-9]*(?:$|[\s.\-_/()]))"""
            ).containsMatchIn(text)
            if(!online&&end>start&&end>now)
                array.put(org.json.JSONObject().put("start",start)
                    .put("end",end).put("name",name))
        }
        val json=array.toString()
        if(pref(context).getString("windows",null)!=json)
            pref(context).edit().putString("windows",json).apply()
    }
    fun activeWindows(context:Context,now:Long=System.currentTimeMillis()):Boolean{
        val array=scheduleData(context)
        val rearmAt=pref(context).getLong("rearmAt",0L)
        for(i in 0 until array.length()){
            val item=array.optJSONObject(i)?:continue
            val start=item.optLong("start")
            val end=item.optLong("end")
            if(start>rearmAt&&now>=start-120L*60_000L&&now<end)
                return true
        }
        return false
    }
    fun inClassWindow(context:Context)=activeWindows(context)
    fun scheduleRows(context:Context,demo:Boolean=false):List<Map<String,Any>>{
        val array=scheduleData(context)
        val now=System.currentTimeMillis()
        val rearmAt=pref(context,demo).getLong("rearmAt",0L)
        val parked=hasParked(context,demo)
        val rows=ArrayList<Map<String,Any>>()
        for(i in 0 until array.length()){
            val row=array.optJSONObject(i)?:continue
            val start=row.optLong("start")
            val end=row.optLong("end")
            if(end<=now||start<=rearmAt||start>now+7*24L*60*60_000L)continue
            val ready=!parked&&now>=start-120L*60_000L
            rows.add(mapOf("name" to row.optString("name","Môn học"),
                "start" to start,"end" to end,"available" to ready,
                "status" to if(parked)"Đã đỗ xe · khóa"
                    else if(ready)"Đang chờ" else "Chưa đến giờ"))
        }
        return rows.sortedBy{it["start"] as Long}.take(40)
    }
    fun nextWaitStart(context:Context,now:Long=System.currentTimeMillis()):Long?{
        val array=scheduleData(context)
        val rearmAt=pref(context).getLong("rearmAt",0L)
        var next:Long?=null
        for(i in 0 until array.length()){
            val row=array.optJSONObject(i)?:continue
            val start=row.optLong("start")
            if(start<=rearmAt||row.optLong("end")<=now)continue
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
    @Synchronized fun rearmTest(context:Context){
        pref(context,true).edit().remove("parkLat").remove("parkLon")
            .remove("parkedAt").putBoolean("tracking",false)
            .putLong("rearmAt",System.currentTimeMillis()).apply()
        file(context,true).delete()
    }
    @Synchronized fun manualResetReal(context:Context){
        val prefs=pref(context)
        val previous=prefs.getLong("rearmAt",0L)
        val now=System.currentTimeMillis()
        file(context).delete()
        prefs.edit().remove("parkLat").remove("parkLon").remove("parkedAt")
            .putBoolean("tracking",false)
            .putLong("rearmAt",maxOf(previous,now)).commit()
        // A manual reset is an explicit fallback and must not restore past
        // parked routes or modify attendance or source timetable.
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
            VehicleIntents.openApp(context),
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
            VehicleIntents.openApp(context),
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
            "notificationAccess" to VehicleExitNotificationListener.hasPermission(context),
            "waitingSubjects" to scheduleRows(context,demo),
            "nextWaitStart" to (if(demo)null else nextWaitStart(context))
        )
    }
}
