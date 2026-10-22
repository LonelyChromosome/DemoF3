import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'vehicle_native.dart';

/// White cinematic loading screen. Each scan square fades out BEFORE the next.
class VehicleScanLockScreen extends StatefulWidget {
  const VehicleScanLockScreen({super.key,this.testMode=false});
  final bool testMode;
  @override State<VehicleScanLockScreen> createState()=>_VehicleScanLockScreenState();
}
class _VehicleScanLockScreenState extends State<VehicleScanLockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller=AnimationController(
      vsync:this,duration:const Duration(milliseconds:3920))..forward();
  @override
  void initState(){
    super.initState();
    // GPS was already started by VehiclePage.openNav, in parallel with this VFX.
    controller.addStatusListener((s){
      if(s==AnimationStatus.completed&&mounted){
        Navigator.of(context).pushReplacement<void,void>(
          MaterialPageRoute<void>(builder:(_)=>VehicleGuidanceScreen(testMode:widget.testMode)));
      }
    });
  }
  @override void dispose(){controller.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:Colors.white,
    body:SafeArea(child:AnimatedBuilder(
      animation:controller,
      builder:(context,_)=>CustomPaint(
        painter:_ScanLockPainter(controller.value),
        child:const SizedBox.expand(),
      ),
    )),
  );
}
class _ScanLockPainter extends CustomPainter {
  const _ScanLockPainter(this.progress);
  final double progress;
  @override void paint(Canvas canvas,Size size) {
    canvas.drawColor(Colors.white,BlendMode.src);
    final w=size.width,h=size.height;
    final p=Paint()..isAntiAlias=true..strokeWidth=1.2
      ..color=const Color(0xFFE4EDF0)..style=PaintingStyle.stroke;
    // Non-geographic geometry is deliberately VFX only.
    for(var i=0;i<8;i++){
      final path=Path()..moveTo(w*((i*29+13)%97)/100,h*.16);
      path.cubicTo(w*((i*17+17)%91)/100,h*.38,
        w*((i*31+18)%91)/100,h*.57,
        w*((i*47+9)%91)/100,h*.86);
      canvas.drawPath(path,p);
    }
    p..style=PaintingStyle.fill..color=const Color(0xFFD0DFE4);
    for(var i=0;i<38;i++){
      canvas.drawCircle(Offset(w*((i*37+13)%101)/101,
        h*(.18+.68*((i*29+4)%99)/99)),1.5,p);
    }
    final targets=<Offset>[
      Offset(w*.27,h*.25),Offset(w*.73,h*.39),
      Offset(w*.31,h*.72),Offset(w*.59,h*.57),
    ];
    final time=progress*3.92;
    if(time<3.08){
      final index=math.min(3,(time/.77).floor());
      final phase=(time-index*.77)/.77;
      final opacity=math.sin(phase*math.pi).clamp(0.0,1.0).toDouble();
      _box(canvas,targets[index],24+phase*7,
          const Color(0xFF00ADC1).withValues(alpha:opacity),2.0);
    }else{
      final phase=((time-3.08)/.22).clamp(0.0,1.0).toDouble();
      _box(canvas,targets.last,30-6*phase,
          const Color(0xFF008DA8),3.1);
      if(phase>.94){
        p..color=const Color(0xFF008DA8)..style=PaintingStyle.fill;
        canvas.drawRect(Rect.fromCenter(
          center:targets.last,width:8,height:8),p);
      }
    }
  }
  void _box(Canvas canvas,Offset center,double radius,Color color,double width){
    final p=Paint()..color=color..style=PaintingStyle.stroke
      ..strokeWidth=width..strokeCap=StrokeCap.square;
    final rect=Rect.fromCenter(center:center,width:radius*2,height:radius*2);
    final seg=radius*.65;
    for(final corner in <Offset>[rect.topLeft,rect.topRight,
        rect.bottomLeft,rect.bottomRight]){
      final dx=corner.dx==rect.left?1.0:-1.0;
      final dy=corner.dy==rect.top?1.0:-1.0;
      canvas.drawLine(corner,Offset(corner.dx+seg*dx,corner.dy),p);
      canvas.drawLine(corner,Offset(corner.dx,corner.dy+seg*dy),p);
    }
  }
  @override bool shouldRepaint(covariant _ScanLockPainter old)=>
    old.progress!=progress;
}

class VehicleGuidanceScreen extends StatefulWidget{
  const VehicleGuidanceScreen({super.key,this.testMode=false});
  final bool testMode;
  @override State<VehicleGuidanceScreen> createState()=>_VehicleGuidanceScreenState();
}
class _VehicleGuidanceScreenState extends State<VehicleGuidanceScreen>
    with WidgetsBindingObserver {
  Map<String,dynamic> nav=<String,dynamic>{};
  Timer? timer;
  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(begin());
    timer=Timer.periodic(const Duration(milliseconds:750),(_)=>unawaited(read()));
  }
  Future<void> begin() async {
    try{await VehicleNative.startNav();}catch(_){}
    await read();
  }
  Future<void> read() async {
    try {
      final v=widget.testMode
          ?await VehicleNative.channel.invokeMethod<dynamic>('testNav')
          :await VehicleNative.nav();
      if(mounted)setState(()=>nav=Map<String,dynamic>.from(v as Map));
    }catch(_){}
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)unawaited(begin());
  }
  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    unawaited(VehicleNative.stopNav());
    super.dispose();
  }
  @override
  Widget build(BuildContext context){
    final lat=(nav['lat'] as num?)?.toDouble();
    final lon=(nav['lon'] as num?)?.toDouble();
    final bikeLat=(nav['parkLat'] as num?)?.toDouble();
    final bikeLon=(nav['parkLon'] as num?)?.toDouble();
    final age=(nav['ageMs'] as num?)?.toInt()??0;
    double? distance;
    if(lat!=null&&lon!=null&&bikeLat!=null&&bikeLon!=null){
      final lat1=lat*math.pi/180,lat2=bikeLat*math.pi/180;
      final dlat=(bikeLat-lat)*math.pi/180;
      final dlon=(bikeLon-lon)*math.pi/180;
      final a=math.pow(math.sin(dlat/2),2)+math.cos(lat1)*math.cos(lat2)*
          math.pow(math.sin(dlon/2),2);
      distance=6371000*2*math.atan2(math.sqrt(a),math.sqrt(math.max(0,1-a)));
    }
    final distanceText=distance==null?'— m':distance<100?
        distance.toStringAsFixed(1)+' m':distance.round().toString()+' m';
    return Scaffold(
      backgroundColor:Colors.white,
      body:SafeArea(child:Padding(
        padding:const EdgeInsets.fromLTRB(22,12,22,24),
        child:Column(children:<Widget>[
          Row(children:<Widget>[
            IconButton(onPressed:()=>Navigator.of(context).pop(),
              icon:const Icon(Icons.arrow_back_ios_new_rounded,
                color:Color(0xFF1B3442),size:21)),
            const SizedBox(width:8),
            Text(widget.testMode?'Tìm xe · TEST':'Tìm xe',style:const TextStyle(color:Color(0xFF1B3442),
              fontSize:22,fontWeight:FontWeight.w700)),
          ]),
          const SizedBox(height:25),
          Text(distanceText,style:const TextStyle(
            color:Color(0xFF1B3442),fontWeight:FontWeight.w800,fontSize:52)),
          const Text('Đến vị trí xe',style:TextStyle(
            color:Color(0xFF8997A0),fontSize:13)),
          Expanded(child:CustomPaint(
            painter:_NorthUpPainter(lat:lat,lon:lon,
              bikeLat:bikeLat,bikeLon:bikeLon),
            child:const SizedBox.expand())),
          if(lat==null||age>15000)
            Padding(padding:const EdgeInsets.only(bottom:12),
              child:Text(lat==null?'Đang lấy vị trí':'Vị trí gần đúng',
                style:const TextStyle(color:Color(0xFF8797A0),fontSize:12))),
        ]),
      )),
    );
  }
}

class _NorthUpPainter extends CustomPainter{
  const _NorthUpPainter({required this.lat,required this.lon,
    required this.bikeLat,required this.bikeLon});
  final double? lat,lon,bikeLat,bikeLon;
  @override
  void paint(Canvas canvas,Size size){
    if(bikeLat==null||bikeLon==null)return;
    final p=Paint()..isAntiAlias=true;
    final me=Offset(size.width*.5,size.height*.57);
    Offset bike=Offset(size.width*.5,size.height*.45);
    if(lat!=null&&lon!=null){
      final east=(bikeLon!-lon!)*111320*
          math.cos((bikeLat!+lat!)*math.pi/360);
      final north=(bikeLat!-lat!)*111320;
      final sx=size.width*.39/math.max(1,east.abs());
      final sy=size.height*.38/math.max(1,north.abs());
      final scale=math.min(10.0,math.min(sx,sy));
      bike=me+Offset(east*scale,-north*scale);
      p..color=const Color(0xFF728B99)..style=PaintingStyle.stroke
        ..strokeWidth=2.6;
      final d=bike-me,length=d.distance;
      for(var value=0.0;value<length;value+=17){
        canvas.drawLine(me+d*(value/math.max(1,length)),
          me+d*(math.min(length,value+9)/math.max(1,length)),p);
      }
    }
    p.style=PaintingStyle.fill;
    p.color=const Color(0xFFDDEFFF);
    canvas.drawCircle(me,16,p);
    p.color=const Color(0xFF258AC6);
    canvas.drawCircle(me,7.5,p);
    p.color=const Color(0xFFFFF0D8);
    canvas.drawCircle(bike,16,p);
    p.color=const Color(0xFFECAA3D);
    canvas.drawCircle(bike,7.5,p);
    void label(String text,Offset point){
      final tp=TextPainter(text:TextSpan(text:text,
          style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600,
            color:Color(0xFF1B3442))),
        textDirection:TextDirection.ltr)..layout();
      tp.paint(canvas,Offset(point.dx-tp.width/2,point.dy));
    }
    if(lat!=null&&lon!=null)label('BẠN',me+const Offset(0,27));
    label('XE ĐỖ',bike+const Offset(0,-37));
    final north=TextPainter(text:const TextSpan(text:'N ↑',
      style:TextStyle(fontSize:11,color:Color(0xFFA0ADB5))),
      textDirection:TextDirection.ltr)..layout();
    north.paint(canvas,Offset((size.width-north.width)/2,17));
  }
  @override bool shouldRepaint(covariant _NorthUpPainter old)=>
    old.lat!=lat||old.lon!=lon||old.bikeLat!=bikeLat||old.bikeLon!=bikeLon;
}
