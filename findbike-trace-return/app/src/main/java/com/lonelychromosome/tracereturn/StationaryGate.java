package com.lonelychromosome.tracereturn;

import android.location.Location;
import android.os.SystemClock;
import java.util.ArrayDeque;

/**
 * Conservative extrapolation gate. Does not affect the correct NorthUp projection
 * or destination; it only decides whether the GPS movement vector is trustworthy.
 *
 * No step sensor available/permission: stronger GPS-only confirmation required.
 * A user standing still must not move due to one noisy position or phone rotation.
 */
final class StationaryGate {
    private final ArrayDeque<Location> recent=new ArrayDeque<>();
    private long lastStepNanos=0, lastMotionNanos=0;
    private int stepCount=0, gpsOnlyStreak=0;
    private boolean stepSensorActive=false, verified=false;
    private float courseDegrees=0, speedMetersPerSecond=0;

    void reset(){
        recent.clear();lastStepNanos=lastMotionNanos=0;
        stepCount=gpsOnlyStreak=0;verified=false;
        courseDegrees=speedMetersPerSecond=0f;
        stepSensorActive=false;
    }
    void setStepSensorActive(boolean yes){stepSensorActive=yes;}
    void onStep(long t){
        if(t<=0)t=SystemClock.elapsedRealtimeNanos();
        if(lastStepNanos==0||t-lastStepNanos>3_000_000_000L)stepCount=1;
        else stepCount=Math.min(12,stepCount+1);
        lastStepNanos=t;
    }
    private boolean recentlyStepping(){
        long age=SystemClock.elapsedRealtimeNanos()-lastStepNanos;
        return stepCount>=2 && lastStepNanos>0&&age>=0&&age<2_500_000_000L;
    }
    void observe(Location loc){
        if(loc==null||loc.getElapsedRealtimeNanos()<=0)return;
        long t=loc.getElapsedRealtimeNanos();
        long age=SystemClock.elapsedRealtimeNanos()-t;
        if(age<0||age>2_500_000_000L||!loc.hasAccuracy()||loc.getAccuracy()>22f)return;
        if(!recent.isEmpty()&&t<=recent.getLast().getElapsedRealtimeNanos())return;
        recent.addLast(new Location(loc));
        while(recent.size()>30||(recent.size()>1&&
            t-recent.getFirst().getElapsedRealtimeNanos()>12_000_000_000L))
            recent.removeFirst();
        boolean hasAccurateSpeed=loc.hasSpeed()&&loc.getSpeed()>.85f&&
            loc.getSpeed()<3.5f&&loc.hasSpeedAccuracy()&&
            loc.getSpeedAccuracyMetersPerSecond()<.65f;
        boolean confirmedByGps=false;
        float selectedCourse=0f,selectedSpeed=0f;

        // GPS movement must exceed location uncertainty over several seconds.
        // A 1-m jump during a noisy fix will never count as walking.
        for(Location previous:recent){
            double dt=(t-previous.getElapsedRealtimeNanos())*1e-9;
            if(dt<2.5 || dt>10.0 || !previous.hasAccuracy())continue;
            float displacement=previous.distanceTo(loc);
            float noise=(float)Math.hypot(previous.getAccuracy(),loc.getAccuracy());
            float needed=Math.max(recentlyStepping()?3.5f:8.0f,
                noise*(recentlyStepping() ? 0.95f:1.75f));
            float speed=(float)(displacement/dt);
            if(displacement>needed && speed>.6f && speed<3.5f){
                confirmedByGps=true;
                selectedCourse=previous.bearingTo(loc);
                selectedSpeed=speed;
                break;
            }
        }
        if(confirmedByGps){
            if(recentlyStepping()){
                // Cadence + movement across multiple GPS fixes.
                gpsOnlyStreak=0;
                publish(selectedCourse,selectedSpeed,t);
            }else if(!stepSensorActive && hasAccurateSpeed){
                // Sensor not available: consecutive fixes plus high-confidence speed.
                gpsOnlyStreak=Math.min(10,gpsOnlyStreak+1);
                if(gpsOnlyStreak>=2)publish(selectedCourse,selectedSpeed,t);
            }else{
                gpsOnlyStreak=0;
            }
        }else if(!recentlyStepping()){
            gpsOnlyStreak=0;
        }
        // Note: previous verified course is automatically invalid when steps stop.
    }
    private void publish(float course,float speed,long stamp){
        courseDegrees=((course%360)+360)%360;
        speedMetersPerSecond=speed;
        lastMotionNanos=stamp;
        verified=true;
    }
    boolean hasVerifiedWalkingMotion(){
        if(!verified)return false;
        long now=SystemClock.elapsedRealtimeNanos();
        long age=now-lastMotionNanos;
        if(age<0||age>2_500_000_000L)return false;
        if(stepSensorActive&&!recentlyStepping())return false;
        return true;
    }
    float getCourseDegrees(){return courseDegrees;}
    float getSpeedMetersPerSecond(){return speedMetersPerSecond;}
}
