import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../xem_truoc/theme_dust_transition.dart';
import 'kda_burn_field.dart';
import 'kda_runtime.dart';

/// Runs the approved fragment directly, without another WebView/GL context.
abstract final class KdaFireTransition {
  static Future<ui.FragmentProgram>? _program;
  static Future<ui.Image> _image(Uint8List bytes,int width,int height) {
    final result=Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes,width,height,ui.PixelFormat.rgba8888,result.complete);
    return result.future;
  }
  static Future<void> run(BuildContext context,Future<void> Function() apply) async {
    if(ThemeDustSurface.busy.value)return;
    ThemeDustSurface.busy.value=true;
    OverlayEntry? entry;
    final images=<ui.Image>[];
    try {
      final size=MediaQuery.sizeOf(context),dpr=MediaQuery.devicePixelRatioOf(context);
      final field=await compute(buildKdaBurnField,<String,num>{'seed':math.Random.secure().nextInt(0xffffffff),'aspect':size.width/size.height});
      final program=await (_program??=ui.FragmentProgram.fromAsset('shaders/kda_burn.frag'));
      images.addAll(await Future.wait([_image(field['noise']!,258,258),_image(field['arrival']!,128,224),_image(field['timing']!,256,1)]));
      if(!context.mounted)return;
      final completed=Completer<void>();
      entry=OverlayEntry(builder:(_)=>Positioned.fill(child:AbsorbPointer(child:_ApprovedBurn(key:const ValueKey('kda-approved-fire-vfx'),program:program,images:images,pixelRatio:dpr,onComplete:(){if(!completed.isCompleted)completed.complete();}))));
      Overlay.of(context,rootOverlay:true).insert(entry);
      await completed.future.timeout(const Duration(seconds:6));
      // Last shader frame is completely black; keep it until the MV is ready.
      await WidgetsBinding.instance.endOfFrame;
      await apply();
      await KdaRuntime.instance.waitForFrame();
      await WidgetsBinding.instance.endOfFrame;
    } on Object catch(error) {
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Không chạy được VFX FIRESTARTER: $error')));
    } finally {
      entry?.remove();entry?.dispose();
      for(final image in images){image.dispose();}
      ThemeDustSurface.busy.value=false;
    }
  }
}
class _ApprovedBurn extends StatefulWidget {
  const _ApprovedBurn({super.key,required this.program,required this.images,required this.pixelRatio,required this.onComplete});
  final ui.FragmentProgram program;
  final List<ui.Image> images;
  final double pixelRatio;
  final VoidCallback onComplete;
  @override State<_ApprovedBurn> createState()=>_ApprovedBurnState();
}
class _ApprovedBurnState extends State<_ApprovedBurn> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final ui.FragmentShader shader;
  final progress=ValueNotifier<double>(0);
  int painted=-1;
  @override void initState(){
    super.initState();
    shader=widget.program.fragmentShader();
    for(var i=0;i<3;i++){shader.setImageSampler(i,widget.images[i]);}
    controller=AnimationController(vsync:this,duration:const Duration(milliseconds:1500));
    controller.addListener((){final frame=(controller.value*45).floor();if(frame!=painted){painted=frame;progress.value=controller.value;}});
    unawaited(controller.forward().then((_){progress.value=1;widget.onComplete();}));
  }
  @override void dispose(){controller.dispose();progress.dispose();shader.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>CustomPaint(painter:_BurnPainter(shader,progress,widget.pixelRatio),child:const SizedBox.expand());
}
class _BurnPainter extends CustomPainter {
  _BurnPainter(this.shader,this.progress,this.pixelRatio):super(repaint:progress);
  final ui.FragmentShader shader;
  final ValueListenable<double> progress;
  final double pixelRatio;
  @override void paint(Canvas canvas,Size size){
    final scale=math.min(pixelRatio,math.min(1.5,900/size.height));
    shader.setFloat(0,(size.width*scale).roundToDouble());shader.setFloat(1,(size.height*scale).roundToDouble());
    shader.setFloat(2,progress.value*1.5);shader.setFloat(3,1.5);
    shader.setFloat(4,size.width);shader.setFloat(5,size.height);
    canvas.drawRect(Offset.zero&size,Paint()..shader=shader);
  }
  @override bool shouldRepaint(_BurnPainter old)=>old.shader!=shader||old.progress!=progress||old.pixelRatio!=pixelRatio;
}
