package vn.edu.phenikaa.better_phenikaa_schedule.findbike

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

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