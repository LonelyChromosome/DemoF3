import 'package:better_phenikaa_schedule/features/giao_dien/kda_firestarter/kda_runtime.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/kda_firestarter/kda_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){
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
 test('silent defaults and independent settings round-trip',(){const c=KdaConfig();expect(c.music,isFalse);expect(c.video,isTrue);final restored=KdaConfig.fromJson(c.copyWith(video:false,music:true,visualizer:false).toJson());expect(restored.video,isFalse);expect(restored.music,isTrue);expect(restored.visualizer,isFalse);expect(KdaConfig.fromJson({'intensity':99}).intensity,1.5);});
 testWidgets('lazy cinematic gate retains opened schedule state',(t) async {final r=KdaRuntime.instance;r.cardsVisible=false;var builds=0;await t.pumpWidget(MaterialApp(home:Scaffold(body:KdaContentGate(enabled:true,builder:(_){builds++;return const _Counter();}))));expect(builds,0);r.toggleCards();await t.pumpAndSettle();await t.tap(find.text('count 0'));await t.pump();expect(find.text('count 1'),findsOneWidget);r.toggleCards();await t.pumpAndSettle();expect(find.text('count 1'),findsNothing);r.toggleCards();await t.pumpAndSettle();expect(find.text('count 1'),findsOneWidget);await t.pumpWidget(const SizedBox());r.cardsVisible=false;});
}
class _Counter extends StatefulWidget {const _Counter();@override State<_Counter> createState()=>_CounterState();}
class _CounterState extends State<_Counter>{int count=0;@override Widget build(BuildContext context)=>TextButton(onPressed:()=>setState(()=>count++),child:Text('count $count'));}
