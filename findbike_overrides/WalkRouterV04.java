package com.bpa.findbike;

import android.content.res.AssetManager;
import android.graphics.PointF;
import java.io.DataInputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.PriorityQueue;

/** FindMyBike 0.4: always allow entering roads through yellow footprints,
 * then navigate ON the lane network to its closest point to the bike. */
final class WalkRouter {
    static final class Result {
        final ArrayList<PointF> points = new ArrayList<>();
        PointF laneTarget = new PointF();
        float bikeGap;
        boolean fallback;
    }
    private static final int[] DX={-1,0,1,1,1,0,-1,-1};
    private static final int[] DY={-1,-1,-1,0,1,1,1,0};
    private int width,height;
    private int[] xs=new int[0], ys=new int[0], grid=new int[0];
    private static final class Node {
        final int id;
        final float cost;
        Node(int id,float cost){this.id=id;this.cost=cost;}
    }
    WalkRouter(AssetManager assets) {
        try(DataInputStream in=new DataInputStream(assets.open("lanes.bin"))) {
            width=in.readUnsignedShort();height=in.readUnsignedShort();
            int n=in.readUnsignedShort();
            xs=new int[n];ys=new int[n];
            grid=new int[width*height];Arrays.fill(grid,-1);
            for(int i=0;i<n;i++) {
                xs[i]=in.readUnsignedShort();ys[i]=in.readUnsignedShort();
                grid[ys[i]*width+xs[i]]=i;
            }
        }catch(Exception e){xs=new int[0];ys=new int[0];}
    }
    private PointF at(int id){return new PointF(xs[id]*2f,ys[id]*2f);}
    private static float distance(PointF a,PointF b) {
        return (float)Math.hypot(a.x-b.x,a.y-b.y);
    }
    private int closest(PointF p) {
        float best=Float.MAX_VALUE;int result=-1;
        for(int i=0;i<xs.length;i++) {
            float dx=xs[i]*2f-p.x,dy=ys[i]*2f-p.y;
            float d=dx*dx+dy*dy;
            if(d<best){best=d;result=i;}
        }
        return result;
    }
    Result route(PointF person,PointF bike) {
        Result r=new Result();
        r.points.add(new PointF(person.x,person.y));
        if(xs.length==0) {
            r.fallback=true;
            r.laneTarget=new PointF(bike.x,bike.y);
            r.points.add(r.laneTarget);
            return r;
        }
        int target=closest(bike);
        r.laneTarget=at(target);
        r.bikeGap=distance(r.laneTarget,bike);
        int n=xs.length;
        float[] costs=new float[n];Arrays.fill(costs,Float.POSITIVE_INFINITY);
        int[] next=new int[n];Arrays.fill(next,-1);
        boolean[] done=new boolean[n];
        PriorityQueue<Node> heap=new PriorityQueue<>(Comparator.comparingDouble(x->x.cost));
        costs[target]=0f;heap.add(new Node(target,0f));
        while(!heap.isEmpty()) {
            Node node=heap.poll();
            int u=node.id;
            if(done[u])continue;
            done[u]=true;
            for(int k=0;k<8;k++) {
                int x=xs[u]+DX[k], y=ys[u]+DY[k];
                if(x<0||y<0||x>=width||y>=height)continue;
                int v=grid[y*width+x];
                if(v<0||done[v])continue;
                float len=(DX[k]==0||DY[k]==0)?2f:2.828427f;
                float candidate=costs[u]+len;
                if(candidate<costs[v]){
                    costs[v]=candidate;next[v]=u;
                    heap.add(new Node(v,candidate));
                }
            }
        }
        int nearest=closest(person);
        float direct=distance(person,bike);
        float minLane=Math.min(110f,Math.max(24f,direct*.22f));
        int entry=nearest;
        if(distance(person,at(nearest))>14f) {
            float best=Float.POSITIVE_INFINITY;
            for(int i=0;i<n;i++){
                if(costs[i]<minLane||!Float.isFinite(costs[i]))continue;
                float approach=distance(person,at(i));
                float score=approach*1.16f+costs[i];
                if(score<best){best=score;entry=i;}
            }
        }
        PointF approach=at(entry);
        if(distance(person,approach)>1f)r.points.add(approach);
        ArrayList<PointF> road=new ArrayList<>();
        int id=entry;
        while(id!=-1){
            road.add(at(id));
            if(id==target)break;
            id=next[id];
        }
        if(road.isEmpty()||id!=target) {
            r.fallback=true;
            r.points.clear();
            r.points.add(new PointF(person.x,person.y));
            r.points.add(new PointF(r.laneTarget.x,r.laneTarget.y));
            return r;
        }
        ArrayList<PointF> reduced=new ArrayList<>();
        if(road.size()>1) {
            simplify(road,0,road.size()-1,2.2f,reduced);
            reduced.add(road.get(road.size()-1));
        }else reduced.add(road.get(0));
        for(PointF p:reduced) {
            if(distance(r.points.get(r.points.size()-1),p)>.75f)r.points.add(p);
        }
        if(distance(r.points.get(r.points.size()-1),r.laneTarget)>.5f)r.points.add(r.laneTarget);
        if(r.points.size()==1)r.points.add(new PointF(r.laneTarget.x,r.laneTarget.y));
        return r;
    }
    private static void simplify(ArrayList<PointF> points,int a,int b,float tol,ArrayList<PointF> out){
        PointF p=points.get(a),q=points.get(b);
        float dx=q.x-p.x,dy=q.y-p.y,den=dx*dx+dy*dy;
        float largest=tol;int index=-1;
        for(int i=a+1;i<b;i++){
            PointF t=points.get(i);
            float v=den<.001f?0:Math.max(0f,Math.min(1f,((t.x-p.x)*dx+(t.y-p.y)*dy)/den));
            float e=(float)Math.hypot(t.x-p.x-v*dx,t.y-p.y-v*dy);
            if(e>largest){largest=e;index=i;}
        }
        if(index<0)out.add(p);
        else{simplify(points,a,index,tol,out);simplify(points,index,b,tol,out);}
    }
}
