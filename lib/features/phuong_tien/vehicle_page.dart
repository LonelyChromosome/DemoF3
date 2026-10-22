import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'vehicle_navigation.dart';

class VehicleNative {
  static const channel = MethodChannel('better_phenikaa/vehicle');
  static Future<Map<String, dynamic>> state() async {
    if (kIsWeb) return <String, dynamic>{'enabled': false};
    final value = await channel.invokeMethod<dynamic>('state');
    return Map<String, dynamic>.from(value as Map);
  }
  static Future<void> enable() async { await channel.invokeMethod<dynamic>('enable'); }
  static Future<void> permissionSettings() async { await channel.invokeMethod<dynamic>('permissionSettings'); }
  static Future<void> requestNotificationAccess() async {
    await channel.invokeMethod<dynamic>('requestNotificationAccess');
  }
  static Future<void> permissions() async { await channel.invokeMethod<dynamic>('permissions'); }
  static Future<void> schedule(List<Map<String, dynamic>> windows) async {
    await channel.invokeMethod<dynamic>('schedule', <String, Object>{'windows': windows});
  }
  static Future<Map<String, dynamic>> testState() async {
    final value=await channel.invokeMethod<dynamic>('testState');
    return Map<String, dynamic>.from(value as Map);
  }
  static Future<String> testEvent(String method) async {
    final value=await channel.invokeMethod<String>(method);
    return value??'Đã gửi sự kiện';
  }
  static Future<void> startNav() async { await channel.invokeMethod<dynamic>('startNav'); }
  static Future<void> stopNav() async { await channel.invokeMethod<dynamic>('stopNav'); }
  static Future<Map<String, dynamic>> nav() async {
    final value = await channel.invokeMethod<dynamic>('nav');
    return Map<String, dynamic>.from(value as Map);
  }
}

class VehiclePage extends StatefulWidget {
  const VehiclePage({super.key, required this.windows, required this.active});
  final List<Map<String, dynamic>> windows;
  final bool active;
  @override State<VehiclePage> createState() => _VehiclePageState();
}
class _VehiclePageState extends State<VehiclePage> {
  Map<String, dynamic> data = <String, dynamic>{'enabled': false};
  Map<String, dynamic> testData = <String, dynamic>{'tracking':false,'parked':false};
  Timer? timer;
  bool busy = false;
  bool testOpen = false;
  String testResult = '';
  static const eventPanelEnabled =
      bool.fromEnvironment('BPA_VEHICLE_TEST_PANEL',defaultValue:kDebugMode);
  @override
  void initState() {
    super.initState();
    unawaited(initial());
    timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if(widget.active && !busy) unawaited(read());
    });
  }
  Future<void> initial() async {
    try { await VehicleNative.schedule(widget.windows); } catch (_) {}
    await read();
  }
  @override
  void didUpdateWidget(covariant VehiclePage old) {
    super.didUpdateWidget(old);
    if(!old.active && widget.active) unawaited(read());
    if(old.windows != widget.windows) {
      unawaited(VehicleNative.schedule(widget.windows).catchError((Object _) {}));
    }
  }
  Future<void> read() async {
    try {
      final value=await VehicleNative.state();
      Map<String,dynamic> test=<String,dynamic>{};
      if(eventPanelEnabled) {
        try {test=await VehicleNative.testState();}catch(_){}
      }
      if(mounted)setState((){
        data=value;
        if(test.isNotEmpty)testData=test;
      });
    }catch(_){}
  }
  Future<void> enable() async {
    if(busy)return;
    setState(()=>busy=true);
    try { await VehicleNative.enable(); await read(); } catch (_) {}
    if(mounted)setState(()=>busy=false);
  }
  Future<void> openNav({bool testMode=false}) async {
    if(busy || (testMode?testData['parked']:data['parked']) != true)return;
    setState(()=>busy=true);
    // The location request starts BEFORE the VFX animation starts.
    try { await VehicleNative.startNav(); } catch (_) {}
    if(!mounted)return;
    setState(()=>busy=false);
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => VehicleScanLockScreen(testMode:testMode)));
    if(mounted)unawaited(read());
  }
  Future<void> testEvent(String method) async {
    if(busy)return;
    if(method=='testReset'){
      final allow=await showDialog<bool>(
        context:context,builder:(ctx)=>AlertDialog(
          title:const Text('Reset phiên kiểm thử?'),
          content:const Text('Chỉ xóa hành trình và xe đỗ trong APK demo này. Dữ liệu BPA chính không bị ảnh hưởng.'),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Hủy')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Reset')),
          ],
        ),
      );
      if(allow!=true||!mounted)return;
    }
    setState(()=>busy=true);
    try{
      final message=await VehicleNative.testEvent(method);
      if(mounted)setState(()=>testResult=message);
    }on PlatformException catch(e){
      if(mounted)setState(()=>testResult='Không thể thực hiện: ${e.message??e.code}');
    }catch(e){
      if(mounted)setState(()=>testResult='Không thể thực hiện: $e');
    }finally{
      await read();
      if(mounted)setState(()=>busy=false);
    }
  }
  List<Offset> get trace {
    final raw=data['route'];
    if(raw is! List)return const <Offset>[];
    final points=<Offset>[];
    for(final row in raw) {
      if(row is List && row.length>=2 && row[0] is num && row[1] is num) {
        points.add(Offset((row[1] as num).toDouble(),(row[0] as num).toDouble()));
      }
    }
    return points;
  }
  @override void dispose() { timer?.cancel(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final palette=appThemePalette;
    final primary=palette.primary;
    final enabled=data['enabled']==true;
    final parked=data['parked']==true;
    final tracking=data['tracking']==true;
    final foreground=data['location']==true;
    final background=data['background']==true;
    final exitAccess=data['notificationAccess']==true;
    final testTracking=testData['tracking']==true;
    final testParked=testData['parked']==true;
    final rawWindows=data['waitingSubjects'];
    final waiting=rawWindows is List?rawWindows:const <dynamic>[];
    Widget card(Widget child,{VoidCallback? tap})=>Material(
      color:palette.card.withValues(alpha:.9),
      borderRadius:BorderRadius.circular(20),
      child:InkWell(onTap:tap,borderRadius:BorderRadius.circular(20),
        child:Container(
          padding:const EdgeInsets.all(18),
          decoration:BoxDecoration(
            border:Border.all(color:palette.border,width:1.1),
            borderRadius:BorderRadius.circular(20)),
          child:child,
        ),
      ),
    );
    TextStyle heading(double size)=>TextStyle(
      color:palette.textPrimary,fontSize:size,fontWeight:FontWeight.w800);
    Widget line(IconData icon,String title,String detail,{VoidCallback? tap})=>card(
      Row(children:<Widget>[
        Icon(icon,color:primary,size:26),
        const SizedBox(width:14),
        Expanded(child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:<Widget>[
            Text(title,style:heading(15)),
            if(detail.isNotEmpty)...<Widget>[
              const SizedBox(height:5),
              Text(detail,style:TextStyle(color:palette.textSecondary,fontSize:13)),
            ],
          ],
        )),
        if(tap!=null)Icon(Icons.chevron_right,color:primary),
      ]),
      tap:tap,
    );
    return SafeArea(
      child:Padding(
        padding:const EdgeInsets.fromLTRB(20,22,20,24),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,
          children:<Widget>[
            Text('Phương Tiện',style:heading(27)),
            const SizedBox(height:24),
            Expanded(child:ListView(
              padding:EdgeInsets.zero,
              children:<Widget>[
                line(Icons.radar_rounded,'Trạng thái',
                    (!enabled)?'Chờ dữ liệu lịch học':
                    (!foreground||!background)?'Cần cấp quyền':
                    tracking?'Đang ghi hành trình':
                    parked?'Đã xác định vị trí xe':'Đang chờ lịch học'),
                const SizedBox(height:12),
                card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:<Widget>[
                  Row(children:<Widget>[
                    Icon(Icons.calendar_month_rounded,color:primary,size:23),
                    const SizedBox(width:10),
                    Expanded(child:Text('Các môn học đang được chờ',style:heading(15))),
                  ]),
                  const SizedBox(height:12),
                  if(waiting.isEmpty)
                    Text('Chưa có môn học sắp tới từ lịch BPA.',
                      style:TextStyle(color:palette.textSecondary,fontSize:13)),
                  for(final raw in waiting)
                    if(raw is Map)...<Widget>[
                      Builder(builder:(context){
                        final row=Map<String,dynamic>.from(raw);
                        final allowed=row['available']==true;
                        final start=(row['start'] as num?)?.toInt()??0;
                        final when=DateTime.fromMillisecondsSinceEpoch(start);
                        final day='${when.day.toString().padLeft(2,'0')}/${when.month.toString().padLeft(2,'0')}';
                        final hour='${when.hour.toString().padLeft(2,'0')}:${when.minute.toString().padLeft(2,'0')}';
                        return Padding(padding:const EdgeInsets.only(bottom:10),
                          child:Row(children:<Widget>[
                            Icon(allowed?Icons.check_circle_rounded:Icons.cancel_rounded,
                              size:22,color:allowed?const Color(0xFF39BD87):palette.textSecondary),
                            const SizedBox(width:10),
                            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                              children:<Widget>[
                                Text(row['name']?.toString()??'Môn học',
                                    maxLines:2,overflow:TextOverflow.ellipsis,
                                    style:TextStyle(color:palette.textPrimary,
                                      fontSize:13,fontWeight:FontWeight.w700)),
                                Text('$day · $hour · ${row['status']??''}',
                                  style:TextStyle(color:palette.textSecondary,fontSize:11)),
                              ])),
                          ]));
                      }),
                    ],
                ])),
                if(!foreground||!background)...<Widget>[
                  const SizedBox(height:12),
                  line(Icons.gps_fixed_rounded,'Cấp quyền định vị','',
                    tap:()async {
                      try {
                        if(!foreground) {
                          await VehicleNative.permissions();
                        } else {
                          await VehicleNative.permissionSettings();
                        }
                      }catch(_){}
                    }),
                ],
                const SizedBox(height:12),
                if(!exitAccess)...<Widget>[
                  const SizedBox(height:12),
                  line(Icons.notifications_active_outlined,
                    'Cấp quyền nhận thông báo Phenikaa Uni',
                    'Cấp quyền Truy cập thông báo một lần để tự kết thúc lượt gửi xe.',
                    tap:()=>VehicleNative.requestNotificationAccess()),
                ],
                line(Icons.two_wheeler_rounded,'Xe đã dừng',
                    parked?'Đã đỗ xe':'Chưa ghi nhận'),
                const SizedBox(height:12),
                card(Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:<Widget>[
                    Row(children:<Widget>[
                      Icon(Icons.route_rounded,color:primary),
                      const SizedBox(width:12),
                      Expanded(child:Text('Xem lộ trình di chuyển',
                          style:heading(15))),
                      Icon(Icons.chevron_right,color:palette.textSecondary),
                    ]),
                    const SizedBox(height:12),
                    ClipRRect(borderRadius:BorderRadius.circular(12),
                      child:ColoredBox(color:Colors.white,
                        child:SizedBox(width:double.infinity,height:142,
                          child:CustomPaint(painter:VehicleTracePainter(trace))))),
                  ]),
                  tap:trace.length<2?null:() {
                    showModalBottomSheet<void>(
                      context:context,
                      backgroundColor:Colors.white,
                      isScrollControlled:true,
                      showDragHandle:true,
                      builder:(_)=>SafeArea(child:Padding(
                        padding:const EdgeInsets.all(20),
                        child:SizedBox(
                          height:MediaQuery.sizeOf(context).height*.62,
                          child:Column(
                            crossAxisAlignment:CrossAxisAlignment.start,
                            children:<Widget>[
                              const Text('Lộ trình di chuyển',style:TextStyle(
                                fontSize:19,fontWeight:FontWeight.w700,
                                color:Color(0xFF1B3442))),
                              const SizedBox(height:12),
                              Expanded(child:CustomPaint(
                                painter:VehicleTracePainter(trace),
                                child:const SizedBox.expand())),
                            ]),
                        )),
                      ),
                    );
                  },
                ),
                const SizedBox(height:12),
                line(Icons.location_on_outlined,'Vị trí đỗ xe của tôi','',
                    tap:parked?()=>openNav():null),
                if(eventPanelEnabled)...<Widget>[
                  const SizedBox(height:18),
                  card(Column(crossAxisAlignment:CrossAxisAlignment.start,
                    children:<Widget>[
                      InkWell(
                        onTap:()=>setState(()=>testOpen=!testOpen),
                        child:Row(children:<Widget>[
                          Icon(Icons.science_outlined,color:primary),
                          const SizedBox(width:9),
                          Expanded(child:Text('PANEL TEST SỰ KIỆN',
                            style:heading(14))),
                          Text('DEMO',style:TextStyle(color:palette.textSecondary,
                            fontWeight:FontWeight.w600,fontSize:10)),
                          const SizedBox(width:4),
                          Icon(testOpen?Icons.expand_less:Icons.expand_more,
                              color:primary),
                        ]),
                      ),
                      if(testOpen)...<Widget>[
                        const SizedBox(height:10),
                        Text('Giả lập tín hiệu vào cổng / bước chân. '
                          'Tọa độ và lộ trình vẫn lấy từ GPS thật.',
                          style:TextStyle(color:palette.textSecondary,fontSize:12)),
                        const SizedBox(height:14),
                        Wrap(spacing:9,runSpacing:9,children:<Widget>[
                          OutlinedButton.icon(
                            onPressed:busy||testTracking||testParked?null:()=>testEvent('testGate'),
                            icon:const Icon(Icons.meeting_room_outlined,size:18),
                            label:const Text('Vào cổng')),
                          OutlinedButton.icon(
                            onPressed:busy||!testTracking?null:()=>testEvent('testWalk'),
                            icon:const Icon(Icons.directions_walk,size:18),
                            label:const Text('Bước chân')),
                          OutlinedButton.icon(
                            onPressed:busy||!testTracking?null:()=>testEvent('testPark'),
                            icon:const Icon(Icons.location_on_outlined,size:18),
                            label:const Text('Chốt xe GPS')),
                          OutlinedButton.icon(
                            onPressed:busy||!testParked?null:()=>testEvent('testExit'),
                            icon:const Icon(Icons.logout,size:18),
                            label:const Text('Xe ra cổng [TEST]')),
                          OutlinedButton.icon(
                            onPressed:busy?null:()=>testEvent('testReset'),
                            icon:const Icon(Icons.restart_alt,size:18),
                            label:const Text('Reset')),
                        ]),
                        const SizedBox(height:11),
                        Text('Phiên TEST: '+
                          (testTracking?'Đang ghi GPS':testParked?'Đã đỗ xe':'Chưa ghi')+
                          '  ·  '+((testData['route'] as List?)?.length??0).toString()+' điểm',
                          style:TextStyle(color:palette.textSecondary,fontSize:12)),
                        if(testParked)
                          OutlinedButton.icon(
                            onPressed:busy?null:()=>openNav(testMode:true),
                            icon:const Icon(Icons.navigation_outlined,size:18),
                            label:const Text('Dẫn tới xe TEST')),
                        if(testResult.isNotEmpty)...<Widget>[
                          const SizedBox(height:7),
                          Text(testResult,style:TextStyle(color:primary,fontSize:12)),
                        ],
                      ],
                    ],
                  )),
                ],
              ],
            )),
          ],
        ),
      ),
    );
  }
}

/// Reconstructs real recorded coordinates. North-up, white background.
class VehicleTracePainter extends CustomPainter {
  const VehicleTracePainter(this.points);
  final List<Offset> points;
  @override void paint(Canvas canvas,Size size) {
    final paint=Paint()..isAntiAlias=true;
    if(points.length<2) {
      paint..color=const Color(0xFFE8F0F3)
        ..strokeWidth=1..style=PaintingStyle.stroke;
      for(var i=0;i<5;i++){
        final y=size.height*(i+1)/6;
        canvas.drawLine(Offset(12,y),Offset(size.width-12,y),paint);
      }
      return;
    }
    var minX=points.first.dx,maxX=points.first.dx;
    var minY=points.first.dy,maxY=points.first.dy;
    for(final point in points) {
      minX=math.min(minX,point.dx);maxX=math.max(maxX,point.dx);
      minY=math.min(minY,point.dy);maxY=math.max(maxY,point.dy);
    }
    final ratio=math.cos((minY+maxY)*math.pi/360);
    final spanX=math.max(.0000001,(maxX-minX)*ratio);
    final spanY=math.max(.0000001,maxY-minY);
    final padding=math.min(30.0,math.min(size.width,size.height)*.17);
    final scale=math.min((size.width-2*padding)/spanX,
      (size.height-2*padding)/spanY);
    final cx=(minX+maxX)*.5,cy=(minY+maxY)*.5;
    Offset xy(Offset point)=>Offset(
      size.width*.5+(point.dx-cx)*ratio*scale,
      size.height*.5-(point.dy-cy)*scale);
    final path=Path()..moveTo(xy(points.first).dx,xy(points.first).dy);
    for(final point in points.skip(1)) {
      final p=xy(point);path.lineTo(p.dx,p.dy);
    }
    paint..color=const Color(0xFF12AFC3)..strokeWidth=2.5
      ..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round
      ..style=PaintingStyle.stroke;
    canvas.drawPath(path,paint);
    paint.style=PaintingStyle.fill;
    paint.color=const Color(0xFF258BC5);
    canvas.drawCircle(xy(points.first),4.5,paint);
    paint.color=const Color(0xFFEFAD3F);
    canvas.drawCircle(xy(points.last),5.2,paint);
  }
  @override bool shouldRepaint(covariant VehicleTracePainter old)=>
    !listEquals(old.points,points);
}
