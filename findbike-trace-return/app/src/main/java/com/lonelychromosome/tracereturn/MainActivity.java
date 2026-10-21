package com.lonelychromosome.tracereturn;

import android.Manifest;
import android.app.*;
import android.os.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.hardware.*;
import android.location.Location;
import android.net.Uri;
import android.view.*;
import android.widget.*;
import android.util.Xml;
import org.xmlpull.v1.XmlPullParser;
import com.google.android.gms.location.*;
import com.google.android.gms.tasks.CancellationTokenSource;
import java.io.*;
import java.util.*;

public final class MainActivity extends Activity implements SensorEventListener {
    // Saved bike coordinate read from the user's Find My Bike REAL 1.5 screenshot, 21 October.
    // NOT computed from the older, unrelated 22-point trace.
    private static final double SCREENSHOT_PARK_LAT=20.959630;
    private static final double SCREENSHOT_PARK_LON=105.746592;
    private static final int REQUEST_GPX=40, REQUEST_GPS=41;
    private final Handler ui=new Handler(Looper.getMainLooper());
    private final ArrayList<Point> importedRoute=new ArrayList<>();
    private FusedLocationProviderClient fused;
    private LocationCallback locationCallback;
    private SensorManager sensorManager;
    private Sensor rotationSensor;
    private TextView distanceView, information, fixInfo, subtitle, headingInfo;
    private Button navigationButton;
    private CompassView compass;
    private Location latestFix;
    private boolean navigating=false, requestedLocation=false;
    private boolean headingAvailable=false;
    private float azimuth=0f, velEast=0f, velNorth=0f;
    private double bikeLat=SCREENSHOT_PARK_LAT, bikeLon=SCREENSHOT_PARK_LON;
    private String bikeSource="Điểm XE ĐỖ trong ảnh REAL 1.5 · 21/10";
    private String loadedTrace="";
    private int traceCount=0;
    private final Runnable animate=new Runnable(){
        @Override public void run(){
            if(!navigating)return;
            drawStatus();
            ui.postDelayed(this,100);
        }
    };

    @Override public void onCreate(Bundle b){
        super.onCreate(b);
        getWindow().setStatusBarColor(Color.WHITE);
        getWindow().setNavigationBarColor(Color.WHITE);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
        fused=LocationServices.getFusedLocationProviderClient(this);
        sensorManager=(SensorManager)getSystemService(SENSOR_SERVICE);
        rotationSensor=sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR);
        android.content.SharedPreferences prefs=getSharedPreferences("dest",MODE_PRIVATE);
        if(prefs.contains("lat")&&prefs.contains("lon")){
            bikeLat=Double.longBitsToDouble(prefs.getLong("lat",0));
            bikeLon=Double.longBitsToDouble(prefs.getLong("lon",0));
            bikeSource=prefs.getString("source","Đã nhập GPX");
            loadedTrace=prefs.getString("filename","");
            traceCount=prefs.getInt("count",0);
        }
        restoreTrace();
        LinearLayout root=new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.WHITE);
        root.setPadding(dp(20),dp(18),dp(20),dp(18));

        TextView kicker=new TextView(this);
        kicker.setText("FIND MY BIKE   /   NORTH UP");
        kicker.setTextSize(11);kicker.setLetterSpacing(.13f);
        kicker.setTextColor(Color.rgb(87,114,131));
        root.addView(kicker);

        TextView title=new TextView(this);
        title.setText("Tìm xe");
        title.setTextSize(30);title.setTypeface(Typeface.DEFAULT,Typeface.BOLD);
        title.setTextColor(Color.rgb(18,42,58));
        LinearLayout.LayoutParams titleLp=new LinearLayout.LayoutParams(-1,-2);
        titleLp.topMargin=dp(7);root.addView(title,titleLp);

        subtitle=new TextView(this);
        subtitle.setTextColor(Color.rgb(91,108,120));
        subtitle.setTextSize(12);subtitle.setMaxLines(2);
        LinearLayout.LayoutParams subLp=new LinearLayout.LayoutParams(-1,-2);
        subLp.topMargin=dp(6);root.addView(subtitle,subLp);

        distanceView=new TextView(this);
        distanceView.setText("— m");distanceView.setGravity(Gravity.CENTER);
        distanceView.setTextColor(Color.rgb(18,42,58));
        distanceView.setTextSize(49);distanceView.setTypeface(Typeface.DEFAULT,Typeface.BOLD);
        LinearLayout.LayoutParams distanceLp=new LinearLayout.LayoutParams(-1,dp(82));
        distanceLp.topMargin=dp(17);root.addView(distanceView,distanceLp);

        headingInfo=new TextView(this);
        headingInfo.setTextSize(13);headingInfo.setGravity(Gravity.CENTER);
        headingInfo.setTextColor(Color.rgb(103,116,126));
        root.addView(headingInfo);

        compass=new CompassView(this);
        root.addView(compass,new LinearLayout.LayoutParams(-1,0,1f));

        fixInfo=new TextView(this);
        fixInfo.setGravity(Gravity.CENTER);
        fixInfo.setTextSize(13);
        fixInfo.setTextColor(Color.rgb(82,100,115));
        fixInfo.setPadding(dp(4),dp(3),dp(4),dp(9));
        root.addView(fixInfo);

        information=new TextView(this);
        information.setTextSize(12);
        information.setTextColor(Color.rgb(99,113,125));
        information.setMaxLines(3);
        information.setPadding(dp(4),0,dp(4),dp(11));
        root.addView(information);

        navigationButton=button("BẮT ĐẦU DẪN VỀ",Color.rgb(24,49,67),Color.WHITE);
        root.addView(navigationButton,new LinearLayout.LayoutParams(-1,dp(54)));
        navigationButton.setOnClickListener(v->{
            if(navigating)stopNav();else startNav();
        });

        Button importButton=button("NHẬP TRACE GPX · ĐỔI ĐIỂM ĐẾN",Color.rgb(232,241,246),Color.rgb(20,57,75));
        LinearLayout.LayoutParams importLp=new LinearLayout.LayoutParams(-1,dp(52));
        importLp.topMargin=dp(9);root.addView(importButton,importLp);
        importButton.setOnClickListener(v->openTracePicker());

        TextView note=new TextView(this);
        note.setText("BẮC luôn ở trên. Xoay điện thoại chỉ xoay mũi tên BẠN; XE ĐỖ và line không xoay. Đây là đường chim bay.");
        note.setTextColor(Color.rgb(137,149,157));
        note.setTextSize(10);
        LinearLayout.LayoutParams noteLp=new LinearLayout.LayoutParams(-1,-2);
        noteLp.topMargin=dp(10);root.addView(note,noteLp);
        setContentView(root);
        drawStatus();
        maybeHandleSharedFile(getIntent());
    }

    private Button button(String text,int bg,int fg){
        Button b=new Button(this);b.setText(text);b.setAllCaps(false);b.setTextSize(13);
        b.setTypeface(Typeface.create("sans-serif-medium",Typeface.BOLD));
        b.setTextColor(fg);
        GradientDrawable shape=new GradientDrawable();
        shape.setColor(bg);shape.setCornerRadius(dp(14));b.setBackground(shape);
        return b;
    }
    private int dp(float x){return Math.round(x*getResources().getDisplayMetrics().density);}
    private boolean hasLocation(){
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)==PackageManager.PERMISSION_GRANTED;
    }
    private void startNav(){
        if(!hasLocation()){
            requestedLocation=true;
            requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION},REQUEST_GPS);
            return;
        }
        if(navigating)return;
        navigating=true;
        navigationButton.setText("DỪNG DẪN ĐƯỜNG");
        headingAvailable=false;
        if(rotationSensor!=null)sensorManager.registerListener(this,rotationSensor,SensorManager.SENSOR_DELAY_GAME);
        // Cached fix is shown immediately if available, but always labeled with its true age.
        try{
            fused.getLastLocation().addOnSuccessListener(this,loc->{if(navigating)acceptFix(loc);});
            LocationRequest request=new LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY,900L)
                .setMinUpdateIntervalMillis(400L)
                .setMinUpdateDistanceMeters(0f)
                .setWaitForAccurateLocation(false).build();
            locationCallback=new LocationCallback(){
                @Override public void onLocationResult(LocationResult r){
                    for(Location loc:r.getLocations())acceptFix(loc);
                }
            };
            fused.requestLocationUpdates(request,locationCallback,Looper.getMainLooper())
                .addOnFailureListener(e->{ fixInfo.setText("Không thể bật định vị: "+e.getMessage()); });
            CancellationTokenSource c=new CancellationTokenSource();
            fused.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY,c.getToken())
                .addOnSuccessListener(this,loc->{if(navigating)acceptFix(loc);});
        }catch(SecurityException e){fixInfo.setText("Thiếu quyền vị trí");}
        ui.removeCallbacks(animate);ui.post(animate);
        drawStatus();
    }
    private void stopNav(){
        navigating=false;
        ui.removeCallbacks(animate);
        if(locationCallback!=null){fused.removeLocationUpdates(locationCallback);locationCallback=null;}
        sensorManager.unregisterListener(this);
        velNorth=0f;velEast=0f;
        navigationButton.setText("BẮT ĐẦU DẪN VỀ");
        drawStatus();
    }
    @Override protected void onStop(){stopNav();super.onStop();}
    @Override protected void onResume(){super.onResume();drawStatus();}
    @Override protected void onDestroy(){ui.removeCallbacks(animate);stopNav();super.onDestroy();}
    @Override public void onRequestPermissionsResult(int code,String[] permissions,int[] results){
        super.onRequestPermissionsResult(code,permissions,results);
        if(code==REQUEST_GPS && requestedLocation){
            requestedLocation=false;
            if(hasLocation())startNav();
            else fixInfo.setText("Cần cấp quyền vị trí để dẫn về xe");
        }
    }
    private long ageMs(Location loc){
        if(loc==null)return Long.MAX_VALUE;
        long t=loc.getElapsedRealtimeNanos();
        if(t<=0)return Long.MAX_VALUE;
        return Math.max(0L,(SystemClock.elapsedRealtimeNanos()-t)/1_000_000L);
    }
    private void acceptFix(Location candidate){
        if(candidate==null || !Double.isFinite(candidate.getLatitude()) ||
            !Double.isFinite(candidate.getLongitude()))return;
        if(Math.abs(candidate.getLatitude())>90||Math.abs(candidate.getLongitude())>180)return;
        if(ageMs(candidate)>30000L)return;
        if(candidate.hasAccuracy() && candidate.getAccuracy()>80f)return;
        if(latestFix!=null){
            long dt=(candidate.getElapsedRealtimeNanos()-latestFix.getElapsedRealtimeNanos());
            if(dt<=0)return;
            float accuracy=candidate.hasAccuracy()?candidate.getAccuracy():999f;
            float oldAccuracy=latestFix.hasAccuracy()?latestFix.getAccuracy():999f;
            // Keep recent better fix over a suddenly much worse network fix.
            if(accuracy>oldAccuracy*3f && ageMs(latestFix)<3000)return;
            double secs=dt/1e9;
            if(secs>0.3&&secs<7){
                float dx=latestFix.distanceTo(candidate);
                float gate=Math.max(22f,Math.max(oldAccuracy,accuracy)*2.5f+(float)(6*secs));
                if(dx>gate)return;
                if(dx>1.7f && dx/secs<4.5f) {
                    double north=(candidate.getLatitude()-latestFix.getLatitude())*111320.0/secs;
                    double east=(candidate.getLongitude()-latestFix.getLongitude())*111320.0*
                        Math.cos(Math.toRadians(candidate.getLatitude()))/secs;
                    velNorth=.57f*velNorth+.43f*(float)north;
                    velEast=.57f*velEast+.43f*(float)east;
                } else {velNorth*=.65f;velEast*=.65f;}
            }
        }
        if(candidate.hasSpeed() && candidate.hasBearing() &&
            candidate.getSpeed()>.45f && candidate.getSpeed()<4.2f){
            double rad=Math.toRadians(candidate.getBearing());
            velEast=.6f*velEast+.4f*(float)(candidate.getSpeed()*Math.sin(rad));
            velNorth=.6f*velNorth+.4f*(float)(candidate.getSpeed()*Math.cos(rad));
        }
        latestFix=new Location(candidate);
        drawStatus();
    }
    private double[] displayedLocation(){
        if(latestFix==null)return null;
        double lat=latestFix.getLatitude(),lon=latestFix.getLongitude();
        long age=ageMs(latestFix);
        if(navigating && age<1200 && latestFix.hasAccuracy() && latestFix.getAccuracy()<35) {
            double s=age/1000.0;
            double velocity=Math.hypot(velNorth,velEast);
            if(velocity>.25 && velocity<3.5){
                lat+=velNorth*s/111320.0;
                lon+=velEast*s/(111320.0*Math.max(.25,Math.cos(Math.toRadians(lat))));
            }
        }
        return new double[]{lat,lon};
    }
    private void drawStatus(){
        if(distanceView==null)return;
        subtitle.setText(bikeSource);
        information.setText("XE ĐỖ · "+String.format(Locale.US,"%.6f, %.6f",bikeLat,bikeLon)
            +(loadedTrace.isEmpty()?"":"\nTRACE · "+loadedTrace+" · "+traceCount+" điểm GPS"));
        double[] current=displayedLocation();
        if(current==null) {
            distanceView.setText("— m");
            headingInfo.setText("Đã có tọa độ xe · "+(navigating?"đang lấy GPS của BẠN":"bấm BẮT ĐẦU DẪN VỀ"));
            fixInfo.setText(navigating?"Đang nhận vị trí mới qua GPS / mạng":"GPS dẫn đường chưa bật");
        }else{
            Location me=new Location("display");
            me.setLatitude(current[0]);me.setLongitude(current[1]);
            Location bike=new Location("park");
            bike.setLatitude(bikeLat);bike.setLongitude(bikeLon);
            float meters=me.distanceTo(bike), bearing=me.bearingTo(bike);
            distanceView.setText(meters<100?String.format(Locale.US,"%.1f m",meters):
                String.format(Locale.US,"%.0f m",meters));
            String orient;
            if(headingAvailable){
                float delta=((bearing-azimuth+540)%360)-180;
                if(Math.abs(delta)<18)orient="Xe ở phía trước";
                else if(delta>0)orient="Xe ở bên phải "+Math.round(Math.abs(delta))+"°";
                else orient="Xe ở bên trái "+Math.round(Math.abs(delta))+"°";
            }else orient="Hướng xe: "+Math.round((bearing+360)%360)+"° từ Bắc";
            headingInfo.setText(orient+" · đường chim bay");
            long age=ageMs(latestFix);
            String time=age>=60000 ? (age/60000)+" phút" : (age/1000)+" giây";
            String quality=latestFix.hasAccuracy()?"±"+Math.round(latestFix.getAccuracy())+" m":"chưa rõ sai số";
            String flag=age>3000?"VỊ TRÍ CUỐI · GPS ĐANG CẬP NHẬT":"GPS đang cập nhật";
            fixInfo.setText(flag+" · "+time+" trước · "+quality);
        }
        compass.invalidate();
    }
    @Override public void onSensorChanged(SensorEvent e){
        if(rotationSensor==null || e.sensor.getType()!=Sensor.TYPE_ROTATION_VECTOR)return;
        float[] rotation=new float[9],orientation=new float[3];
        SensorManager.getRotationMatrixFromVector(rotation,e.values);
        float[] displayMatrix=new float[9];
        int xx=SensorManager.AXIS_X,yy=SensorManager.AXIS_Y;
        switch(getWindowManager().getDefaultDisplay().getRotation()){
            case Surface.ROTATION_90:xx=SensorManager.AXIS_Y;yy=SensorManager.AXIS_MINUS_X;break;
            case Surface.ROTATION_180:xx=SensorManager.AXIS_MINUS_X;yy=SensorManager.AXIS_MINUS_Y;break;
            case Surface.ROTATION_270:xx=SensorManager.AXIS_MINUS_Y;yy=SensorManager.AXIS_X;break;
        }
        if(!SensorManager.remapCoordinateSystem(rotation,xx,yy,displayMatrix))return;
        SensorManager.getOrientation(displayMatrix,orientation);
        float next=(float)((Math.toDegrees(orientation[0])+360)%360);
        if(!headingAvailable){azimuth=next;headingAvailable=true;}
        else{
            float delta=((next-azimuth+540)%360)-180;
            azimuth=(azimuth+delta*.16f+360)%360;
        }
    }
    @Override public void onAccuracyChanged(Sensor s,int accuracy){}
    private void openTracePicker(){
        Intent pick=new Intent(Intent.ACTION_OPEN_DOCUMENT);
        pick.setType("*/*");
        pick.addCategory(Intent.CATEGORY_OPENABLE);
        pick.putExtra(Intent.EXTRA_MIME_TYPES,new String[]{
            "application/gpx+xml","application/xml","text/xml","text/plain","application/octet-stream"});
        startActivityForResult(pick,REQUEST_GPX);
    }
    @Override protected void onNewIntent(Intent intent){
        super.onNewIntent(intent);maybeHandleSharedFile(intent);
    }
    private void maybeHandleSharedFile(Intent intent){
        if(intent==null)return;
        Uri uri=null;
        if(Intent.ACTION_VIEW.equals(intent.getAction()))uri=intent.getData();
        else if(Intent.ACTION_SEND.equals(intent.getAction())){
            uri=intent.getParcelableExtra(Intent.EXTRA_STREAM);
        }
        if(uri!=null)readTrace(uri);
    }
    @Override protected void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);
        if(request==REQUEST_GPX&&result==RESULT_OK&&data!=null&&data.getData()!=null){
            readTrace(data.getData());
        }
    }

    private static class Point {
        double lat,lon;String name;
        Point(double la,double lo){lat=la;lon=lo;}
        Location asLocation(){Location l=new Location("gpx");l.setLatitude(lat);l.setLongitude(lon);return l;}
    }
    private static class Trace {
        final ArrayList<Point> points=new ArrayList<>();
        final ArrayList<Point> named=new ArrayList<>();
    }
    private Trace parseGpx(InputStream input) throws Exception {
        Trace track=new Trace();
        XmlPullParser x=Xml.newPullParser();
        x.setInput(new InputStreamReader(input,"UTF-8"));
        int event=x.getEventType();
        Point waypoint=null;
        StringBuilder waypointName=new StringBuilder();
        while(event!=XmlPullParser.END_DOCUMENT) {
            if(event==XmlPullParser.START_TAG){
                String tag=x.getName();
                if("trkpt".equals(tag)||"rtept".equals(tag)||"wpt".equals(tag)){
                    String latitude=x.getAttributeValue(null,"lat");
                    String longitude=x.getAttributeValue(null,"lon");
                    if(latitude!=null&&longitude!=null){
                        try{
                            double lat=Double.parseDouble(latitude),lon=Double.parseDouble(longitude);
                            if(Double.isFinite(lat)&&Double.isFinite(lon)&&Math.abs(lat)<=90&&Math.abs(lon)<=180
                                &&!(lat==0&&lon==0)){
                                Point p=new Point(lat,lon);
                                if("wpt".equals(tag)){waypoint=p;waypointName.setLength(0);}
                                else if(track.points.size()<10000)track.points.add(p);
                            }
                        }catch(NumberFormatException ignored){}
                    }
                }else if("name".equals(tag)&&waypoint!=null){
                    waypointName.append(x.nextText());
                }
            }else if(event==XmlPullParser.END_TAG && "wpt".equals(x.getName())){
                if(waypoint!=null){
                    waypoint.name=waypointName.toString();
                    track.named.add(waypoint);
                }
                waypoint=null;
            }
            event=x.next();
        }
        return track;
    }
    private Point bestCandidate(Trace t){
        for(Point p:t.named){
            if(p.name!=null){
                String n=p.name.toLowerCase(Locale.ROOT);
                if(n.contains("đỗ")||n.contains("do xe")||n.contains("park")||
                    n.contains("bike")||n.contains("xe"))return p;
            }
        }
        ArrayList<Point> pts=t.points;
        Point best=null;int bestSize=0;
        // A small stationary cluster followed by movement is a CANDIDATE only.
        for(int i=0;i<pts.size()-3;i++){
            Point base=pts.get(i);
            int e=i+1;
            while(e<pts.size() && distance(base,pts.get(e))<=4.2 && e-i<20)e++;
            int count=e-i;
            boolean walkedAway=false;
            for(int k=e;k<Math.min(pts.size(),e+12);k++){
                if(distance(base,pts.get(k))>13){walkedAway=true;break;}
            }
            if(count>=3 && walkedAway && count>=bestSize){
                double la=0,lo=0;
                for(int k=i;k<e;k++){la+=pts.get(k).lat;lo+=pts.get(k).lon;}
                best=new Point(la/count,lo/count);
                best.name="Cụm đứng yên khoảng điểm "+(i+1)+"–"+e;
                bestSize=count;
            }
        }
        return best;
    }
    private double distance(Point a,Point b){
        return a.asLocation().distanceTo(b.asLocation());
    }
    private void readTrace(Uri uri){
        String file="GPX vừa nhập";
        try(android.database.Cursor c=getContentResolver().query(uri,new String[]{android.provider.OpenableColumns.DISPLAY_NAME},null,null,null)){
            if(c!=null&&c.moveToFirst())file=c.getString(0);
        }catch(Exception ignored){}
        if(file==null)file="GPX";
        final String filename=file;
        try(InputStream stream=getContentResolver().openInputStream(uri)){
            if(stream==null)throw new IOException("Không đọc được tệp");
            Trace track=parseGpx(new BufferedInputStream(stream));
            if(track.points.isEmpty()&&track.named.isEmpty())throw new IOException("Không có trkpt hoặc wpt hợp lệ trong GPX");
            Point candidate=bestCandidate(track);
            String message="Đọc được "+track.points.size()+" điểm hành trình"+
                (track.named.isEmpty()?"":", "+track.named.size()+" waypoint")+".\n";
            if(candidate!=null){
                message+="\nĐiểm đề xuất: "+String.format(Locale.US,"%.6f, %.6f",candidate.lat,candidate.lon)+
                    "\n"+(candidate.name==null?"":candidate.name)+
                    "\n\nKiểm tra đúng chỗ đỗ trước khi dẫn đường.";
            }else message+="\nKhông có nhãn xe đỗ/cụm đứng yên rõ ràng. Chọn một điểm trên trace.";
            AlertDialog.Builder dialog=new AlertDialog.Builder(this)
                .setTitle("Trace: "+filename)
                .setMessage(message)
                .setNegativeButton("HỦY",null)
                .setNeutralButton("CHỌN ĐIỂM KHÁC",(d,which)->pickTracePoint(track,filename));
            if(candidate!=null)dialog.setPositiveButton("DÙNG ĐIỂM NÀY",(d,which)->
                setBike(candidate,filename,track));
            else dialog.setPositiveButton("CHỌN ĐIỂM",(d,which)->pickTracePoint(track,filename));
            dialog.show();
        }catch(Exception e){
            new AlertDialog.Builder(this).setTitle("Không đọc được Trace GPX")
                .setMessage(e.getMessage()).setPositiveButton("OK",null).show();
        }
    }
    private void pickTracePoint(Trace track,String filename){
        ArrayList<Point> pts=track.points.isEmpty()?track.named:track.points;
        String[] options=new String[pts.size()];
        for(int i=0;i<pts.size();i++){
            Point p=pts.get(i);
            options[i]=String.format(Locale.US,"#%d   %.6f, %.6f",i+1,p.lat,p.lon);
        }
        new AlertDialog.Builder(this).setTitle("Chọn điểm xe đỗ · "+pts.size()+" điểm")
            .setItems(options,(d,which)->{
                Point p=pts.get(which);
                new AlertDialog.Builder(this).setTitle("Xác nhận điểm xe")
                    .setMessage(String.format(Locale.US,
                        "Điểm #%d\n%.6f, %.6f\n\nĐiểm này sẽ là đích dẫn về. Đúng vị trí xe chứ?",
                        which+1,p.lat,p.lon))
                    .setPositiveButton("DÙNG ĐIỂM NÀY",(dd,w)->setBike(p,filename,track))
                    .setNegativeButton("QUAY LẠI",(dd,w)->pickTracePoint(track,filename)).show();
            }).setNegativeButton("HỦY",null).show();
    }
    private void setBike(Point p,String filename,Trace track){
        int count=track.points.size();
        saveTrace(track.points);
        bikeLat=p.lat;bikeLon=p.lon;
        bikeSource="Vị trí xe từ GPX · "+filename;
        loadedTrace=filename;traceCount=count;
        getSharedPreferences("dest",MODE_PRIVATE).edit()
            .putLong("lat",Double.doubleToRawLongBits(bikeLat))
            .putLong("lon",Double.doubleToRawLongBits(bikeLon))
            .putString("source",bikeSource).putString("filename",filename)
            .putInt("count",count).apply();
        drawStatus();
        if(!navigating)startNav();
    }


    private void saveTrace(ArrayList<Point> pts){
        importedRoute.clear();
        File output=new File(getFilesDir(),"confirmed_route.csv");
        try(BufferedWriter writer=new BufferedWriter(new OutputStreamWriter(new FileOutputStream(output),"UTF-8"))){
            int count=0;
            for(Point point:pts){
                if(count++>=10000)break;
                writer.write(String.format(Locale.US,"%.9f,%.9f",point.lat,point.lon));
                writer.newLine();importedRoute.add(point);
            }
        }catch(Exception ignored){importedRoute.clear();}
    }
    private void restoreTrace(){
        File source=new File(getFilesDir(),"confirmed_route.csv");
        if(!source.isFile())return;
        try(BufferedReader reader=new BufferedReader(new InputStreamReader(new FileInputStream(source),"UTF-8"))){
            String row;
            while((row=reader.readLine())!=null&&importedRoute.size()<10000){
                String[] xy=row.split(",");
                if(xy.length!=2)continue;
                double lat=Double.parseDouble(xy[0]),lon=Double.parseDouble(xy[1]);
                if(Double.isFinite(lat)&&Double.isFinite(lon)&&Math.abs(lat)<=90&&Math.abs(lon)<=180)
                    importedRoute.add(new Point(lat,lon));
            }
        }catch(Exception ignored){importedRoute.clear();}
    }

    private final class CompassView extends View{
        private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
        CompassView(Context context){super(context);}
        private void circle(Canvas c,float x,float y,float r,int col){
            paint.reset();paint.setAntiAlias(true);paint.setColor(col);c.drawCircle(x,y,r,paint);
        }
        private void label(Canvas c,String s,float x,float y,int size,int color){
            paint.reset();paint.setAntiAlias(true);paint.setColor(color);
            paint.setTextAlign(Paint.Align.CENTER);paint.setTextSize(dp(size));
            paint.setTypeface(Typeface.create("sans-serif-medium",Typeface.BOLD));c.drawText(s,x,y,paint);
        }
        @Override protected void onDraw(Canvas canvas){
            super.onDraw(canvas);
            float w=getWidth(),h=getHeight(),ux=w*.50f,uy=h*.55f;
            int navy=Color.rgb(25,55,74),amber=Color.rgb(236,161,54);
            double[] current=displayedLocation();
            if(current==null) {
                circle(canvas,ux,uy,dp(12),navy);
                label(canvas,"BẠN",ux,uy+dp(36),13,navy);
                label(canvas,"GPS đang lấy vị trí BẠN",ux,h*.22f,13,Color.rgb(130,143,152));
                return;
            }
            Location from=new Location("me"),dest=new Location("bike");
            from.setLatitude(current[0]);from.setLongitude(current[1]);
            dest.setLatitude(bikeLat);dest.setLongitude(bikeLon);
            float meters=from.distanceTo(dest),bearing=from.bearingTo(dest);
            float rel=(float)Math.toRadians(bearing); // NORTH-UP: position never rotates with phone
            // Metric coordinates: east is right, north is up. Both points are independent of handset rotation.
            double metersEast=(bikeLon-current[1])*111320.0*Math.cos(Math.toRadians(current[0]));
            double metersNorth=(bikeLat-current[0])*111320.0;
            float freeX=Math.max(dp(35),Math.min(ux-dp(44),w-ux-dp(44)));
            float freeY=Math.max(dp(35),Math.min(uy-dp(65),h-uy-dp(65)));
            float pxPerMeter=Math.min(freeX/(float)Math.max(8,Math.abs(metersEast)),
                                      freeY/(float)Math.max(8,Math.abs(metersNorth)));
            pxPerMeter=Math.min(pxPerMeter,dp(11));
            float bx=ux+(float)metersEast*pxPerMeter;
            float by=uy-(float)metersNorth*pxPerMeter;
            // Draw confirmed GPX polyline in the SAME north-up coordinate frame.
            if(importedRoute.size()>1){
                Path route=new Path();
                boolean isFirst=true;
                for(Point point:importedRoute){
                    float east=(float)((point.lon-current[1])*111320.0*Math.cos(Math.toRadians(current[0])));
                    float north=(float)((point.lat-current[0])*111320.0);
                    float x=ux+east*pxPerMeter,y=uy-north*pxPerMeter;
                    if(isFirst){route.moveTo(x,y);isFirst=false;}else route.lineTo(x,y);
                }
                paint.reset();paint.setAntiAlias(true);
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(dp(2));paint.setColor(Color.rgb(174,203,220));
                canvas.drawPath(route,paint);
            }
            paint.reset();paint.setAntiAlias(true);paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(dp(2.5f));paint.setColor(Color.rgb(79,100,115));
            paint.setPathEffect(new DashPathEffect(new float[]{dp(11),dp(9)},0));
            canvas.drawLine(ux,uy,bx,by,paint);
            paint.setPathEffect(null);paint.setStyle(Paint.Style.FILL);
            float mx=(ux+bx)/2f,my=(uy+by)/2f;
            String metersText=meters<100?String.format(Locale.US,"%.1f m",meters):
                String.format(Locale.US,"%.0f m",meters);
            paint.setColor(Color.WHITE);
            float textWidth=dp(85);
            canvas.drawRoundRect(mx-textWidth*.5f,my-dp(20),mx+textWidth*.5f,my+dp(12),dp(12),dp(12),paint);
            label(canvas,metersText,mx,my+dp(4),16,navy);
            circle(canvas,bx,by,dp(18),Color.rgb(252,245,230));
            circle(canvas,bx,by,dp(10),amber);circle(canvas,bx,by,dp(3.3f),Color.WHITE);
            circle(canvas,ux,uy,dp(12),navy);circle(canvas,ux,uy,dp(3.5f),Color.WHITE);
            label(canvas,"XE ĐỖ",bx,by-dp(27),12,navy);
            label(canvas,"BẠN",ux,uy+dp(35),12,navy);
            long age=ageMs(latestFix);
            double speed=Math.hypot(velEast,velNorth);
            if(headingAvailable){
                // Only BẠN arrow follows the phone's rotation, not route or XE ĐỖ.
                double angle=Math.toRadians(azimuth);
                float sx=ux+(float)Math.sin(angle)*dp(30),sy=uy-(float)Math.cos(angle)*dp(30);
                paint.setColor(Color.rgb(34,166,180));paint.setStrokeWidth(dp(3));
                paint.setStrokeCap(Paint.Cap.ROUND);paint.setStyle(Paint.Style.STROKE);
                canvas.drawLine(ux,uy,sx,sy,paint);
                float a=(float)angle;
                canvas.drawLine(sx,sy,sx-(float)Math.sin(a-.55f)*dp(11),sy+(float)Math.cos(a-.55f)*dp(11),paint);
                canvas.drawLine(sx,sy,sx-(float)Math.sin(a+.55f)*dp(11),sy+(float)Math.cos(a+.55f)*dp(11),paint);
                paint.setStyle(Paint.Style.FILL);
            }
            // Accurate metric scale derived from the same map projection.
            float preferredMetres=(w*.27f)/Math.max(.001f,pxPerMeter),scaleMetres=1f;
            for(float v:new float[]{1,2,5,10,20,50,100,200,500,1000,2000,5000})
                if(v<=preferredMetres)scaleMetres=v;
            float startX=dp(21),scaleY=h-dp(44),length=scaleMetres*pxPerMeter;
            paint.reset();paint.setAntiAlias(true);
            paint.setColor(Color.rgb(155,168,179));paint.setStrokeWidth(dp(2f));
            canvas.drawLine(startX,scaleY,startX+length,scaleY,paint);
            canvas.drawLine(startX,scaleY-dp(5),startX,scaleY+dp(5),paint);
            canvas.drawLine(startX+length,scaleY-dp(5),startX+length,scaleY+dp(5),paint);
            label(canvas,String.format(Locale.US,"%.0f m",scaleMetres),
                startX+length*.5f,scaleY-dp(11),10,Color.rgb(139,155,167));
            label(canvas,"↑ BẮC · BẢN ĐỒ CỐ ĐỊNH",w*.5f,dp(24),10,Color.rgb(144,153,159));
            if(age>3000)label(canvas,"VỊ TRÍ TẠM · MẤT GPS",w*.5f,h-dp(17),12,Color.rgb(160,112,42));
            else if(meters<5)label(canvas,"ĐANG Ở GẦN VỊ TRÍ XE",w*.5f,h-dp(17),12,Color.rgb(42,131,92));
        }
    }
}
