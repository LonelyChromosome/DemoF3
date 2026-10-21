package com.lonelychromosome.findbike.vfxdemo;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.graphics.*;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import java.util.Random;

/**
 * A real-time, native Canvas animation of Find My Bike scanning/loading VFX.
 * Deliberately NO GPS permissions: coordinates shown during lock-on are a
 * clearly labeled demo sample from the previous field-test screenshot.
 *
 * Sequence: dark themed gateway -> digital map scan -> candidates -> pixel
 * convergence -> lock-on -> luminous wipe into the clean Find Bike screen.
 */
public final class MainActivity extends Activity {
    private ScanScene scene;
    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_FULLSCREEN
            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
        scene=new ScanScene(this);
        setContentView(scene);
    }
    private static final class ScanScene extends View {
        static final float BASE_W=1080f, BASE_H=1920f, LENGTH=8.75f;
        static final int VOID=Color.rgb(8,4,16), VIOLET=Color.rgb(182,97,251);
        static final int PINK=Color.rgb(255,70,194), CYAN=Color.rgb(105,217,255);
        static final int WHITE=Color.rgb(246,238,255);
        private final Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Random rng=new Random(1307);
        private long start=SystemClock.uptimeMillis();
        private final float[] starsX=new float[68], starsY=new float[68], starsR=new float[68];
        private final float[] buildings=new float[168];
        private final float[] tileTimes=new float[21*27];
        private final float[] candidates={215,605,790,465,310,1100,820,800,265,1375,825,1400};
        private final Path roadA=new Path(),roadB=new Path(),roadC=new Path(),roadD=new Path();
        ScanScene(android.content.Context context){
            super(context);
            setLayerType(View.LAYER_TYPE_SOFTWARE,null);
            for(int i=0;i<starsX.length;i++){
                starsX[i]=rng.nextFloat()*BASE_W;
                starsY[i]=rng.nextFloat()*BASE_H;
                starsR[i]=.5f+rng.nextFloat()*2.5f;
            }
            for(int i=0;i<buildings.length;i+=4){
                buildings[i]=22+rng.nextInt(1010);
                buildings[i+1]=295+rng.nextInt(1145);
                buildings[i+2]=36+rng.nextInt(78);
                buildings[i+3]=48+rng.nextInt(110);
            }
            for(int row=0;row<27;row++)for(int col=0;col<21;col++){
                // Scan tiles enter in waves with spatial disorder, not a static overlay.
                tileTimes[row*21+col]=1.05f+col*.125f+
                    (float)Math.sin(row*.77f+col*.44f)*.22f+rng.nextFloat()*.25f;
            }
            roadA.moveTo(-100,675);roadA.cubicTo(230,530,455,850,1180,665);
            roadB.moveTo(-60,1190);roadB.cubicTo(355,1040,680,1335,1180,1240);
            roadC.moveTo(145,240);roadC.cubicTo(440,650,250,1120,620,1680);
            roadD.moveTo(910,250);roadD.cubicTo(570,560,890,970,550,1590);
        }
        private static float sat(float v){return Math.max(0f,Math.min(1f,v));}
        private static float ease(float a){a=sat(a);return a*a*(3-2*a);}
        private static float pulse(float x,float center,float width){
            return (float)Math.exp(-Math.pow((x-center)/width,2));
        }
        private static int rgb(int col,float alpha){
            return Color.argb(Math.round(255*sat(alpha)),Color.red(col),Color.green(col),Color.blue(col));
        }
        private void fill(Canvas c,int col,float a){
            if(a<=0)return;
            p.reset();p.setAntiAlias(true);p.setColor(rgb(col,a));
            c.drawRect(0,0,BASE_W,BASE_H,p);
        }
        private void line(Canvas c,float x,float y,float xx,float yy,int col,float alpha,float stroke){
            if(alpha<=0)return;
            p.reset();p.setAntiAlias(true);p.setColor(rgb(col,alpha));p.setStrokeWidth(stroke);
            p.setStrokeCap(Paint.Cap.ROUND);
            c.drawLine(x,y,xx,yy,p);
        }
        private void rect(Canvas c,float x,float y,float w,float h,int col,float alpha){
            if(alpha<=0)return;
            p.reset();p.setAntiAlias(true);p.setColor(rgb(col,alpha));
            c.drawRect(x,y,x+w,y+h,p);
        }
        private void rounded(Canvas c,float x,float y,float w,float h,float r,int col,float alpha,boolean stroke,float thickness){
            if(alpha<=0)return;
            p.reset();p.setAntiAlias(true);p.setColor(rgb(col,alpha));
            p.setStyle(stroke?Paint.Style.STROKE:Paint.Style.FILL);
            p.setStrokeWidth(thickness);
            c.drawRoundRect(x,y,x+w,y+h,r,r,p);
            p.setStyle(Paint.Style.FILL);
        }
        private void ring(Canvas c,float x,float y,float radius,int col,float alpha,float thickness){
            if(radius<=0||alpha<=0)return;
            p.reset();p.setAntiAlias(true);p.setColor(rgb(col,alpha));
            p.setStrokeWidth(thickness);p.setStyle(Paint.Style.STROKE);
            c.drawCircle(x,y,radius,p);
            p.setStyle(Paint.Style.FILL);
        }
        private void disk(Canvas c,float x,float y,float radius,int col,float alpha){
            if(alpha<=0)return;
            p.reset();p.setAntiAlias(true);p.setColor(rgb(col,alpha));
            c.drawCircle(x,y,radius,p);
        }
        private void txt(Canvas c,String message,float x,float y,float size,int col,float alpha,boolean bold,Paint.Align alignment){
            if(alpha<=0)return;
            p.reset();p.setAntiAlias(true);p.setColor(rgb(col,alpha));
            p.setTypeface(Typeface.create("sans-serif",bold?Typeface.BOLD:Typeface.NORMAL));
            p.setTextAlign(alignment);p.setTextSize(size);
            c.drawText(message,x,y,p);
        }
        private void path(Canvas c,Path shape,int col,float alpha,float width){
            if(alpha<=0)return;
            p.reset();p.setAntiAlias(true);p.setColor(rgb(col,alpha));
            p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(width);
            p.setStrokeCap(Paint.Cap.ROUND);
            c.drawPath(shape,p);p.setStyle(Paint.Style.FILL);
        }
        private void brackets(Canvas c,float x,float y,float radius,int col,float a,float thickness){
            float r=radius,k=radius*.34f;
            for(int sx=-1;sx<=1;sx+=2)for(int sy=-1;sy<=1;sy+=2){
                float cx=x+sx*r,cy=y+sy*r;
                line(c,cx,cy,cx-sx*k,cy,col,a,thickness);
                line(c,cx,cy,cx,cy-sy*k,col,a,thickness);
            }
        }
        private void glow(Canvas c,float x,float y,float rad,int col,float a){
            for(int i=4;i>=1;i--){
                disk(c,x,y,rad*(1+i*.65f),col,a*.025f);
            }
            disk(c,x,y,rad,col,a*.14f);
        }
        private void map(Canvas c,float t,float a){
            if(a<=0)return;
            // Animated ambient technical chart from pseudo buildings and roads.
            for(int row=0;row<20;row++) {
                float y=300+row*67f;
                line(c,0,y,1080,y,VIOLET,a*.085f,1f);
            }
            for(int col=0;col<19;col++){
                float x=col*60f;
                line(c,x,270,x,1600,VIOLET,a*.07f,1f);
            }
            for(int i=0;i<buildings.length;i+=4){
                float x=buildings[i],y=buildings[i+1],w=buildings[i+2],h=buildings[i+3];
                float alpha=a*(.20f+.06f*(float)Math.sin(t*1.8f+i));
                rounded(c,x+6,y+7,w,h,5,Color.BLACK,a*.28f,false,0);
                rounded(c,x,y,w,h,5,VIOLET,alpha*.34f,false,0);
                rounded(c,x,y,w,h,4,VIOLET,alpha*.85f,true,1.3f);
                line(c,x+5,y+7,x+w-5,y+7,PINK,a*.075f,1);
                line(c,x+w,y,x+w+7,y-10,VIOLET,a*.17f,2);
            }
            for(Path r:new Path[]{roadA,roadB,roadC,roadD}){
                path(c,r,PINK,a*.045f,25);
                path(c,r,VIOLET,a*.15f,11);
                path(c,r,VIOLET,a*.5f,2.4f);
            }
            for(int i=0;i<starsX.length;i++){
                float twinkle=.6f+.4f*(float)Math.sin(t*(1+i%3*.26f)+i*.75f);
                disk(c,starsX[i],starsY[i],starsR[i],VIOLET,a*.24f*twinkle);
            }
            // A wide interference sweep crosses the map and lights small cells.
            float sweep=260f+1280f*ease((t-.88f)/3.3f);
            for(int i=0;i<11;i++){
                float x=sweep-i*10f;
                line(c,x,294,x,1550,PINK,a*(.015f+i*.0015f),5);
            }
            line(c,sweep,295,sweep,1538,PINK,a*.26f,2.5f);
            // Unordered scan squares with a moving pulse and persistence decay.
            for(int row=0;row<27;row++)for(int col=0;col<21;col++){
                float start=tileTimes[row*21+col];
                float elapsed=t-start;
                if(elapsed<0||elapsed>2.7f)continue;
                float on=ease(elapsed/.16f)*(1f-ease((elapsed-.55f)/2.1f));
                float x=30+col*51,y=285+row*47;
                int color=(col+2*row)%5==0?CYAN:((row+col)%3==0?PINK:VIOLET);
                float size=(row+col)%5==0?9:6;
                glow(c,x,y,5,color,a*.6f*on);
                rect(c,x-size*.5f,y-size*.5f,size,size,color,a*.75f*on);
                if((col+row*3)%13==0)
                    rounded(c,x-11,y-11,22,22,1,color,a*.33f*on,true,1);
            }
        }
        private void candidates(Canvas c,float t,float a){
            if(t<1.7||a<=0)return;
            float appear=ease((t-1.65f)/.45f);
            float reject=ease((t-4.65f)/.6f);
            for(int i=0;i<candidates.length;i+=2){
                int idx=i/2;
                float x=candidates[i],y=candidates[i+1];
                float intensity=idx==3?1:1-reject;
                float flicker=.75f+.25f*(float)Math.sin(t*7+idx*1.3f);
                float alpha=a*appear*intensity*flicker;
                if(alpha<=0)continue;
                ring(c,x,y,26+12*(float)(t%1),PINK,alpha*.31f,1.2f);
                ring(c,x,y,46+15*(float)((t*.45f+idx*.2f)%1),VIOLET,alpha*.26f,2);
                brackets(c,x,y,29,idx==3?CYAN:VIOLET,alpha*.85f,2.6f);
                glow(c,x,y,5,idx==3?CYAN:PINK,alpha);
                rect(c,x-3,y-3,6,6,idx==3?CYAN:PINK,alpha);
                if(idx!=3&&reject>.05f){
                    line(c,x-9,y-9,x+9,y+9,PINK,a*reject*.85f,2);
                    line(c,x-9,y+9,x+9,y-9,PINK,a*reject*.85f,2);
                }
            }
        }
        private void lock(Canvas c,float t,float a){
            if(t<4.1f||a<=0)return;
            final float cx=550,cy=990;
            float converge=ease((t-4.15f)/1.65f);
            float targetAlpha=a*ease((t-4.2f)/.48f);
            glow(c,cx,cy,56,PINK,targetAlpha);
            for(int i=0;i<6;i++){
                float r=30+i*25f+(1-converge)*80;
                ring(c,cx,cy,r,i%2==0?PINK:VIOLET,targetAlpha*(.20f+i*.008f),2.5f);
            }
            for(int k=0;k<64;k++){
                float ang=(float)(k*2*Math.PI/64+t*(.6+(k%4)*.12));
                float radius=280*(1-converge)+58+(k%6)*8;
                float x=cx+(float)Math.cos(ang)*radius,y=cy+(float)Math.sin(ang)*radius;
                float sq=(k%4==0?10:5)*(1+.5f*converge);
                rect(c,x,y,sq,sq,k%5==0?CYAN:PINK,targetAlpha*(.4f+.5f*converge));
            }
            brackets(c,cx,cy,88-24*converge,PINK,targetAlpha,5);
            float scanRing=22+120*((t*1.65f)%1);
            ring(c,cx,cy,scanRing,CYAN,targetAlpha*.3f*(1-(scanRing-22)/130),2);
            disk(c,cx,cy,9,PINK,targetAlpha);
            // Final crosshairs
            line(c,cx-135,cy,cx-105,cy,PINK,targetAlpha*.6f,2);
            line(c,cx+105,cy,cx+135,cy,PINK,targetAlpha*.6f,2);
            line(c,cx,cy-135,cx,cy-105,PINK,targetAlpha*.6f,2);
            line(c,cx,cy+105,cx,cy+135,PINK,targetAlpha*.6f,2);
            if(t>5.45f){
                float q=ease((t-5.45f)/.4f)*a;
                rounded(c,290,1182,500,106,16,VOID,q*.9f,false,0);
                rounded(c,290,1182,500,106,16,PINK,q*.75f,true,1.8f);
                txt(c,"VỊ TRÍ ĐÃ ĐƯỢC KHÓA",540,1226,24,WHITE,q,true,Paint.Align.CENTER);
                txt(c,"20.959630   105.746592",540,1266,22,CYAN,q,false,Paint.Align.CENTER);
            }
        }
        private void top(Canvas c,float t,float a){
            txt(c,"BPA",90,125,53,WHITE,a,true,Paint.Align.LEFT);
            txt(c,"/ FIND MY BIKE",233,121,24,VIOLET,a*.85f,true,Paint.Align.LEFT);
            float blink=(float)(.78+.22*Math.sin(t*8));
            disk(c,987,104,7,t<5.45?PINK:CYAN,a*blink);
            line(c,84,155,996,155,VIOLET,a*.3f,1.5f);
            txt(c,t<4.8?"ĐỊNH VỊ ĐANG HOẠT ĐỘNG":"ĐÃ KHÓA MỤC TIÊU",
                92,247,38,WHITE,a,true,Paint.Align.LEFT);
            txt(c,t<4.8?"Đang rà soát vùng bản đồ":"Đang chuyển vào Tìm xe",
                92,294,22,VIOLET,a*.72f,false,Paint.Align.LEFT);
            // Thin progress bar is integrated with the scanner status, no modal dialog.
            rounded(c,95,1640,890,5,3,VIOLET,a*.23f,false,0);
            float progress=ease((t-.5f)/6.7f);
            rounded(c,95,1640,890*progress,5,3,PINK,a*.85f,false,0);
            txt(c,t<4.65?"ĐANG QUÉT  /  "+Math.round(progress*100)+"%":
                    t<5.45?"ĐANG HỘI TỤ TÍN HIỆU":"TARGET LOCKED",
                96,1700,23,t<5.4?VIOLET:CYAN,a*.86f,true,Paint.Align.LEFT);
            txt(c,"VFX DEMO  ·  TỌA ĐỘ MINH HỌA",984,1700,16,VIOLET,a*.6f,false,Paint.Align.RIGHT);
            // Minimal glowing boot chevrons
            for(int i=0;i<4;i++){
                int color=i==(int)((t*3)%4)?PINK:VIOLET;
                rounded(c,94+i*45,1750,34,9,4,color,a*(i==(int)((t*3)%4)?.9f:.15f),false,0);
            }
        }
        private void portal(Canvas c,float t){
            if(t>1.15f)return;
            float k=ease((t-.05f)/.7f);
            disk(c,540,930,85+600*k,VIOLET,(1-k)*.10f);
            ring(c,540,930,50+650*k,PINK,(1-k)*.7f,6);
            ring(c,540,930,90+500*k,VIOLET,(1-k)*.5f,2);
            fill(c,VOID,1-k);
        }
        private void whiteEnd(Canvas c,float t){
            float fade=ease((t-7.0f)/.72f);
            if(fade<=0)return;
            // A short bright pixel-disassembly wipe connects scan map to Find Bike.
            for(int y=0;y<1920;y+=65){
                for(int x=0;x<1080;x+=65){
                    float reveal=ease((fade*1.7f)-((x*0.30f+y*.65f)/1920f)*.72f);
                    if(reveal>.02f)rect(c,x,y,65,65,Color.WHITE,reveal);
                }
            }
            float screen=ease((t-7.64f)/.36f);
            if(screen<=0)return;
            fill(c,Color.rgb(250,250,251),screen);
            int dark=Color.rgb(24,45,61);
            int muted=Color.rgb(115,133,144);
            txt(c,"‹",74,170,78,dark,screen,false,Paint.Align.LEFT);
            txt(c,"Tìm xe",147,168,45,dark,screen,true,Paint.Align.LEFT);
            txt(c,"— m",540,420,115,dark,screen,true,Paint.Align.CENTER);
            txt(c,"Khoảng cách đến xe",540,475,24,muted,screen,false,Paint.Align.CENTER);
            float mx=408,my=1045,bx=716,by=753;
            p.reset();p.setAntiAlias(true);p.setStrokeWidth(5);p.setColor(rgb(muted,screen*.5f));
            p.setPathEffect(new DashPathEffect(new float[]{16,18},0));c.drawLine(mx,my,bx,by,p);
            p.setPathEffect(null);
            disk(c,mx,my,50,Color.rgb(60,137,246),screen*.10f);
            disk(c,mx,my,18,Color.rgb(60,137,246),screen);
            disk(c,bx,by,53,Color.rgb(251,170,59),screen*.13f);
            disk(c,bx,by,19,Color.rgb(251,170,59),screen);
            txt(c,"BẠN",mx,my+90,25,dark,screen,true,Paint.Align.CENTER);
            txt(c,"XE ĐỖ",bx,by-70,25,dark,screen,true,Paint.Align.CENTER);
            txt(c,"N ↑",540,600,22,muted,screen,false,Paint.Align.CENTER);
            txt(c,"ĐANG CHỜ GPS THẬT",540,1530,24,muted,screen,false,Paint.Align.CENTER);
            txt(c,"CHẠM ĐỂ PHÁT LẠI VFX",540,1710,24,Color.rgb(147,64,220),screen,true,Paint.Align.CENTER);
            txt(c,"BẢN PREVIEW VFX  ·  KHÔNG ĐỊNH VỊ THẬT",540,1800,17,muted,screen*.7f,false,Paint.Align.CENTER);
        }
        @Override protected void onDraw(Canvas raw){
            super.onDraw(raw);
            float scale=Math.min(getWidth()/BASE_W,getHeight()/BASE_H);
            raw.drawColor(VOID);
            raw.save();
            raw.translate((getWidth()-BASE_W*scale)/2,(getHeight()-BASE_H*scale)/2);
            raw.scale(scale,scale);
            float t=(SystemClock.uptimeMillis()-start)/1000f;
            t=Math.min(t,LENGTH+1.5f);
            // Base color gradients, vignette and ambient pulse are always animated.
            p.reset();p.setAntiAlias(true);
            p.setShader(new LinearGradient(0,0,1080,1920,
                new int[]{Color.rgb(9,5,20),Color.rgb(26,9,42),Color.rgb(9,5,20)},
                null,Shader.TileMode.CLAMP));
            raw.drawRect(0,0,1080,1920,p);p.setShader(null);
            glow(raw,540,945,200,PINK,.20f+.06f*(float)Math.sin(t*2.1f));
            float sceneAlpha=ease(t/.95f)*(1-ease((t-7.15f)/.62f));
            map(raw,t,sceneAlpha);
            candidates(raw,t,sceneAlpha);
            lock(raw,t,sceneAlpha);
            top(raw,t,sceneAlpha);
            portal(raw,t);
            whiteEnd(raw,t);
            raw.restore();
            if(t<LENGTH+.3f)postInvalidateOnAnimation();
        }
        @Override public boolean onTouchEvent(MotionEvent event){
            if(event.getAction()==MotionEvent.ACTION_UP){
                if((SystemClock.uptimeMillis()-start)/1000f>7.95f){
                    start=SystemClock.uptimeMillis();
                    invalidate();
                }
                return true;
            }
            return true;
        }
    }
}
