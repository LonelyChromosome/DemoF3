import 'package:flutter/material.dart';
import 'kda_runtime.dart';
class KdaSettings extends StatelessWidget {
 const KdaSettings({super.key});
 @override Widget build(BuildContext context){final r=KdaRuntime.instance;return AnimatedBuilder(animation:r,builder:(context,_){final c=r.config;
 Future<void> save(KdaConfig value) async {try{await r.save(value);}on Object catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
 return Column(key:const ValueKey('kda-theme-settings'),crossAxisAlignment:CrossAxisAlignment.start,children:[
 const Text('K/DA FIRESTARTER',style:TextStyle(fontWeight:FontWeight.w800)),
 SwitchListTile.adaptive(title:const Text('Video Background'),subtitle:const Text('Tắt để dùng ảnh ghép 4 nhân vật'),value:c.video,onChanged:(v)=>save(c.copyWith(video:v))),
 SwitchListTile.adaptive(title:const Text('Nhạc FIRESTARTER'),subtitle:const Text('Âm thanh độc lập với nền video'),value:c.music,onChanged:(v)=>save(c.copyWith(music:v))),
 SwitchListTile.adaptive(title:const Text('Audio Visualizer'),subtitle:const Text('Phổ âm thanh thật; không có tín hiệu thì đứng yên'),value:c.visualizer,onChanged:(v)=>save(c.copyWith(visualizer:v))),
 if(c.visualizer)...[Text(r.captureStatus,style:Theme.of(context).textTheme.bodySmall),if(!r.permission)TextButton.icon(icon:const Icon(Icons.equalizer),label:const Text('Cấp quyền lấy phổ âm thanh'),onPressed:r.requestPermission),const Text('Android yêu cầu quyền âm thanh cho FFT. Theme không dùng micro. Nguồn ngoài có thể bị Android hoặc ứng dụng phát chặn.',style:TextStyle(fontSize:11)),SwitchListTile.adaptive(title:const Text('Chữ KDA FIRESTARTER chạy ngang'),value:c.marquee,onChanged:(v)=>save(c.copyWith(marquee:v))),Row(children:[const Text('Cường độ'),Expanded(child:Slider(value:c.intensity,min:.35,max:1.5,onChanged:(v)=>save(c.copyWith(intensity:v))))])],
 if(r.error!=null)Text(r.error!,style:const TextStyle(color:Color(0xFFFFC4CC))),const SizedBox(height:12)]);
 });}
}
