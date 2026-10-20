package com.lonelychromosome.findbikepollingtest;

import android.Manifest;
import android.app.PendingIntent;
import android.content.*;
import android.content.pm.PackageManager;
import android.os.Build;
import com.google.android.gms.location.*;
import java.util.ArrayList;

/** Original REAL 1.4 entrance reference positions extracted from its APK. */
public final class CampusFence {
    public static final double[][] GATES = {
        {20.962668790883644, 105.74871859259113},
        {20.959607109088672, 105.74789745697416}
    };
    public static final float RADIUS_METERS = 100f;
    private CampusFence(){}

    public static void register(Context ctx) {
        final Context app=ctx.getApplicationContext();
        if (app.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED ||
            (Build.VERSION.SDK_INT>=29 &&
              app.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)!=PackageManager.PERMISSION_GRANTED)) {
            status(app,"Cần quyền vị trí chính xác + luôn cho phép để theo dõi geofence nền");
            return;
        }
        ArrayList<Geofence> fences=new ArrayList<>();
        for(int i=0;i<GATES.length;i++){
            fences.add(new Geofence.Builder()
                .setRequestId("GATE_"+(i+1))
                .setCircularRegion(GATES[i][0],GATES[i][1],RADIUS_METERS)
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
                .build());
        }
        GeofencingRequest request=new GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(fences).build();
        try {
            LocationServices.getGeofencingClient(app).addGeofences(request,pendingIntent(app))
                .addOnSuccessListener(unused->status(app,"Đã bật theo dõi 2 cổng · 100m"))
                .addOnFailureListener(e->status(app,"Geofence lỗi: "+e.getMessage()));
        }catch(SecurityException e){status(app,"Thiếu quyền định vị nền");}
    }
    static PendingIntent pendingIntent(Context ctx){
        Intent intent=new Intent(ctx,FenceReceiver.class);
        intent.setAction("com.lonelychromosome.findbikepollingtest.GATE_ENTER");
        return PendingIntent.getBroadcast(ctx,471,intent,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_MUTABLE);
    }
    public static void unregister(Context ctx){
        LocationServices.getGeofencingClient(ctx).removeGeofences(pendingIntent(ctx));
        status(ctx,"Đã tắt geofence");
    }
    public static void status(Context ctx,String text){
        ctx.getSharedPreferences("trip",Context.MODE_PRIVATE).edit().putString("status",text).apply();
    }
}
