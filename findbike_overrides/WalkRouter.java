package com.bpa.findbike;

import android.content.res.AssetManager;
import android.graphics.PointF;
import java.io.DataInputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.PriorityQueue;

/** All map areas, including yellow buildings, are walkable.
 * Lane corridors only offer a small routing preference. */
final class WalkRouter {
    private static final int CELL=8, W=182, H=137, COUNT=W*H;
    private static final float ROAD_FACTOR=.78f;
    private static final int[] DX={-1,0,1,1,1,0,-1,-1};
    private static final int[] DY={-1,-1,-1,0,1,1,1,0};
    private final boolean[] road=new boolean[COUNT];

    WalkRouter(AssetManager assets) {
        try (DataInputStream in=new DataInputStream(assets.open("lanes.bin"))) {
            in.readUnsignedShort(); in.readUnsignedShort();
            int n=in.readUnsignedShort();
            for(int i=0;i<n;i++) {
                int x=Math.round(in.readUnsignedShort()/4f);
                int y=Math.round(in.readUnsignedShort()/4f);
                for(int dy=-2;dy<=2;dy++) for(int dx=-2;dx<=2;dx++) {
                    if(dx*dx+dy*dy>4) continue;
                    int nx=x+dx,ny=y+dy;
                    if(nx>=0&&ny>=0&&nx<W&&ny<H)road[ny*W+nx]=true;
                }
            }
        } catch(Exception ignored) {}
    }
    private static int clamp(int v,int limit){return Math.max(0,Math.min(limit,v));}
    private static float dist(PointF a,PointF b){return (float)Math.hypot(a.x-b.x,a.y-b.y);}
    private static float h(int x,int y,int gx,int gy){
        return ROAD_FACTOR*(float)Math.hypot(gx-x,gy-y);
    }
    private static final class Q {
        final int id; final float f;
        Q(int id,float f){this.id=id;this.f=f;}
    }
    ArrayList<PointF> route(PointF start,PointF finish) {
        ArrayList<PointF> out=new ArrayList<>();
        out.add(new PointF(start.x,start.y));
        if(dist(start,finish)<12f){out.add(new PointF(finish.x,finish.y));return out;}
        int sx=clamp(Math.round(start.x/CELL),W-1),sy=clamp(Math.round(start.y/CELL),H-1);
        int gx=clamp(Math.round(finish.x/CELL),W-1),gy=clamp(Math.round(finish.y/CELL),H-1);
        int origin=sy*W+sx,target=gy*W+gx;
        float[] score=new float[COUNT];Arrays.fill(score,Float.POSITIVE_INFINITY);
        int[] parent=new int[COUNT];Arrays.fill(parent,-1);
        boolean[] closed=new boolean[COUNT];
        PriorityQueue<Q> open=new PriorityQueue<>(Comparator.comparingDouble(a->a.f));
        score[origin]=0f;open.add(new Q(origin,h(sx,sy,gx,gy)));
        while(!open.isEmpty()){
            int u=open.poll().id;
            if(closed[u])continue;
            closed[u]=true;
            if(u==target)break;
            int ux=u%W,uy=u/W;
            for(int k=0;k<8;k++){
                int nx=ux+DX[k],ny=uy+DY[k];
                if(nx<0||ny<0||nx>=W||ny>=H)continue;
                int v=ny*W+nx;
                if(closed[v])continue;
                float factor=road[u]&&road[v]?ROAD_FACTOR:1f;
                float length=(DX[k]==0||DY[k]==0)?1f:1.41421356f;
                float next=score[u]+length*factor;
                if(next<score[v]){
                    score[v]=next;parent[v]=u;
                    open.add(new Q(v,next+h(nx,ny,gx,gy)));
                }
            }
        }
        if(origin!=target&&parent[target]<0){
            out.add(new PointF(finish.x,finish.y));return out;
        }
        ArrayList<PointF> nodes=new ArrayList<>();
        for(int at=target;at!=-1;at=parent[at]){
            nodes.add(new PointF((at%W)*CELL,(at/W)*CELL));
            if(at==origin)break;
        }
        Collections.reverse(nodes);
        ArrayList<PointF> smooth=new ArrayList<>();
        if(!nodes.isEmpty()){
            simplify(nodes,0,nodes.size()-1,6f,smooth);
            smooth.add(nodes.get(nodes.size()-1));
        }
        for(PointF p:smooth)if(dist(out.get(out.size()-1),p)>1.5f)out.add(p);
        out.add(new PointF(finish.x,finish.y));
        return out;
    }
    private static void simplify(ArrayList<PointF> list,int first,int last,float tol,ArrayList<PointF> out){
        PointF a=list.get(first),b=list.get(last);
        float dx=b.x-a.x,dy=b.y-a.y,den=dx*dx+dy*dy;
        float max=tol;int where=-1;
        for(int i=first+1;i<last;i++){
            PointF p=list.get(i);
            float t=den==0?0:Math.max(0,Math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/den));
            float error=(float)Math.hypot(p.x-a.x-t*dx,p.y-a.y-t*dy);
            if(error>max){max=error;where=i;}
        }
        if(where<0)out.add(a);
        else{simplify(list,first,where,tol,out);simplify(list,where,last,tol,out);}
    }
}
