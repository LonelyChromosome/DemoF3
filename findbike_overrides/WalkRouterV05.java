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
        PointF safeStart = new PointF();
        boolean adjustedStart;
        String error = "";
    }
    private static final int[] DX={-1,0,1,1,1,0,-1,-1};
    private static final int[] DY={-1,-1,-1,0,1,1,1,0};
    private int width,height,gw,gh;
    private boolean[] blocked=new boolean[0];
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
        try(DataInputStream in=new DataInputStream(assets.open("blocked_grey.bin"))){
            gw=in.readUnsignedShort();gh=in.readUnsignedShort();
            byte[] bits=new byte[(gw*gh+7)/8];in.readFully(bits);
            blocked=new boolean[gw*gh];
            for(int i=0;i<blocked.length;i++)blocked[i]=(bits[i/8]&(1<<(i%8)))!=0;
        }catch(Exception e){gw=0;gh=0;blocked=new boolean[0];}
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

    private boolean pass(int x,int y){
        return x>=0&&y>=0&&x<gw&&y<gh&&!blocked[y*gw+x];
    }
    private boolean safe(PointF p){return pass((int)(p.x/4f),(int)(p.y/4f));}
    private PointF center(int index){return new PointF((index%gw)*4f+2f,(index/gw)*4f+2f);}
    private boolean clear(PointF a,PointF b){
        float dist=distance(a,b);
        int n=Math.max(1,(int)Math.ceil(dist/1.5f));
        for(int i=0;i<=n;i++){
            float t=(float)i/n;
            if(!pass((int)((a.x+(b.x-a.x)*t)/4f),(int)((a.y+(b.y-a.y)*t)/4f)))return false;
        }
        return true;
    }
    private PointF project(PointF p){
        int x=Math.max(0,Math.min(gw-1,(int)(p.x/4f)));
        int y=Math.max(0,Math.min(gh-1,(int)(p.y/4f)));
        if(pass(x,y))return new PointF(p.x,p.y);
        for(int r=1;r<Math.max(gw,gh);r++){
            float best=Float.POSITIVE_INFINITY;
            PointF result=null;
            for(int dy=-r;dy<=r;dy++)for(int dx=-r;dx<=r;dx++){
                if(Math.max(Math.abs(dx),Math.abs(dy))!=r||!pass(x+dx,y+dy))continue;
                PointF q=new PointF((x+dx)*4f+2f,(y+dy)*4f+2f);
                float d=distance(q,p);
                if(d<best){best=d;result=q;}
            }
            if(result!=null)return result;
        }
        return p;
    }
    Result route(PointF person,PointF bike) {
        Result out=new Result();
        if(xs.length==0||gw==0||gh==0){
            out.error="Thiếu dữ liệu lane hoặc vùng cấm";return out;
        }
        PointF personSafe=project(person);
        out.safeStart=personSafe;
        out.adjustedStart=distance(person,personSafe)>1f;
        // Target is the closest reachable blue lane location to the parked bike.
        int target=-1;float min=Float.POSITIVE_INFINITY;
        for(int i=0;i<xs.length;i++){
            PointF q=at(i);
            if(!safe(q))continue;
            float d=distance(q,bike);
            if(d<min){min=d;target=i;}
        }
        if(target<0){out.error="Không tìm thấy lane gần xe";return out;}
        out.laneTarget=at(target);
        out.bikeGap=min;
        // Dijkstra backwards ON lanes; reject every edge touching a grey footprint.
        int n=xs.length;
        float[] score=new float[n];Arrays.fill(score,Float.POSITIVE_INFINITY);
        int[] next=new int[n];Arrays.fill(next,-1);
        boolean[] visited=new boolean[n];
        PriorityQueue<Node> road=new PriorityQueue<>(Comparator.comparingDouble(a->a.cost));
        score[target]=0f;road.add(new Node(target,0f));
        while(!road.isEmpty()){
            Node e=road.poll();int u=e.id;
            if(visited[u])continue;
            visited[u]=true;
            PointF a=at(u);
            for(int k=0;k<8;k++){
                int x=xs[u]+DX[k],y=ys[u]+DY[k];
                if(x<0||y<0||x>=width||y>=height)continue;
                int v=grid[y*width+x];
                if(v<0||visited[v]||!clear(a,at(v)))continue;
                float value=e.cost+((DX[k]==0||DY[k]==0)?2f:2.828427f);
                if(value<score[v]){score[v]=value;next[v]=u;road.add(new Node(v,value));}
            }
        }
        // Dijkstra across ONLY legal white/yellow/blue cells to find a good lane entrance.
        // No line-to-lane shortcuts: each approach edge respects the grey obstacle mask.
        int total=gw*gh;
        float[] walkCost=new float[total];Arrays.fill(walkCost,Float.POSITIVE_INFINITY);
        int[] prev=new int[total];Arrays.fill(prev,-1);
        boolean[] seen=new boolean[total];
        int from=Math.max(0,Math.min(gh-1,(int)(personSafe.y/4f)))*gw
                 +Math.max(0,Math.min(gw-1,(int)(personSafe.x/4f)));
        PriorityQueue<Node> free=new PriorityQueue<>(Comparator.comparingDouble(a->a.cost));
        walkCost[from]=0f;free.add(new Node(from,0f));
        float minLane=Math.min(80f,Math.max(18f,distance(personSafe,bike)*.12f));
        float best=Float.POSITIVE_INFINITY, backup=Float.POSITIVE_INFINITY;
        int bestEntry=-1,bestCell=-1,backupEntry=-1,backupCell=-1;
        while(!free.isEmpty()){
            Node q=free.poll();int cell=q.id;
            if(seen[cell])continue;
            if(q.cost>best)break;
            seen[cell]=true;
            PointF cp=center(cell);
            // Search existing road nodes within the current 4x4 free cell.
            for(int r=0;r<n;r++){
                if(!Float.isFinite(score[r]))continue;
                PointF point=at(r);
                if(Math.abs(point.x-cp.x)>4f||Math.abs(point.y-cp.y)>4f)continue;
                if(!clear(cp,point))continue;
                float proposed=q.cost+distance(cp,point)*1.25f+score[r];
                if(proposed<backup){backup=proposed;backupEntry=r;backupCell=cell;}
                if(score[r]>=minLane&&proposed<best){
                    best=proposed;bestEntry=r;bestCell=cell;
                }
            }
            int ux=cell%gw,uy=cell/gw;
            for(int k=0;k<8;k++){
                int vx=ux+DX[k],vy=uy+DY[k];
                if(!pass(vx,vy))continue;
                if(DX[k]!=0&&DY[k]!=0&&(!pass(ux+DX[k],uy)||!pass(ux,uy+DY[k])))continue;
                int v=vy*gw+vx;
                if(seen[v])continue;
                float nd=q.cost+((DX[k]==0||DY[k]==0)?5.04f:7.12764f);
                if(nd<walkCost[v]){walkCost[v]=nd;prev[v]=cell;free.add(new Node(v,nd));}
            }
        }
        if(bestEntry<0){bestEntry=backupEntry;bestCell=backupCell;}
        if(bestEntry<0){out.error="Không tìm được lối tránh nhà xám";return out;}
        ArrayList<PointF> approach=new ArrayList<>();
        for(int at=bestCell;at!=-1;at=prev[at]){
            approach.add(center(at));
            if(at==from)break;
        }
        Collections.reverse(approach);
        out.points.add(new PointF(personSafe.x,personSafe.y));
        // Merge only line-of-sight free-walking steps.
        int index=0;
        while(index<approach.size()){
            int furthest=index;
            for(int j=index;j<approach.size();j++){
                if(!clear(out.points.get(out.points.size()-1),approach.get(j)))break;
                furthest=j;
            }
            PointF q=approach.get(furthest);
            if(!clear(out.points.get(out.points.size()-1),q)){
                out.error="Phát hiện đường nối không hợp lệ";out.points.clear();return out;
            }
            if(distance(q,out.points.get(out.points.size()-1))>1f)out.points.add(q);
            index=furthest+1;
        }
        PointF entry=at(bestEntry);
        if(!clear(out.points.get(out.points.size()-1),entry)){
            out.error="Không thể vào lane an toàn";out.points.clear();return out;
        }
        if(distance(entry,out.points.get(out.points.size()-1))>1f)out.points.add(entry);
        int id=bestEntry;
        for(int steps=0;steps<n&&id!=target;steps++){
            int v=next[id];
            if(v<0||!clear(at(id),at(v))){
                out.error="Lane không thể đi qua";out.points.clear();return out;
            }
            PointF q=at(v);
            if(distance(q,out.points.get(out.points.size()-1))>.5f)out.points.add(q);
            id=v;
        }
        if(id!=target){out.error="Lane không nối tới vị trí gần xe";out.points.clear();return out;}
        // Remove collinear tiny steps ONLY; never smooth diagonally across grey.
        for(int k=1;k+1<out.points.size();){
            PointF a=out.points.get(k-1),b=out.points.get(k),c=out.points.get(k+1);
            if(distance(a,b)+distance(b,c)-distance(a,c)<.025f&&clear(a,c))out.points.remove(k);
            else k++;
        }
        for(int i=1;i<out.points.size();i++){
            if(!clear(out.points.get(i-1),out.points.get(i))){
                out.error="Tuyến cắt khối xám: đã hủy";out.points.clear();return out;
            }
        }
        if(out.points.size()==1)out.points.add(out.laneTarget);
        return out;
    }
}