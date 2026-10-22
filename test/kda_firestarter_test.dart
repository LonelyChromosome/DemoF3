import 'package:better_phenikaa_schedule/features/giao_dien/kda_firestarter/kda_runtime.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/kda_firestarter/kda_stage.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/kda_firestarter/kda_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){
 setUp((){SharedPreferences.setMockInitialValues({});final r=KdaRuntime.instance;r.cardsWrites=Future.value();r.loading=null;});
 testWidgets('cinematic control works outside the Navigator overlay',(tester) async {
  final r=KdaRuntime.instance;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(KdaRuntime.channel,(_) async=>{'type':'state','ready':true});
  r.enabled=true;r.cardsVisible=false;r.config=const KdaConfig(video:false,visualizer:false,marquee:false);
  await tester.pumpWidget(MaterialApp(builder:(_,child)=>KdaStage(enabled:true,child:child!),home:Scaffold(backgroundColor:Colors.transparent,body:KdaContentGate(enabled:true,builder:(_)=>const _Counter()))));
  expect(tester.takeException(),isNull);
  expect(find.text('count 0'),findsNothing);
  await tester.tap(find.byKey(const ValueKey('kda-toggle-cards')));await tester.pumpAndSettle();
  expect(find.text('count 0'),findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('kda-toggle-cards')));await tester.pumpAndSettle();
  expect(find.text('count 0'),findsNothing);
  await tester.pumpWidget(const SizedBox());await tester.pump();
  r.cardsVisible=false;r.config=const KdaConfig();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(KdaRuntime.channel,null);
 });
 test('music defaults on and explicit mute survives settings round-trip',(){const c=KdaConfig();expect(c.music,isTrue);expect(c.video,isTrue);final restored=KdaConfig.fromJson(c.copyWith(video:false,music:true,visualizer:false).toJson());expect(restored.video,isFalse);expect(restored.music,isTrue);expect(restored.visualizer,isFalse);expect(KdaConfig.fromJson({'intensity':99}).intensity,1.5);});
 testWidgets('first entry requests audio once, including upgrade, then respects mute',(tester) async {
  SharedPreferences.setMockInitialValues({KdaRuntime.preferenceKey:jsonEncode(const KdaConfig(music:false).toJson())});
  final r=KdaRuntime.instance;r.loading=null;r.enabled=false;r.firstEntry=null;
  var requests=0;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(KdaRuntime.channel,(call) async {if(call.method=='permission'){requests++;return false;}return null;});
  await Future.wait([r.prepareFirstEntry(),r.prepareFirstEntry()]);
  expect(requests,1);expect(r.config.music,isTrue);expect(r.permission,isFalse);
  await r.save(r.config.copyWith(music:false));
  r.loading=null;await r.prepareFirstEntry();
  expect(requests,1);expect(r.config.music,isFalse);
  final p=await SharedPreferences.getInstance();expect(p.getBool(KdaRuntime.firstEntryKey),isTrue);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(KdaRuntime.channel,null);
  r.loading=null;r.config=const KdaConfig();
 });
 test('last card choice survives reload and rapid toggles',() async {
  final r=KdaRuntime.instance;r.loading=null;await r.load();expect(r.cardsVisible,isFalse);
  await r.toggleCards();expect(r.cardsVisible,isTrue);
  r.cardsVisible=false;r.loading=null;await r.load();expect(r.cardsVisible,isTrue);
  await Future.wait([r.toggleCards(),r.toggleCards(),r.toggleCards()]);
  expect(r.cardsVisible,isFalse);
  r.cardsVisible=true;r.loading=null;await r.load();expect(r.cardsVisible,isFalse);
  r.loading=null;r.ready=true;
 });
 test('new theme entry resets session while cold reload preserves it',() async {
  final r=KdaRuntime.instance;r.enabled=false;
  await r.load();
  await r.save(const KdaConfig(video:false,music:false,visualizer:false,marquee:false,intensity:.6));
  final pending=r.toggleCards();
  await r.startNewSession();await pending;
  expect(r.cardsVisible,isFalse);expect(r.config.video,isTrue);expect(r.config.music,isTrue);
  expect(r.config.visualizer,isFalse);expect(r.config.marquee,isFalse);expect(r.config.intensity,.6);
  r.loading=null;await r.load();expect(r.cardsVisible,isFalse);
  await r.toggleCards();await r.save(r.config.copyWith(video:false,music:false));
  r.cardsVisible=false;r.loading=null;await r.load();
  expect(r.cardsVisible,isTrue);expect(r.config.video,isFalse);expect(r.config.music,isFalse);
  r.cardsVisible=false;r.config=const KdaConfig();r.loading=null;
 });
 testWidgets('compact settings have controls without descriptive subtitles',(tester) async {
  final r=KdaRuntime.instance;r.enabled=false;r.config=const KdaConfig();r.permission=true;
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:KdaSettings())));
  expect(find.text('Nhạc'),findsOneWidget);expect(find.text('Video nền'),findsOneWidget);
  for(final tile in tester.widgetList<SwitchListTile>(find.byType(SwitchListTile))){expect(tile.subtitle,isNull);}
  expect(find.textContaining('Phổ âm thanh thật'),findsNothing);
  expect(find.textContaining('Android yêu cầu'),findsNothing);
  await tester.pumpWidget(const SizedBox());r.permission=false;
 });
 testWidgets('lazy cinematic gate retains opened schedule state',(t) async {final r=KdaRuntime.instance;r.cardsVisible=false;r.ready=true;var builds=0;await t.pumpWidget(MaterialApp(home:Scaffold(body:KdaContentGate(enabled:true,builder:(_){builds++;return const _Counter();}))));expect(builds,0);r.toggleCards();await t.pumpAndSettle();await t.tap(find.text('count 0'));await t.pump();expect(find.text('count 1'),findsOneWidget);r.toggleCards();await t.pumpAndSettle();expect(find.text('count 1'),findsNothing);r.toggleCards();await t.pumpAndSettle();expect(find.text('count 1'),findsOneWidget);await t.pumpWidget(const SizedBox());r.cardsVisible=false;});
}
class _Counter extends StatefulWidget {const _Counter();@override State<_Counter> createState()=>_CounterState();}
class _CounterState extends State<_Counter>{int count=0;@override Widget build(BuildContext context)=>TextButton(onPressed:()=>setState(()=>count++),child:Text('count $count'));}
