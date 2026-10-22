import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'kda_runtime.dart';

class KdaStage extends StatefulWidget {
  const KdaStage({required this.enabled,required this.child,super.key});
  final bool enabled;final Widget child;
  @override State<KdaStage> createState()=>_KdaStageState();
}
class _KdaStageState extends State<KdaStage> with WidgetsBindingObserver {
  final runtime=KdaRuntime.instance;
  void sync()=>WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)unawaited(runtime.activate(widget.enabled));});
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);sync();}
  @override void didUpdateWidget(covariant KdaStage old){super.didUpdateWidget(old);if(old.enabled!=widget.enabled)sync();}
  @override void didChangeAppLifecycleState(AppLifecycleState state)=>runtime.setForeground(state==AppLifecycleState.resumed);
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);unawaited(runtime.activate(false));super.dispose();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:runtime,builder:(context,_){
    if(!widget.enabled)return widget.child;
    return Stack(fit:StackFit.expand,children:[
      const ColoredBox(color:Color(0xFF08040D)),
      Positioned.fill(child:Image.asset('assets/kda/stacked.png',fit:BoxFit.cover,gaplessPlayback:true)),
      if(runtime.config.video&&runtime.textureId!=null)Positioned.fill(child:IgnorePointer(child:ClipRect(child:FittedBox(fit:BoxFit.cover,child:SizedBox(width:runtime.width.toDouble(),height:runtime.height.toDouble(),child:Opacity(opacity:runtime.ready?1:.001,child:Texture(textureId:runtime.textureId!))))))),
      widget.child,
      if(runtime.config.visualizer)Positioned(left:24,right:24,bottom:MediaQuery.paddingOf(context).bottom+12,child:IgnorePointer(child:TickerMode(enabled:runtime.foreground,child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:380),child:KdaSpectrumDock(runtime:runtime)))))),
      Positioned(right:12,top:MediaQuery.paddingOf(context).top+8,child:Material(color:const Color(0xA0180C22),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24),side:const BorderSide(color:Color(0x99E184BE),width:.7)),child:Semantics(label:runtime.cardsVisible?'Ẩn giao diện BPA':'Hiện giao diện BPA',button:true,child:IconButton(key:const ValueKey('kda-toggle-cards'),onPressed:runtime.toggleCards,color:const Color(0xFFF6DEEF),icon:Icon(runtime.cardsVisible?Icons.visibility_off_outlined:Icons.dashboard_outlined))))),
    ]);
  });
}
/// Lazy on entry; once opened, retain UI state offstage without painting it.
class KdaContentGate extends StatefulWidget {
  const KdaContentGate({required this.enabled,required this.builder,super.key});
  final bool enabled;final WidgetBuilder builder;
  @override State<KdaContentGate> createState()=>_KdaContentGateState();
}
class _KdaContentGateState extends State<KdaContentGate> {
  Widget? content;bool hidden=true;
  @override Widget build(BuildContext context){
    if(!widget.enabled)return widget.builder(context);
    final r=KdaRuntime.instance;
    return AnimatedBuilder(animation:r,builder:(context,_){
      final visible=r.cardsVisible;
      if(visible){content=widget.builder(context);hidden=false;}
      if(content==null)return const SizedBox.expand();
      return Offstage(
        offstage: hidden && !visible,
        child: IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds:240),
            onEnd: () {if(mounted && !r.cardsVisible)setState(()=>hidden=true);},
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0,.025),
              duration: const Duration(milliseconds:240),
              child: Padding(
                padding: EdgeInsets.only(top:56,bottom:r.config.visualizer?110:8),
                child: TickerMode(enabled:visible&&r.foreground,child:content!),
              ),
            ),
          ),
        ),
      );
    });
  }
}
class KdaSpectrumDock extends StatefulWidget {
  const KdaSpectrumDock({required this.runtime,super.key});final KdaRuntime runtime;
  @override State<KdaSpectrumDock> createState()=>_KdaSpectrumDockState();
}
class _KdaSpectrumDockState extends State<KdaSpectrumDock> with SingleTickerProviderStateMixin {
  final values=List<double>.filled(48,0);final repaint=ValueNotifier<int>(0);
  late final Ticker ticker;List<double> target=List.filled(48,0);Duration last=Duration.zero;DateTime lastInput=DateTime.fromMillisecondsSinceEpoch(0);
  @override void initState(){super.initState();ticker=createTicker(tick);widget.runtime.spectrum.addListener(input);}
  void input(){target=widget.runtime.spectrum.value;lastInput=DateTime.now();if(widget.runtime.foreground&&target.any((v)=>v>.0001)&&!ticker.isActive){last=Duration.zero;ticker.start();}}
  void tick(Duration elapsed){final dt=(elapsed-last).inMicroseconds/1000000;if(dt<1/30)return;last=elapsed;final stale=DateTime.now().difference(lastInput).inMilliseconds>500;var peak=0.0;
    for(var i=0;i<48;i++){final to=stale||!widget.runtime.foreground||i>=target.length?0.0:target[i];final tau=to > values[i] ? .055 : .22;values[i]+=(to-values[i])*(1-math.exp(-dt.clamp(0,.1)/tau));peak=math.max(peak,values[i]);}
    repaint.value++;if(peak<.0005||!widget.runtime.foreground)ticker.stop();
  }
  @override void dispose(){widget.runtime.spectrum.removeListener(input);ticker.dispose();repaint.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>SizedBox(height:74,child:Column(children:[SizedBox(height:20,child:KdaMarquee(animated:widget.runtime.config.marquee)),SizedBox(height:50,width:double.infinity,child:RepaintBoundary(child:CustomPaint(painter:_SpectrumPainter(values,repaint,widget.runtime.config.intensity))))]));
}
class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter(this.values,Listenable repaint,this.intensity):super(repaint:repaint);final List<double> values;final double intensity;
  @override void paint(Canvas canvas,Size size){final shader=const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFF80F5FF),Color(0xFFBDA2FF),Color(0xFFFF76D3)]).createShader(Offset.zero&size);final center=size.height-5;
    final glow=Paint()..shader=shader..strokeWidth=3..strokeCap=StrokeCap.round..maskFilter=const MaskFilter.blur(BlurStyle.normal,5);
    final core=Paint()..shader=shader..strokeWidth=1.5..strokeCap=StrokeCap.round;
    canvas.drawLine(Offset(0,center),Offset(size.width,center),glow);canvas.drawLine(Offset(0,center),Offset(size.width,center),core);
    for(var i=0;i<values.length;i++){final h=(values[i]*intensity).clamp(0,1)*(center-3);if(h<.1)continue;final x=(i+.5)*size.width/values.length;final a=Offset(x,center-h),b=Offset(x,center);canvas.drawLine(a,b,glow);canvas.drawLine(a,b,core);}
  }
  @override bool shouldRepaint(covariant _SpectrumPainter old)=>true;
}
class KdaMarquee extends StatefulWidget {
  const KdaMarquee({required this.animated,super.key});final bool animated;
  @override State<KdaMarquee> createState()=>_KdaMarqueeState();
}
class _KdaMarqueeState extends State<KdaMarquee> with SingleTickerProviderStateMixin {
  late final clock=AnimationController(vsync:this,duration:const Duration(seconds:14));
  @override void initState(){super.initState();if(widget.animated)clock.repeat();}
  @override void didUpdateWidget(covariant KdaMarquee old){super.didUpdateWidget(old);if(widget.animated!=old.animated){if(widget.animated)clock.repeat();else clock.stop();}}
  @override void dispose(){clock.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Semantics(label:'KDA FIRESTARTER',child:RepaintBoundary(child:CustomPaint(painter:_MarqueePainter(clock,widget.animated),size:const Size(double.infinity,20))));
}
class _MarqueePainter extends CustomPainter {
  _MarqueePainter(this.clock,this.animated):super(repaint:clock){text=TextPainter(text:const TextSpan(text:'KDA FIRESTARTER    •    ',style:TextStyle(color:Color(0xFFF9DAF5),fontSize:11,fontWeight:FontWeight.w800,letterSpacing:2.2)),textDirection:TextDirection.ltr)..layout();}
  final Animation<double> clock;final bool animated;late final TextPainter text;
  @override void paint(Canvas canvas,Size size){canvas.save();canvas.clipRect(Offset.zero&size);if(!animated)text.paint(canvas,Offset((size.width-text.width)/2,2));else{for(var x=-clock.value*text.width;x<size.width;x+=text.width){text.paint(canvas,Offset(x,2));}}canvas.restore();}
  @override bool shouldRepaint(covariant _MarqueePainter old)=>old.animated!=animated;
}
