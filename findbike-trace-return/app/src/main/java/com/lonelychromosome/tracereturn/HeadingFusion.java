package com.lonelychromosome.tracereturn;

import android.location.Location;
import android.os.SystemClock;
import java.util.ArrayDeque;

/**
 * A course-over-ground estimator. It NEVER treats compass orientation
 * as the direction a stationary person is looking.
 *
 * Signals:
 *  - Step detector: movement evidence only (no absolute heading).
 *  - Linear acceleration: weak movement evidence only.
 *  - Multiple high-quality GPS points: verified course-over-ground.
 *  - Strong, consistent GPS reported speed+bearing: early course candidate.
 *
 * When direction is not reliable, return NO course rather than a guessed one.
 */
final class HeadingFusion {
    private final ArrayDeque<Location> gps=new ArrayDeque<>();
    private long lastStepNs=0, lastShakeNs=0, lastGpsMoveNs=0, lastCourseNs=0;
    private float lastSpeedHeading=Float.NaN;
    private long lastSpeedHeadingNs=0;
    private float courseDeg=Float.NaN, speedMps=0f;
    private boolean hasCourse=false;
    private int stepEvidenceCount=0;

    void reset(){
        gps.clear();
        lastStepNs=lastShakeNs=lastGpsMoveNs=lastCourseNs=0;
        lastSpeedHeading=Float.NaN;
        lastSpeedHeadingNs=0;courseDeg=Float.NaN;speedMps=0f;
        hasCourse=false;stepEvidenceCount=0;
    }
    private long now(){return SystemClock.elapsedRealtimeNanos();}
    private boolean recent(long stamp,long durationNs){
        return stamp>0 && now()-stamp>=0 && now()-stamp<durationNs;
    }
    void observeStep(long timeNs){
        if(timeNs<=0)timeNs=now();
        if(lastStepNs==0 || timeNs-lastStepNs>4_000_000_000L)
            stepEvidenceCount=1;
        else stepEvidenceCount=Math.min(10,stepEvidenceCount+1);
        lastStepNs=timeNs;
    }
    void observeAcceleration(long timeNs,float x,float y,float z){
        // Acceleration/shaking alone cannot establish a heading.
        float mag=(float)Math.sqrt(x*x+y*y+z*z);
        if(mag>1.6f)lastShakeNs=timeNs>0?timeNs:now();
    }
    boolean isWalking(){
        boolean stepped=recent(lastStepNs,3_500_000_000L);
        boolean gpsMoving=recent(lastGpsMoveNs,3_500_000_000L);
        return stepped||gpsMoving;
    }
    boolean isShaking(){
        return !isWalking() && recent(lastShakeNs,1_200_000_000L);
    }
    boolean isStill(){return !isWalking()&&!isShaking();}
    boolean hasReliableCourse(){
        return isWalking() && hasCourse && recent(lastCourseNs,3_500_000_000L);
    }
    float getCourse(){return courseDeg;}
    float getSpeed(){return speedMps;}
    int stepCount(){return stepEvidenceCount;}

    private static float signedDiff(float a,float b){
        return ((a-b+540f)%360f)-180f;
    }
    private void publish(float heading,float speed,long timeNs){
        if(!Float.isFinite(heading)||!Float.isFinite(speed))return;
        if(speed<.55f||speed>3.7f)return;
        float next=(heading+360f)%360f;
        if(!hasCourse || timeNs-lastCourseNs>5_000_000_000L){
            courseDeg=next;
        }else{
            float difference=signedDiff(next,courseDeg);
            if(Math.abs(difference)>125f && timeNs-lastCourseNs<1_000_000_000L)
                return; // reject one abrupt contradictory heading within 1s
            courseDeg=(courseDeg+0.43f*difference+360f)%360f;
        }
        speedMps=speedMps<=0?speed:0.55f*speedMps+0.45f*speed;
        hasCourse=true;lastCourseNs=timeNs;
        lastGpsMoveNs=timeNs;
    }

    void observeLocation(Location location){
        if(location==null||location.getElapsedRealtimeNanos()<=0)return;
        float accuracy=location.hasAccuracy()?location.getAccuracy():1000f;
        long t=location.getElapsedRealtimeNanos(),age=now()-t;
        if(age<0||age>5_000_000_000L||accuracy>24f)return;
        if(!gps.isEmpty() && t<=gps.getLast().getElapsedRealtimeNanos())return;
        Location point=new Location(location);
        gps.addLast(point);
        while(gps.size()>32 || (!gps.isEmpty()&&t-gps.getFirst().getElapsedRealtimeNanos()>18_000_000_000L))
            gps.removeFirst();

        // Prefer displacements across several seconds, instead of successive
        // GPS jitter points. Require travel beyond the combined error radius.
        for(Location prev:gps){
            double dt=(t-prev.getElapsedRealtimeNanos())/1e9;
            if(dt<3.5||dt>14.0)continue;
            if(!prev.hasAccuracy()||prev.getAccuracy()>24f)continue;
            float d=prev.distanceTo(point);
            float noise=(float)Math.hypot(prev.getAccuracy(),accuracy);
            float threshold=Math.max(6.5f,noise*(recent(lastStepNs,3_500_000_000L)?1.05f:1.55f));
            float v=(float)(d/dt);
            if(d>threshold && v>.65f && v<3.7f){
                publish(prev.bearingTo(point),v,t);
                break;
            }
        }

        // Early GPS speed+bearing is accepted only on a second consistent fix,
        // with reported speed and bearing uncertainties sufficiently small.
        boolean speedUsable=location.hasSpeed()&&location.getSpeed()>1.05f&&
            location.getSpeed()<3.7f && location.hasSpeedAccuracy()&&
            location.getSpeedAccuracyMetersPerSecond()<.55f&&
            location.hasBearing() && location.hasBearingAccuracy() &&
            location.getBearingAccuracyDegrees()<24f &&
            accuracy<15f;
        if(speedUsable){
            float bearing=location.getBearing();
            if(Float.isFinite(lastSpeedHeading) &&
                t-lastSpeedHeadingNs>450_000_000L &&
                t-lastSpeedHeadingNs<4_000_000_000L &&
                Math.abs(signedDiff(bearing,lastSpeedHeading))<32f){
                publish(bearing,location.getSpeed(),t);
            }
            lastSpeedHeading=bearing;lastSpeedHeadingNs=t;
        }else if(t-lastSpeedHeadingNs>4_000_000_000L){
            lastSpeedHeading=Float.NaN;lastSpeedHeadingNs=0;
        }
    }
}
