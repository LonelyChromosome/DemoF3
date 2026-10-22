import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../xem_truoc/theme_dust_transition.dart';
import 'kda_runtime.dart';
abstract final class KdaFireTransition {
 static Future<void> run(BuildContext context,Future<void> Function() apply) async {
  if(ThemeDustSurface.busy.value)return;ThemeDustSurface.busy.value=true;
  OverlayEntry? entry;final black=ValueNotifier<bool>(false);
  try {
   final source=await rootBundle.loadString('assets/kda/fire_transition.html');if(!context.mounted)return;
   final completed=Completer<void>();
   entry=OverlayEntry(builder:(_)=>Positioned.fill(child:AbsorbPointer(child:ValueListenableBuilder<bool>(valueListenable:black,builder:(_,covered,_)=>covered?const ColoredBox(color:Colors.black):InAppWebView(key:const ValueKey('kda-approved-fire-vfx'),initialData:InAppWebViewInitialData(data:source),initialSettings:InAppWebViewSettings(transparentBackground:true,javaScriptEnabled:true,supportZoom:false,disableContextMenu:true,useHybridComposition:true,verticalScrollBarEnabled:false,horizontalScrollBarEnabled:false),onWebViewCreated:(controller){controller.addJavaScriptHandler(handlerName:'KdaBurnComplete',callback:(_){if(!completed.isCompleted){black.value=true;completed.complete();}return null;});controller.addJavaScriptHandler(handlerName:'KdaBurnError',callback:(_){if(!completed.isCompleted)completed.completeError(StateError('WebGL không khả dụng'));return null;});},onLoadStop:(controller,_) async {await controller.evaluateJavascript(source:'if(window.BPABurn){window.BPABurn.play({duration:1.5});}else{window.flutter_inappwebview.callHandler("KdaBurnError");}');},onReceivedError:(_,request,error){if(!completed.isCompleted)completed.completeError(StateError(error.description));})))));
   Overlay.of(context,rootOverlay:true).insert(entry);
   await completed.future.timeout(const Duration(seconds:15));
   await WidgetsBinding.instance.endOfFrame;await apply();await WidgetsBinding.instance.endOfFrame;await KdaRuntime.instance.waitForFrame();await WidgetsBinding.instance.endOfFrame;
  }on Object catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Không chạy được VFX FIRESTARTER: $e')));}
  finally{entry?.remove();entry?.dispose();black.dispose();ThemeDustSurface.busy.value=false;}
 }
}
