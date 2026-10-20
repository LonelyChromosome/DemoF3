package com.lonelychromosome.findbikepollingtest;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.hardware.*;
import android.location.*;
import android.os.*;
import java.util.*;

/**
 * Background parking detection.
 * 100m gate wakeup -> GPS approach -> verified gate crossing -> slow/stationary
 * -> sustained walking for 10 seconds -> commit the PRE-WALK stationary fix
 * -> STOP location/sensor updates. Does not claim sub-meter GPS accuracy.
 */
public final class VehicleTrackService extends Service implements LocationListener,SensorEventListener {
    public static final String START="com.lonelychromosome.findbikepollingtest.START_GPS";
    public static final String STOP="com.lonelychromosome.findbikepollingtest.STOP_GPS";
    private static final int CHANNEL_ID=15, NOTIFICATION_ID=1515;
    private static final long TRACK_TIMEOUT_MS=12*60*1000L;
    private LocationManager lm;
    private SensorManager sensors;
    private Sensor steps;
    private final Handler handler=new Handler(Looper.getMainLooper());
    private Location lastFix, parkedCandidate;
    private long started, stillFrom, walkFrom, lastStepAt, lastFixAt;
    private int stepCount=0, acceptedFixes=0;
    private boolean crossedGate=false, seenVehicleMotion=false, active=false;
    private double bestGateDistance=Double.POSITIVE_INFINITY;
    private int minGateIndex=-1;
    private final Runnable watchdog=new Runnable(){
        @Override public void run(){
            if(!active)return;
            if(SystemClock.elapsedRealtime()-started>TRACK_TIMEOUT_MS){
                end("Dừng tracking vì chưa xác nhận vào trường/đỗ sau 12 phút");
            }else handler.postDelayed(this,5000);
        }
    };

    @Override public void onCreate(){
        super.onCreate();
        lm=(LocationManager)getSystemService(LOCATION_SERVICE);
        sensors=(SensorManager)getSystemService(SENSOR_SERVICE);
        steps=sensors.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR);
        if(Build.VERSION.SDK_INT>=26){
            NotificationChannel c=new NotificationChannel("bike_parking","Theo dõi đỗ xe",NotificationManager.IMPORTANCE_LOW);
            ((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(c);
        }
    }
    private Notification notice(String message){
        Intent ui=new Intent(this,MainActivity.class);
        PendingIntent pending=PendingIntent.getActivity(this,0,ui,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder b=Build.VERSION.SDK_INT>=26?new Notification.Builder(this,"bike_parking"):new Notification.Builder(this);
        return b.setContentTitle("Find My Bike · nhận diện đỗ xe")
            .setContentText(message).setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pending).setOngoing(true).build();
    }
    @Override public int onStartCommand(Intent intent,int flags,int startId){
        if(intent!=null && STOP.equals(intent.getAction())){
            end("Đã tắt theo dõi tự động");return START_NOT_STICKY;
        }
        if(active)return START_NOT_STICKY;
        if(getSharedPreferences("trip",MODE_PRIVATE).getBoolean("armed",false)==false){
            stopSelf();return START_NOT_STICKY;
        }
        try{startForeground(NOTIFICATION_ID,notice("Đang kiểm tra đường vào trường"));}
        catch(Exception e){CampusFence.status(this,"FGS thất bại: "+e.getClass().getSimpleName());stopSelf();return START_NOT_STICKY;}
        if(checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED){
            end("Chưa cấp GPS chính xác");return START_NOT_STICKY;
        }
        started=SystemClock.elapsedRealtime();
        active=true;
        try {
            if(lm.isProviderEnabled(LocationManager.GPS_PROVIDER))
                lm.requestLocationUpdates(LocationManager.GPS_PROVIDER,900,0f,this,Looper.getMainLooper());
            if(lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
                lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER,1600,0f,this,Looper.getMainLooper());
        }catch(Exception e){end("Không thể nhận GPS: "+e.getMessage());return START_NOT_STICKY;}
        if(steps!=null && (Build.VERSION.SDK_INT<29 ||
             checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION)==PackageManager.PERMISSION_GRANTED))
            sensors.registerListener(this,steps,SensorManager.SENSOR_DELAY_NORMAL);
        else CampusFence.status(this,"Đang theo dõi GPS; thiếu cảm biến/quyền bước chân");
        handler.postDelayed(watchdog,5000);
        return START_NOT_STICKY;
    }

    @Override public void onLocationChanged(Location loc){
        if(!active || !loc.hasAccuracy() || loc.getAccuracy()>45f)return;
        long age=(SystemClock.elapsedRealtimeNanos()-loc.getElapsedRealtimeNanos())/1000000L;
        if(age<0 || age>4500)return;
        long now=SystemClock.elapsedRealtime();
        if(lastFix!=null) {
            long dtNs=loc.getElapsedRealtimeNanos()-lastFix.getElapsedRealtimeNanos();
            if(dtNs<=0)return;
            double sec=dtNs/1e9;
            float displacement=lastFix.distanceTo(loc);
            if(displacement>Math.max(24f,loc.getAccuracy()*2.2f)+sec*8 && sec<8)return;
        }
        double closest=Double.POSITIVE_INFINITY;
        int gate=-1;
        for(int i=0;i<CampusFence.GATES.length;i++){
            float[] d=new float[1];
            Location.distanceBetween(loc.getLatitude(),loc.getLongitude(),
                  CampusFence.GATES[i][0],CampusFence.GATES[i][1],d);
            if(d[0]<closest){closest=d[0];gate=i;}
        }
        if(closest<bestGateDistance){bestGateDistance=closest;minGateIndex=gate;}
        if(closest<=35 && loc.getAccuracy()<=25f)crossedGate=true;
        // Require a real gate crossing; being near a shop 100m away cannot save a bike.
        if(!crossedGate){
            CampusFence.status(this,String.format(Locale.US,
                "Đang tới trường · cách cổng %.0fm (vòng 100m)",closest));
            lastFix=new Location(loc);lastFixAt=now;return;
        }
        float speed=loc.hasSpeed()?loc.getSpeed():0f;
        if(lastFix!=null && !loc.hasSpeed()){
            double seconds=(loc.getElapsedRealtimeNanos()-lastFix.getElapsedRealtimeNanos())/1e9;
            if(seconds>0.2) speed=lastFix.distanceTo(loc)/(float)seconds;
        }
        if(loc.hasAccuracy() && loc.getAccuracy()>22) {
            // Do not let low quality GNSS overwrite parked candidate.
            lastFix=new Location(loc);lastFixAt=now;return;
        }
        // GPS motion alone is not proof of a vehicle. It only arms a possible stop.
        if(speed>=1.3f && speed<=20f){
            seenVehicleMotion=true;
            if(walkFrom==0){
                stillFrom=0;
                parkedCandidate=null;
            }
        }
        if(seenVehicleMotion && speed<0.65f && walkFrom==0) {
            if(stillFrom==0)stillFrom=now;
            if(now-stillFrom>=3000) parkedCandidate=new Location(loc);
        }
        if(seenVehicleMotion && stillFrom>0 && speed<0.65f && walkFrom==0) {
            // Keep latest good stopped coordinate while waiting for walking.
            if(now-stillFrom>=3000)parkedCandidate=new Location(loc);
        }
        if(walkFrom>0 && parkedCandidate!=null && now-walkFrom>=10000
              && stepCount>=6) {
            // Last confirmed stationary position is the saved bike anchor.
            double moved=parkedCandidate.distanceTo(loc);
            if(moved>=4.0 && moved<=200.0) {
                finishPark(now);
                return;
            }
        }
        CampusFence.status(this, walkFrom>0
            ? "Đang xác nhận đi bộ: "+Math.min(10,(now-walkFrom)/1000)+"s / 10s · bước "+stepCount
            : parkedCandidate!=null ? "Xe dừng · đợi phát hiện đi bộ" : "Đã qua cổng · đang theo dõi chuyển động");
        lastFix=new Location(loc);lastFixAt=now;acceptedFixes++;
    }
    @Override public void onSensorChanged(SensorEvent event){
        if(!active || event.sensor.getType()!=Sensor.TYPE_STEP_DETECTOR || !crossedGate)return;
        long now=SystemClock.elapsedRealtime();
        if(parkedCandidate==null)return;
        if(walkFrom==0){
            walkFrom=now;
            stepCount=0;
        }
        if(lastStepAt>0 && now-lastStepAt>3200){
            // Walking was interrupted, require another continuous 10 seconds.
            walkFrom=now;stepCount=0;
        }
        stepCount++;
        lastStepAt=now;
    }
    private void finishPark(long now){
        if(parkedCandidate==null)return;
        double lat=parkedCandidate.getLatitude(),lon=parkedCandidate.getLongitude();
        getSharedPreferences("bike",MODE_PRIVATE).edit()
            .putLong("lat",Double.doubleToRawLongBits(lat))
            .putLong("lon",Double.doubleToRawLongBits(lon))
            .putLong("savedAt",System.currentTimeMillis())
            .putBoolean("autoSaved",true).apply();
        end("Đã xác nhận đỗ · đi bộ 10s · GPS tracking đã dừng");
    }
    private void end(String reason){
        active=false;
        handler.removeCallbacks(watchdog);
        try{lm.removeUpdates(this);}catch(Exception ignored){}
        if(sensors!=null)sensors.unregisterListener(this);
        CampusFence.status(this,reason);
        try{stopForeground(STOP_FOREGROUND_REMOVE);}catch(Exception ignored){}
        stopSelf();
    }
    @Override public void onProviderEnabled(String provider){}
    @Override public void onProviderDisabled(String provider){}
    @Override public void onAccuracyChanged(Sensor sensor,int accuracy){}
    @Override public IBinder onBind(Intent intent){return null;}
    @Override public void onDestroy(){active=false;handler.removeCallbacks(watchdog);try{lm.removeUpdates(this);}catch(Exception ignored){}if(sensors!=null)sensors.unregisterListener(this);super.onDestroy();}
}
