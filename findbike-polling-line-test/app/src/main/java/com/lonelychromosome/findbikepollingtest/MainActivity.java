package com.lonelychromosome.findbikepollingtest;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.graphics.*;
import android.os.*;
import android.content.*;
import android.view.*;
import android.widget.*;
import java.util.Locale;

/**
 * Standalone real-device test. No map, no routing, no fake location.
 * Location updates are provider callbacks (not a busy polling loop).
 * The 100 ms loop extrapolates the marker for display only.
 */
public final class MainActivity extends Activity {
    private static final long GPS_INTERVAL_MS = 900L;
    private static final long NETWORK_INTERVAL_MS = 1500L;
    private static final long PREDICT_LIMIT_MS = 1200L;
    private LocationManager manager;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private Location lastReal;
    private long lastRealSeenMs = 0L;
    private long firstRequestMs = 0L, previousRealSeenMs = 0L;
    private double velocityEast = 0.0, velocityNorth = 0.0;
    private double bikeLat = Double.NaN, bikeLon = Double.NaN;
    private boolean activeGps = false, navigation = false, saveWhenFix = false, pendingArm = false;
    private String statusMessage = "Sẵn sàng";
    private TextView status;
    private LineView view;

    private final Runnable frame = new Runnable() {
        @Override public void run() {
            if (!navigation) return;
            view.invalidate();
            refreshStatus();
            handler.postDelayed(this, 100L);
        }
    };

    private final LocationListener listener = new LocationListener() {
        @Override public void onLocationChanged(Location loc) {
            acceptFix(loc);
        }
        @Override public void onProviderEnabled(String provider) {}
        @Override public void onProviderDisabled(String provider) { refreshStatus(); }
    };

    @Override public void onCreate(Bundle savedState) {
        super.onCreate(savedState);
        getWindow().setStatusBarColor(Color.WHITE);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
        getWindow().setNavigationBarColor(Color.WHITE);
        manager = (LocationManager) getSystemService(LOCATION_SERVICE);
        android.content.SharedPreferences p = getSharedPreferences("bike", MODE_PRIVATE);
        if (p.contains("lat") && p.contains("lon")) {
            bikeLat = Double.longBitsToDouble(p.getLong("lat",0));
            bikeLon = Double.longBitsToDouble(p.getLong("lon",0));
        }
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.WHITE);
        root.setPadding(dp(18),dp(18),dp(18),dp(22));
        TextView title = new TextView(this);
        title.setText("FIND MY BIKE");
        title.setTextColor(Color.rgb(18,22,28));
        title.setTextSize(23);
        title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        root.addView(title);
        TextView subtitle = new TextView(this);
        subtitle.setText("POLLING TEST 1.5  ·  GPS THẬT  ·  KHÔNG BẢN ĐỒ");
        subtitle.setTextSize(10);
        subtitle.setLetterSpacing(0.06f);
        subtitle.setTextColor(Color.rgb(117,126,137));
        root.addView(subtitle);
        view = new LineView(this);
        root.addView(view,new LinearLayout.LayoutParams(-1,0,1));
        status = new TextView(this);
        status.setTextSize(13);
        status.setTextColor(Color.rgb(71,80,94));
        status.setPadding(dp(3), dp(8), dp(3), dp(12));
        root.addView(status);
        LinearLayout controls = new LinearLayout(this);
        controls.setOrientation(LinearLayout.HORIZONTAL);
        controls.setGravity(Gravity.CENTER);
        Button save = makeButton("LƯU THỬ",Color.rgb(230,239,246),Color.rgb(19,33,45));
        Button find = makeButton("TÌM XE",Color.rgb(25,44,59),Color.WHITE);
        Button stop = makeButton("DỪNG",Color.rgb(245,246,248),Color.rgb(40,46,50));
        LinearLayout.LayoutParams weight = new LinearLayout.LayoutParams(0,dp(52),1);
        weight.setMargins(dp(3),0,dp(3),0);
        controls.addView(save,weight);
        LinearLayout.LayoutParams weight2 = new LinearLayout.LayoutParams(0,dp(52),1);
        weight2.setMargins(dp(3),0,dp(3),0);
        controls.addView(find,weight2);
        LinearLayout.LayoutParams weight3 = new LinearLayout.LayoutParams(0,dp(52),1);
        weight3.setMargins(dp(3),0,dp(3),0);
        controls.addView(stop,weight3);
        root.addView(controls);
        TextView foot = new TextView(this);
        foot.setText("Lưu xe tại một vị trí, đi bộ ra xa rồi bấm TÌM XE. Nhấn giữ LƯU XE để xóa điểm đã lưu.");
        foot.setTextSize(11);
        foot.setTextColor(Color.rgb(129,139,151));
        foot.setPadding(dp(4),dp(13),dp(4),0);
        root.addView(foot);
        setContentView(root);
        save.setOnClickListener(v -> saveBike());
        Button auto = makeButton("BẬT TỰ ĐỘNG · GEOFENCE 100m",Color.rgb(225,236,241),Color.rgb(15,49,61));
        LinearLayout.LayoutParams autoSize=new LinearLayout.LayoutParams(-1,dp(46));
        autoSize.setMargins(dp(3),dp(7),dp(3),0);
        root.addView(auto,root.indexOfChild(controls)+1,autoSize);
        auto.setOnClickListener(v -> armAuto());
        save.setOnLongClickListener(v -> {
            bikeLat=Double.NaN;bikeLon=Double.NaN;
            getSharedPreferences("bike",MODE_PRIVATE).edit().clear().apply();
            statusMessage="Đã xóa điểm xe";view.invalidate();refreshStatus();return true;
        });
        find.setOnClickListener(v -> startNavigation());
        stop.setOnClickListener(v -> stopEverything());
        warmCachedPreview();
        refreshStatus();
    }

    private Button makeButton(String label,int background,int foreground){
        Button b=new Button(this);
        b.setAllCaps(false);
        b.setText(label);
        b.setTextSize(12);
        b.setTypeface(Typeface.DEFAULT,Typeface.BOLD);
        b.setTextColor(foreground);
        android.graphics.drawable.GradientDrawable d=new android.graphics.drawable.GradientDrawable();
        d.setColor(background);d.setCornerRadius(dp(16));
        b.setBackground(d);
        return b;
    }
    private int dp(float x){return (int)(x*getResources().getDisplayMetrics().density+0.5f);}

    private boolean hasLocationPermission(){
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED
            || checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)==PackageManager.PERMISSION_GRANTED;
    }
    private void requestPermission(){
        requestPermissions(new String[] {Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION},73);
    }
    @Override public void onRequestPermissionsResult(int requestCode,String[] perms,int[] grants){
        super.onRequestPermissionsResult(requestCode,perms,grants);
        if(requestCode==73) {
            if(hasLocationPermission()) {if(pendingArm){pendingArm=false;armAuto();}else beginGps();}
            else {statusMessage="Cần cấp quyền vị trí để thử nghiệm GPS thật";refreshStatus();}
        }
    }

    private void warmCachedPreview(){
        if (!hasLocationPermission()) return;
        try{
            Location best=null;
            for(String p:new String[]{LocationManager.GPS_PROVIDER,LocationManager.NETWORK_PROVIDER}){
                Location l=manager.getLastKnownLocation(p);
                if(l==null) continue;
                long ageMs=(SystemClock.elapsedRealtimeNanos()-l.getElapsedRealtimeNanos())/1000000L;
                if(ageMs>=0 && ageMs<=15000 && l.hasAccuracy() && l.getAccuracy()<=35
                    && (best==null || l.getAccuracy()<best.getAccuracy())) best=l;
            }
            if(best!=null) {
                // Cache: provisional visual only, NEVER parking confirmation.
                lastReal=best;lastRealSeenMs=0L;
                statusMessage="Vị trí tạm từ bộ nhớ · đang chờ GPS mới";
            }
        }catch(SecurityException ignored){}
        if(view!=null)view.invalidate();
    }

    private void beginGps(){
        if(activeGps)return;
        if(!hasLocationPermission()){requestPermission();return;}
        activeGps=true;firstRequestMs=SystemClock.elapsedRealtime();
        statusMessage="Đang nhận vị trí GPS...";
        warmCachedPreview();
        boolean any=false;
        try{
            if(manager.isProviderEnabled(LocationManager.GPS_PROVIDER)
                && checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED){
                manager.requestLocationUpdates(LocationManager.GPS_PROVIDER,GPS_INTERVAL_MS,0f,listener,Looper.getMainLooper());
                any=true;
            }
            if(manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)){
                manager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER,NETWORK_INTERVAL_MS,0f,listener,Looper.getMainLooper());
                any=true;
            }
        }catch(Exception e){statusMessage="Không bật được GPS: "+e.getClass().getSimpleName();}
        if(!any) statusMessage="Bật dịch vụ vị trí/GPS trên máy";
        refreshStatus();
    }

    private void armAuto(){
        if(!hasLocationPermission()){pendingArm=true;requestPermission();return;}
        if(android.os.Build.VERSION.SDK_INT>=29 &&
          checkSelfPermission(android.Manifest.permission.ACCESS_BACKGROUND_LOCATION)!=PackageManager.PERMISSION_GRANTED){
            statusMessage="Cho phép vị trí MỌI LÚC trong cài đặt ứng dụng, sau đó mở lại và bấm BẬT TỰ ĐỘNG";
            refreshStatus();
            startActivity(new Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                android.net.Uri.parse("package:"+getPackageName())));
            return;
        }
        if(android.os.Build.VERSION.SDK_INT>=29 &&
          checkSelfPermission(android.Manifest.permission.ACTIVITY_RECOGNITION)!=PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{android.Manifest.permission.ACTIVITY_RECOGNITION},74);
        }
        getSharedPreferences("trip",MODE_PRIVATE).edit().putBoolean("armed",true).apply();
        CampusFence.register(this);
        statusMessage="Bật tự động: theo dõi 2 cổng 100m · lưu xe sau 10s đi bộ";
        refreshStatus();
    }
    private void syncAutoBike(){
        android.content.SharedPreferences saved=getSharedPreferences("bike",MODE_PRIVATE);
        if(saved.contains("lat") && saved.contains("lon")){
            double la=Double.longBitsToDouble(saved.getLong("lat",0));
            double lo=Double.longBitsToDouble(saved.getLong("lon",0));
            if(Double.isNaN(bikeLat)||la!=bikeLat||lo!=bikeLon){
                bikeLat=la;bikeLon=lo;view.invalidate();
            }
        }
    }
    private final Runnable autoStatus=new Runnable(){
        @Override public void run(){
            syncAutoBike();
            if(status!=null && !navigation){
                String s=getSharedPreferences("trip",MODE_PRIVATE).getString("status","");
                if(!s.isEmpty())statusMessage=s;
                refreshStatus();
            }
            handler.postDelayed(this,1000);
        }
    };
    private void saveBike(){
        long now=SystemClock.elapsedRealtime();
        if(lastReal!=null && lastRealSeenMs>0 && now-lastRealSeenMs<6000
           && lastReal.hasAccuracy() && lastReal.getAccuracy()<=35f){
            bikeLat=lastReal.getLatitude();bikeLon=lastReal.getLongitude();
            getSharedPreferences("bike",MODE_PRIVATE).edit()
                .putLong("lat",Double.doubleToRawLongBits(bikeLat))
                .putLong("lon",Double.doubleToRawLongBits(bikeLon)).apply();
            saveWhenFix=false;statusMessage="Đã lưu tọa độ XE ĐỖ từ GPS thật";
            view.invalidate();refreshStatus();
        } else {
            saveWhenFix=true;
            statusMessage="Đang lấy GPS mới để lưu xe...";
            beginGps();refreshStatus();
        }
    }
    private void startNavigation(){
        if(Double.isNaN(bikeLat)) {
            statusMessage="Chưa có điểm xe. Bấm LƯU XE tại vị trí đỗ trước.";
            refreshStatus();return;
        }
        navigation=true;
        handler.removeCallbacks(frame);
        beginGps();
        handler.post(frame);
        statusMessage="Đang tìm xe · cập nhật GPS song song";
        view.invalidate();refreshStatus();
    }
    private void stopEverything(){
        navigation=false;saveWhenFix=false;handler.removeCallbacks(frame);
        try{manager.removeUpdates(listener);}catch(SecurityException ignored){}
        activeGps=false;
        velocityEast=0;velocityNorth=0;
        statusMessage="Đã dừng GPS + dự đoán. Điểm xe vẫn được lưu.";
        view.invalidate();refreshStatus();
    }
    private void acceptFix(Location loc){
        long now=SystemClock.elapsedRealtime();
        long fixAge=(SystemClock.elapsedRealtimeNanos()-loc.getElapsedRealtimeNanos())/1000000L;
        if(fixAge<0 || fixAge>5000 || !loc.hasAccuracy() || loc.getAccuracy()>80) return;
        if(!LocationManager.GPS_PROVIDER.equals(loc.getProvider())
             && lastReal!=null && lastRealSeenMs>0 && now-lastRealSeenMs<2500
             && lastReal.hasAccuracy() && lastReal.getAccuracy()+5<loc.getAccuracy()) return;
        if(lastReal!=null && lastRealSeenMs>0){
            float[] d=new float[2];
            Location.distanceBetween(lastReal.getLatitude(),lastReal.getLongitude(),loc.getLatitude(),loc.getLongitude(),d);
            double secs=(loc.getElapsedRealtimeNanos()-lastReal.getElapsedRealtimeNanos())/1e9;
            if(secs<=0.03)return;
            float threshold=Math.max(20f,Math.max(loc.getAccuracy(),lastReal.getAccuracy())*2.5f+(float)secs*6);
            if(d[0]>threshold && secs<8){statusMessage="Đã lọc bước nhảy GPS bất thường";refreshStatus();return;}
            double metersNorth=(loc.getLatitude()-lastReal.getLatitude())*111320.0;
            double metersEast=(loc.getLongitude()-lastReal.getLongitude())*111320.0
                                  *Math.cos(Math.toRadians(loc.getLatitude()));
            if(secs<7 && d[0]>1.4 && d[0]/secs<4.5) {
                double newEast=metersEast/secs, newNorth=metersNorth/secs;
                velocityEast=0.55*velocityEast+0.45*newEast;
                velocityNorth=0.55*velocityNorth+0.45*newNorth;
            } else {
                velocityEast*=0.55;velocityNorth*=0.55;
            }
            if(loc.hasSpeed() && loc.hasBearing() && loc.getSpeed()>0.5f && loc.getSpeed()<4.5f){
                double bearing=Math.toRadians(loc.getBearing());
                velocityEast=0.65*velocityEast+0.35*loc.getSpeed()*Math.sin(bearing);
                velocityNorth=0.65*velocityNorth+0.35*loc.getSpeed()*Math.cos(bearing);
            }
            previousRealSeenMs=lastRealSeenMs;
        }
        lastReal=new Location(loc);
        lastRealSeenMs=now;
        statusMessage="GPS thật đã cập nhật";
        if(saveWhenFix) saveBike();
        view.invalidate();refreshStatus();
    }
    private double[] visualPosition(){
        if(lastReal==null)return null;
        double lat=lastReal.getLatitude(),lon=lastReal.getLongitude();
        if(navigation && lastRealSeenMs>0){
            long ageMs=Math.max(0,SystemClock.elapsedRealtime()-lastRealSeenMs);
            if(ageMs<=PREDICT_LIMIT_MS){
                double secs=ageMs/1000.0;
                lat += velocityNorth*secs/111320.0;
                lon += velocityEast*secs/(111320.0*Math.max(0.2,Math.cos(Math.toRadians(lat))));
            }
        }
        return new double[]{lat,lon};
    }
    private void refreshStatus(){
        if(status==null)return;
        String s=statusMessage;
        if(lastReal!=null){
            long age=lastRealSeenMs==0? -1:SystemClock.elapsedRealtime()-lastRealSeenMs;
            String ageText=age<0?"bộ nhớ":String.format(Locale.US,"%.1fs",age/1000.0);
            s+="\nVị trí: "+ageText+" · sai số ±"+Math.round(lastReal.getAccuracy())+"m";
            if(previousRealSeenMs>0 && lastRealSeenMs>previousRealSeenMs){
                s+=" · khoảng GPS "+String.format(Locale.US,"%.1fs",(lastRealSeenMs-previousRealSeenMs)/1000.0);
            }
        }
        s+="\nGPS yêu cầu 900ms · Vector 100ms"+(navigation?" · ĐANG TÌM XE":" · CHƯA DẪN ĐƯỜNG");
        status.setText(s);
    }

    @Override protected void onResume(){super.onResume();handler.removeCallbacks(autoStatus);handler.post(autoStatus);}
    @Override protected void onPause(){handler.removeCallbacks(autoStatus);super.onPause();stopEverything();}
    @Override protected void onDestroy(){handler.removeCallbacks(frame);super.onDestroy();}

    private final class LineView extends View {
        private final Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);
        LineView(Context ctx){super(ctx);setLayerType(View.LAYER_TYPE_SOFTWARE,null);}
        private void text(Canvas c,String s,float x,float y,float size,int color,boolean bold){
            p.reset();p.setAntiAlias(true);p.setColor(color);p.setTextAlign(Paint.Align.CENTER);
            p.setTextSize(dp(size));p.setTypeface(bold?Typeface.create("sans-serif-medium",Typeface.BOLD):Typeface.DEFAULT);
            c.drawText(s,x,y,p);
        }
        private void circle(Canvas c,float x,float y,float r,int color){
            p.reset();p.setAntiAlias(true);p.setColor(color);c.drawCircle(x,y,r,p);
        }
        @Override protected void onDraw(Canvas canvas){
            super.onDraw(canvas);
            float w=getWidth(),h=getHeight(), d=getResources().getDisplayMetrics().density;
            float cx=w*.50f,cy=h*.65f;
            double[] pos=visualPosition();
            if(pos==null){
                text(canvas,"Đang lấy vị trí...",cx,h*.46f,18,Color.rgb(48,61,72),true);
                text(canvas,"Cho phép GPS và chờ tọa độ thật",cx,h*.46f+dp(28),12,Color.GRAY,false);
                if(!Double.isNaN(bikeLat)) text(canvas,"Đã có tọa độ xe lưu trước đó",cx,h*.46f+dp(52),12,Color.GRAY,false);
                return;
            }
            float bx=cx,by=h*.32f;
            if(Double.isNaN(bikeLat)){
                circle(canvas,cx,cy,dp(9),Color.rgb(20,42,58));
                text(canvas,"BẠN",cx,cy+dp(30),13,Color.rgb(25,43,56),true);
                text(canvas,"Bấm LƯU XE tại vị trí muốn ghi nhớ",cx,h*.38f,14,Color.rgb(99,110,118),false);
                return;
            }
            double north=(bikeLat-pos[0])*111320.0;
            double east=(bikeLon-pos[1])*111320.0*Math.cos(Math.toRadians(pos[0]));
            double distance=Math.hypot(east,north);
            double span=Math.max(22.0,distance);
            double scale=Math.min(w*.38,h*.35)/span;
            bx=(float)(cx+east*scale);
            by=(float)(cy-north*scale);
            p.reset();p.setAntiAlias(true);
            p.setColor(Color.rgb(52,70,84));p.setStrokeWidth(dp(2.3f));
            p.setStyle(Paint.Style.STROKE);
            p.setPathEffect(new DashPathEffect(new float[]{dp(11),dp(8)},0f));
            canvas.drawLine(cx,cy,bx,by,p);
            p.setPathEffect(null);p.setStyle(Paint.Style.FILL);
            float mx=(cx+bx)/2,my=(cy+by)/2;
            p.setColor(Color.WHITE);
            canvas.drawRoundRect(mx-dp(46),my-dp(21),mx+dp(46),my+dp(12),dp(12),dp(12),p);
            String fmt=distance<100 ? String.format(Locale.US,"%.1f m",distance):String.format(Locale.US,"%.0f m",distance);
            text(canvas,fmt,mx,my+dp(1),17,Color.rgb(21,33,42),true);
            circle(canvas,bx,by,dp(12),Color.rgb(230,156,55));
            circle(canvas,bx,by,dp(5),Color.WHITE);
            circle(canvas,cx,cy,dp(10),Color.rgb(22,46,65));
            circle(canvas,cx,cy,dp(3),Color.WHITE);
            text(canvas,"BẠN",cx,cy+dp(31),13,Color.rgb(25,43,56),true);
            text(canvas,"XE ĐỖ",bx,by-dp(22),13,Color.rgb(160,102,35),true);
            long freshness=lastRealSeenMs==0?Long.MAX_VALUE:SystemClock.elapsedRealtime()-lastRealSeenMs;
            double speed=Math.hypot(velocityEast,velocityNorth);
            if(navigation && freshness<1600 && speed>0.25){
                double angle=Math.atan2(velocityEast,-velocityNorth);
                float px=cx+(float)Math.sin(angle)*dp(27);
                float py=cy+(float)Math.cos(angle)*dp(27);
                p.setColor(Color.rgb(46,139,164));p.setStrokeWidth(dp(3));
                canvas.drawLine(cx,cy,px,py,p);
                float a=(float)angle;
                canvas.drawLine(px,py,px-(float)Math.sin(a-.48)*dp(10),py-(float)Math.cos(a-.48)*dp(10),p);
                canvas.drawLine(px,py,px-(float)Math.sin(a+.48)*dp(10),py-(float)Math.cos(a+.48)*dp(10),p);
            }
            if(freshness>3000)text(canvas,"Vị trí tạm - GPS đang cập nhật",w*.5f,h*.14f,12,Color.rgb(159,101,43),false);
            if(distance<5 && freshness<3000)text(canvas,"Đang ở rất gần xe",w*.5f,h*.19f,15,Color.rgb(31,92,65),true);
        }
    }
}
