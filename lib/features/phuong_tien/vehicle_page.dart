import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'vehicle_navigation.dart';
import 'vehicle_native.dart';
import 'vehicle_permissions.dart';

class VehiclePage extends StatefulWidget {
  const VehiclePage({super.key, required this.windows, required this.active});
  final List<Map<String, dynamic>> windows;
  final bool active;
  @override State<VehiclePage> createState() => _VehiclePageState();
}
class _VehiclePageState extends State<VehiclePage> with WidgetsBindingObserver {
  Map<String, dynamic> data = <String, dynamic>{'enabled': false};
  bool queueExpanded = false;
  Timer? timer;
  bool busy = false;
  bool setupOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(initial());
    syncTimer();
  }
  Future<void> initial() async {
    try { await VehicleNative.schedule(widget.windows); } catch (_) {}
    await read();
  }
  @override
  void didUpdateWidget(covariant VehiclePage old) {
    super.didUpdateWidget(old);
    if(!old.active && widget.active) unawaited(read());
    if(old.active != widget.active) syncTimer();
    if(old.windows != widget.windows) {
      unawaited(VehicleNative.schedule(widget.windows).catchError((Object _) {}));
    }
  }
  void syncTimer() {
    timer?.cancel(); timer=null;
    if(!widget.active || WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.hidden ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.detached) return;
    timer=Timer.periodic(const Duration(seconds:2), (_) {
      if(!busy) unawaited(read());
    });
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    syncTimer();
    if (state == AppLifecycleState.resumed && widget.active) unawaited(read());
  }
  Future<void> read() async {
    try {
      final value=await VehicleNative.state();
      if(mounted) {
        setState(()=>data=value);
        if(widget.active && value['setupSeen'] != true && !setupOpen &&
            (!vehiclePermissionsReady(value) || value['enabled'] != true)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if(mounted && widget.active && !setupOpen) unawaited(setup());
          });
        }
      }
    }catch(_){}
  }
  Future<void> setup() async {
    if(setupOpen)return;
    setupOpen=true;
    try {
      await VehicleNative.setupSeen();
      if(mounted)await showVehiclePermissions(context);
    } finally {
      setupOpen=false;
      if(mounted)await read();
    }
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
  Future<void> manualReset() async {
    if(busy)return;
    final confirm=await showDialog<bool>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Làm mới trạng thái xe?'),
        content:const Text('Kết thúc lượt xe hiện tại, xóa vị trí đỗ đã lưu và tính lại hàng chờ từ lịch học BPA. Chỉ dùng khi trạng thái bị kẹt hoặc sai.'),
        actions:<Widget>[
          TextButton(onPressed:()=>Navigator.of(ctx).pop(false),
            child:const Text('Hủy')),
          FilledButton(onPressed:()=>Navigator.of(ctx).pop(true),
            child:const Text('Làm mới')),
        ],
      ),
    );
    if(confirm!=true||!mounted)return;
    setState(()=>busy=true);
    try {
      await VehicleNative.manualReset();
      await read();
    }on PlatformException catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('Không thể làm mới: ${e.message??e.code}')));
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Làm mới chưa thành công.')));
    }finally{
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
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); timer?.cancel(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final palette=appThemePalette;
    final primary=palette.primary;
    final enabled=data['enabled']==true;
    final parked=data['parked']==true;
    final tracking=data['tracking']==true;
    final foreground=data['location']==true;
    final background=data['background']==true;
    final ready=vehiclePermissionsReady(data);
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
            Row(children:<Widget>[
              Expanded(child:Text('Xe cộ',style:heading(27))),
              IconButton(
                tooltip:'Làm mới trạng thái xe',
                onPressed:busy?null:manualReset,
                icon:Icon(Icons.restart_alt_rounded,color:primary,size:25),
              ),
            ]),
            const SizedBox(height:24),
            Expanded(child:ListView(
              padding:EdgeInsets.zero,
              children:<Widget>[
                line(Icons.radar_rounded,'Trạng thái',
                    (!enabled)?'Chưa bật Find Bike':
                    (!foreground||!background)?'Cần cấp quyền định vị':
                    parked?'Đã đỗ xe · chờ thông báo ra cổng':
                    tracking?'Đang xác định vị trí đỗ':
                    waiting.isEmpty?'Không có môn cần chờ':
                    waiting.any((w)=>w is Map && w['available']==true)
                       ?'Đang chờ xe vào phạm vi'
                       :'Chờ lịch học tiếp theo'),
                const SizedBox(height:12),
                card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:<Widget>[
                  InkWell(
                    onTap:()=>setState(()=>queueExpanded=!queueExpanded),
                    borderRadius:BorderRadius.circular(12),
                    child:Padding(
                      padding:const EdgeInsets.symmetric(vertical:3),
                      child:Row(children:<Widget>[
                        Icon(Icons.calendar_month_rounded,color:primary,size:23),
                        const SizedBox(width:12),
                        Expanded(child:Column(
                          crossAxisAlignment:CrossAxisAlignment.start,
                          children:<Widget>[
                            Text('Môn học đang chờ',style:heading(15)),
                            const SizedBox(height:3),
                            Text(waiting.isEmpty?'Không có môn khả dụng':
                              '${waiting.length} buổi sắp tới',
                              style:TextStyle(color:palette.textSecondary,fontSize:12)),
                          ],
                        )),
                        Icon(queueExpanded?Icons.keyboard_arrow_up_rounded:
                            Icons.keyboard_arrow_down_rounded,color:primary),
                      ]),
                    ),
                  ),
                  if(queueExpanded)...<Widget>[
                    const SizedBox(height:12),
                    if(waiting.isEmpty)
                      Text('Hàng chờ trống. BPA sẽ tự cập nhật theo lịch học.',
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
                          return Padding(
                            padding:const EdgeInsets.only(bottom:9),
                            child:Row(children:<Widget>[
                              Icon(allowed?Icons.check_circle_rounded:Icons.cancel_rounded,
                                color:allowed?const Color(0xFF39BD87):palette.textSecondary,size:20),
                              const SizedBox(width:10),
                              Expanded(child:Column(
                                crossAxisAlignment:CrossAxisAlignment.start,
                                children:<Widget>[
                                  Text(row['name']?.toString()??'Môn học',maxLines:2,
                                    overflow:TextOverflow.ellipsis,
                                    style:TextStyle(color:palette.textPrimary,
                                      fontWeight:FontWeight.w700,fontSize:13)),
                                  Text('$day · $hour · ${row['status']??''}',
                                    style:TextStyle(color:palette.textSecondary,fontSize:11)),
                                ],
                              )),
                            ]),
                          );
                        }),
                      ],
                  ],
                ])),
                const SizedBox(height:12),
                line(Icons.admin_panel_settings_outlined, 'Thiết lập Find Bike',
                    ready && enabled ? 'Đã cấp đủ quyền' : 'Bật tính năng và cấp quyền cần thiết',
                    tap:()=>setup()),
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
                      ),
                    );
                  },
                ),
                const SizedBox(height:12),
                line(Icons.location_on_outlined,'Vị trí đỗ xe của tôi','',
                    tap:parked?()=>openNav():null),
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
