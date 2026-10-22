import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KdaConfig {
  const KdaConfig({this.video=true,this.music=true,this.visualizer=true,this.marquee=true,this.intensity=1});
  factory KdaConfig.fromJson(Map<String,dynamic> j)=>KdaConfig(video:j['video'] as bool? ?? true,music:j['music'] as bool? ?? true,visualizer:j['visualizer'] as bool? ?? true,marquee:j['marquee'] as bool? ?? true,intensity:(j['intensity'] as num? ?? 1).toDouble().clamp(.35,1.5));
  final bool video,music,visualizer,marquee;
  final double intensity;
  KdaConfig copyWith({bool? video,bool? music,bool? visualizer,bool? marquee,double? intensity})=>KdaConfig(video:video??this.video,music:music??this.music,visualizer:visualizer??this.visualizer,marquee:marquee??this.marquee,intensity:intensity??this.intensity);
  Map<String,Object> toJson()=>{'video':video,'music':music,'visualizer':visualizer,'marquee':marquee,'intensity':intensity};
}
class KdaRuntime extends ChangeNotifier {
  KdaRuntime._();
  static final instance=KdaRuntime._();
  static const channel=MethodChannel('better_phenikaa/kda_media');
  static const events=EventChannel('better_phenikaa/kda_events');
  static const preferenceKey='bpa_kda_firestarter_v1';
  static const firstEntryKey='bpa_kda_firestarter_first_entry_v2';
  static const cardsPreferenceKey='bpa_kda_firestarter_cards_visible_v1';
  KdaConfig config=const KdaConfig();
  bool enabled=false,cardsVisible=false,ready=false,permission=false,foreground=true;
  int? textureId;
  int? captureTimeUs;
  int width=1440,height=2560;
  String? error;
  String captureStatus='Chưa có tín hiệu âm thanh';
  final spectrum=ValueNotifier<List<double>>(List.filled(48,0));
  StreamSubscription<dynamic>? subscription;
  Future<void>? loading;
  Future<void>? firstEntry;
  Future<void> queue=Future.value();
  Future<void> cardsWrites=Future.value();
  Completer<void>? frame;
  Future<void> load()=>loading??=_load();
  Future<void> _load() async {
    final p=await SharedPreferences.getInstance();
    try {final raw=p.getString(preferenceKey);if(raw!=null)config=KdaConfig.fromJson(jsonDecode(raw) as Map<String,dynamic>);} on Object {config=const KdaConfig();}
    cardsVisible=p.getBool(cardsPreferenceKey)??false;
    notifyListeners();
  }
  /// Ask once on entry, before the burn starts; later entries respect saved music.
  Future<void> prepareFirstEntry() async {
    if(firstEntry!=null){await firstEntry;return;}
    final pending=_prepareFirstEntry();firstEntry=pending;
    try{await pending;}finally{firstEntry=null;}
  }
  Future<void> _prepareFirstEntry() async {
    await load();
    final p=await SharedPreferences.getInstance();
    if(p.getBool(firstEntryKey)==true)return;
    final initial=config.copyWith(music:true);
    if(!await p.setString(preferenceKey,jsonEncode(initial.toJson())))throw StateError('Không lưu được thiết lập FIRESTARTER');
    config=initial;
    if(!await p.setBool(firstEntryKey,true))throw StateError('Không lưu được thiết lập FIRESTARTER');
    notifyListeners();
    await requestPermission();
  }
  /// Only a deliberate switch from another theme starts a fresh session.
  /// Cold starts and lifecycle resume keep the user's current session.
  Future<void> startNewSession() async {
    await load();
    await cardsWrites;
    final initial=config.copyWith(video:true,music:true);
    final p=await SharedPreferences.getInstance();
    if(!await p.setString(preferenceKey,jsonEncode(initial.toJson())))throw StateError('Không lưu được thiết lập FIRESTARTER');
    if(!await p.setBool(cardsPreferenceKey,false))throw StateError('Không lưu được trạng thái card KDA');
    config=initial;cardsVisible=false;ready=false;
    // Serialize the native disable before activation, even for rapid re-entry.
    if(enabled){enabled=false;await configure();}
    notifyListeners();
  }
  Future<void> activate(bool value) async {
    if(enabled==value)return;
    enabled=value;ready=false;error=null;textureId=null;
    if(frame!=null&&!frame!.isCompleted)frame!.complete();
    frame=value?Completer<void>():null;
    notifyListeners();await load();if(value)await prepareFirstEntry();
    if(value&&enabled){subscription??=events.receiveBroadcastStream().listen(receive,onError:(Object e){error=e.toString();settle();});}
    await configure();
    if(!enabled){await subscription?.cancel();subscription=null;spectrum.value=List.filled(48,0);}
  }
  Future<void> save(KdaConfig value) async {
    final p=await SharedPreferences.getInstance();
    if(!await p.setString(preferenceKey,jsonEncode(value.toJson())))throw StateError('Không lưu được thiết lập FIRESTARTER');
    config=value;notifyListeners();if(enabled)await configure();
  }
  Future<void> configure(){
    final args={'enabled':enabled,'video':config.video,'music':config.music,'visualizer':config.visualizer};
    queue=queue.then((_) async {
      if(kIsWeb||defaultTargetPlatform!=TargetPlatform.android){ready=true;settle();return;}
      try {final s=await channel.invokeMapMethod<Object?,Object?>('configure',args);if(s!=null)receive(s);}
      on MissingPluginException {error='Video cần bản Android đã build';settle();}
      on PlatformException catch(e){error=e.message;settle();}
    }).catchError((Object e){error=e.toString();settle();});
    return queue;
  }
  void receive(dynamic s){
    if(s is! Map)return;
    if(s['type']=='fft'){captureTimeUs=(s['captureTimeUs'] as num?)?.toInt();spectrum.value=(s['bands'] as List).whereType<num>().map((v)=>v.toDouble().clamp(0,1).toDouble()).toList();return;}
    textureId=(s['textureId'] as num?)?.toInt();width=(s['width'] as num?)?.toInt()??1440;height=(s['height'] as num?)?.toInt()??2560;
    ready=s['ready']==true;permission=s['permission']==true;error=s['error'] as String?;captureStatus=s['captureStatus'] as String? ?? captureStatus;foreground=s['foreground']!=false;settle();
  }
  void settle(){if((ready||error!=null||!config.video)&&frame!=null&&!frame!.isCompleted)frame!.complete();notifyListeners();}
  Future<void> waitForFrame() async {if(ready||error!=null||!config.video)return;await (frame?.future??Future<void>.value()).timeout(const Duration(seconds:12),onTimeout:(){error='Video chưa sẵn sàng; đang dùng ảnh nền';notifyListeners();});}
  Future<bool> requestPermission() async {try {permission=await channel.invokeMethod<bool>('permission')??false;notifyListeners();return permission;}on PlatformException{return false;}on MissingPluginException{return false;}}
  Future<void> toggleCards(){
    cardsVisible=!cardsVisible;final visible=cardsVisible;notifyListeners();
    // Serialize quick taps so the last choice is the last persisted value.
    cardsWrites=cardsWrites.then((_) async {
      final p=await SharedPreferences.getInstance();
      if(!await p.setBool(cardsPreferenceKey,visible))debugPrint('Không lưu được trạng thái card KDA');
    }).catchError((Object e){debugPrint('Không lưu được trạng thái card KDA: $e');});
    return cardsWrites;
  }
  void setForeground(bool value){foreground=value;if(!value)spectrum.value=List.filled(48,0);notifyListeners();}
}
