package com.lonelychromosome.findbikepollingtest;

import android.content.*;
import android.os.Build;
import com.google.android.gms.location.GeofencingEvent;
import com.google.android.gms.location.Geofence;

public final class FenceReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context,Intent intent){
        if(!context.getSharedPreferences("trip",Context.MODE_PRIVATE).getBoolean("armed",false))return;
        GeofencingEvent event=GeofencingEvent.fromIntent(intent);
        if(event==null || event.hasError()){
            CampusFence.status(context,"Geofence chưa có vị trí hợp lệ");return;
        }
        if(event.getGeofenceTransition()==Geofence.GEOFENCE_TRANSITION_ENTER){
            CampusFence.status(context,"Vào vùng 100m · bắt đầu xác định đang đến trường");
            Intent service=new Intent(context,VehicleTrackService.class);
            service.setAction(VehicleTrackService.START);
            try{
                if(Build.VERSION.SDK_INT>=26) context.startForegroundService(service);
                else context.startService(service);
            }catch(Exception e){CampusFence.status(context,"Không khởi động được tracking: "+e.getClass().getSimpleName());}
        }
    }
}
