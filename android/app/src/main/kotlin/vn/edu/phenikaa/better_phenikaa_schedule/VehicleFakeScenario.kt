package vn.edu.phenikaa.better_phenikaa_schedule

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Fully isolated, deterministic FAKE mode. A private virtual clock and three
 * in-person lessons + one eLearning lesson never touch VehicleStore or GPS.
 */
object VehicleFakeScenario {
    private const val PREF="bpa_vehicle_fake_v3"
    private const val CHANNEL="bpa_vehicle_fake_scenario"
    private fun prefs(context:Context)=context.getSharedPreferences(PREF,Context.MODE_PRIVATE)
    private data class Lesson(val id:String,val name:String,val start:Long,val end:Long,val online:Boolean=false)
    private fun fixtures(base:Long):List<Lesson>{
        val m=60_000L
        return listOf(
            Lesson("A","Lập trình Android · Ca 1",base,base+60*m),
            Lesson("EL","E-Learning · Không chờ xe",base+70*m,base+130*m,true),
            Lesson("B","Phân tích thiết kế · Ca 2",base+150*m,base+210*m),
            Lesson("C","Cơ sở dữ liệu · Ca 3",base+270*m,base+330*m)
        )
    }
    private fun initialize(context:Context,force:Boolean=false){
        val p=prefs(context)
        if(p.contains("base")&&!force)return
        val base=System.currentTimeMillis()+30*60_000L
        p.edit().clear().putLong("base",base).putLong("clock",base-30*60_000L)
            .putString("status","WAITING").putString("current","")
            .putStringSet("handled",emptySet()).putString("history","").apply()
        log(context,"Tạo 3 buổi trực tiếp + 1 eLearning bị loại")
    }
    private fun consumed(context:Context):MutableSet<String> =
        (prefs(context).getStringSet("handled",emptySet())?:emptySet()).toMutableSet()
    private fun log(context:Context,message:String){
        val p=prefs(context)
        val time=SimpleDateFormat("HH:mm",Locale.forLanguageTag("vi-VN"))
            .format(Date(p.getLong("clock",System.currentTimeMillis())))
        val prev=(p.getString("history","")?:"").split("\n").filter{it.isNotBlank()}.takeLast(5)
        p.edit().putString("history",(prev+listOf("$time · $message")).joinToString("\n")).apply()
    }
    private fun notifyFake(context:Context,title:String,body:String,id:Int){
        if(Build.VERSION.SDK_INT>=33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return
        val manager=context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if(Build.VERSION.SDK_INT>=26)
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL,"Find My Bike · Test giả lập",NotificationManager.IMPORTANCE_DEFAULT))
        val open=PendingIntent.getActivity(context,8901,Intent(context,MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        manager.notify(id,Notification.Builder(context,CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("[FAKE TEST] "+title).setContentText(body)
            .setAutoCancel(true).setContentIntent(open).build())
    }
    @Synchronized fun state(context:Context):Map<String,Any>{
        initialize(context)
        val p=prefs(context)
        val now=p.getLong("clock",0L)
        val status=p.getString("status","WAITING")?:"WAITING"
        val current=p.getString("current","")?:""
        val handled=consumed(context)
        val lessons=fixtures(p.getLong("base",0L))
        val classes=lessons.filter{!it.online}
        val queue=classes.filter{it.end>now&&it.id !in handled}.map{item->
            val ready=status=="WAITING"&&now>=item.start-120*60_000L&&now<item.end
            mapOf<String,Any>(
                "id" to item.id,"name" to item.name,
                "start" to item.start,"end" to item.end,
                "available" to ready,
                "status" to when{
                    status=="PARKED"->"Khóa: đã đỗ xe"
                    status=="TRACKING"->"Khóa: đang tracking"
                    ready->"Đang chờ"
                    else->"Chưa đến giờ"
                }
            )
        }
        return mapOf(
            "mode" to "FAKE","status" to status,"current" to current,
            "virtualTime" to now,"waiting" to queue,
            "excluded" to lessons.filter{it.online}.map{it.name},
            "expiredCount" to classes.count{it.end<=now&&it.id !in handled},
            "consumedCount" to handled.size,
            "history" to (p.getString("history","")?:"").split("\n").filter{it.isNotBlank()},
            "tracking" to (status=="TRACKING"),"parked" to (status=="PARKED")
        )
    }
    @Synchronized fun action(context:Context,command:String):String{
        if(!context.packageName.endsWith(".vehicle.demo19.events"))
            throw SecurityException("FAKE chỉ có trên APK kiểm thử")
        if(command=="reset"){
            initialize(context,true)
            return "Đã đặt lại lịch và đồng hồ FAKE, không thay đổi dữ liệu xe thật."
        }
        initialize(context)
        val p=prefs(context)
        val now=p.getLong("clock",0L)
        val status=p.getString("status","WAITING")?:"WAITING"
        val current=p.getString("current","")?:""
        val handled=consumed(context)
        val classes=fixtures(p.getLong("base",0L)).filter{!it.online}
        fun candidate()=classes.firstOrNull{
            it.id !in handled&&it.end>now&&now>=it.start-120*60_000L
        }
        val event=when(command){
            "gate"->{
                if(status!="WAITING")throw IllegalStateException("Chỉ vào cổng khi đang WAITING")
                val lesson=candidate()?:throw IllegalStateException("Không có môn khả dụng")
                p.edit().putString("status","TRACKING").putString("current",lesson.id).apply()
                notifyFake(context,"Xe vào phạm vi",lesson.name,8911)
                "Xe vào phạm vi → TRACKING ("+lesson.name+")"
            }
            "park"->{
                if(status!="TRACKING")throw IllegalStateException("Chưa có phiên TRACKING")
                p.edit().putString("status","PARKED").apply()
                notifyFake(context,"Đã xác định vị trí xe","Mô phỏng: không dùng GPS thật",8912)
                "Đã đỗ xe → khóa toàn bộ lịch tiếp theo"
            }
            "exit"->{
                if(status!="PARKED")throw IllegalStateException("Chỉ ra cổng khi đã đỗ")
                if(current.isNotEmpty())handled.add(current)
                p.edit().putStringSet("handled",handled.toSet())
                    .putString("status","WAITING").putString("current","").apply()
                notifyFake(context,"Xe ra cổng","Mở khóa hàng chờ mô phỏng",8913)
                "Xe ra cổng → bỏ môn cũ, chờ môn tiếp theo"
            }
            "expire"->{
                if(status=="PARKED")throw IllegalStateException("Đã đỗ xe: lịch phải bị khóa")
                val lesson=if(status=="TRACKING")classes.firstOrNull{it.id==current} else candidate()
                if(lesson==null)throw IllegalStateException("Không có môn khả dụng để hết giờ")
                handled.add(lesson.id)
                p.edit().putLong("clock",lesson.end+1000L)
                    .putStringSet("handled",handled.toSet())
                    .putString("status","WAITING").putString("current","").apply()
                "Môn "+lesson.name+" hết giờ mà chưa đỗ → xóa khỏi hàng chờ"
            }
            "next"->{
                if(status!="WAITING")throw IllegalStateException("Hãy kết thúc lượt trước")
                val next=classes.firstOrNull{it.id !in handled&&it.end>now}
                    ?:throw IllegalStateException("Đã hết lịch mô phỏng")
                val target=next.start-30*60_000L
                if(target>now)p.edit().putLong("clock",target).apply()
                "Đã chuyển đồng hồ FAKE tới "+next.name
            }
            else->throw IllegalArgumentException("Sự kiện FAKE không hợp lệ")
        }
        log(context,event)
        return "[FAKE TEST] "+event
    }
}
