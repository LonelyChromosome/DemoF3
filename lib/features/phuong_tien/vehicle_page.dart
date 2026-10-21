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
  static Future<void> permissions() async { await channel.invokeMethod<dynamic>('permissions'); }
  static Future<void> schedule(List<Map<String, int>> windows) async {
    await channel.invokeMethod<dynamic>('schedule', <String, Object>{'windows': windows});
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
  final List<Map<String, int>> windows;
  final bool active;
  @override State<VehiclePage> createState() => _VehiclePageState();
}
class _VehiclePageState extends State<VehiclePage> {
  Map<String, dynamic> data = <String, dynamic>{'enabled': false};
  Timer? timer;
  bool busy = false;
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
      if(mounted)setState(()=>data=value);
    }catch(_){}
  }
  Future<void> enable() async {
    if(busy)return;
    setState(()=>busy=true);
    try { await VehicleNative.enable(); await read(); } catch (_) {}
    if(mounted)setState(()=>busy=false);
  }
  Future<void> openNav() async {
    if(busy || data['parked'] != true)return;
    setState(()=>busy=true);
    // The location request starts BEFORE the VFX animation starts.
    try { await VehicleNative.startNav(); } catch (_) {}
    if(!mounted)return;
    setState(()=>busy=false);
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => const VehicleScanLockScreen()));
    if(mounted)unawaited(read());
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
            if(!enabled)
              Expanded(child:Center(child:SizedBox(
                width:double.infinity,height:58,
                child:FilledButton.icon(
                  onPressed:busy?null:enable,
                  icon:const Icon(Icons.two_wheeler_rounded),
                  label:const Text('Bật Tìm xe của bạn'),
                  style:FilledButton.styleFrom(
                    backgroundColor:primary,foregroundColor:Colors.white,
                    shape:RoundedRectangleBorder(
                      borderRadius:BorderRadius.circular(18))),
                ),
              )))
            else Expanded(child:ListView(
              padding:EdgeInsets.zero,
              children:<Widget>[
                line(Icons.radar_rounded,'Trạng thái',
                    (!foreground||!background)?'Cần cấp quyền':tracking?'Đang ghi hành trình':parked?'Đã xác định vị trí xe':'Đang theo dõi'),
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
                      )),
                    );
                  },
                ),
                const SizedBox(height:12),
                line(Icons.location_on_outlined,'Vị trí đỗ xe của tôi','',
                    tap:parked?openNav:null),
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
