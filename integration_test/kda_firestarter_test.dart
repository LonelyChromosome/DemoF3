import 'dart:async';
import 'dart:io';
import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/kda_firestarter/kda_runtime.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/xem_truoc/theme_picker.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main(){
 IntegrationTestWidgetsFlutterBinding.ensureInitialized();
 testWidgets('native cinematic video, approved fire, schedule visibility, image mode and full loop',(tester) async {
  Future<void> wait(double seconds) async {final end=DateTime.now().add(Duration(milliseconds:(seconds*1000).round()));while(DateTime.now().isBefore(end)){await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:200)));await tester.pump();}}
  Future<Map<Object?,Object?>> state() async=>await KdaRuntime.channel.invokeMapMethod<Object?,Object?>('state')??{};
  final now=DateTime.now();
  final data=ImportedScheduleData(displayName:'KDA Android verification',records:[ScheduleRecord(id:'kda-test',isExam:false,subjectName:'FIRESTARTER timetable test',room:'A1',startAt:DateTime(now.year,now.month,now.day,7),endAt:DateTime(now.year,now.month,now.day,9))],syncedAt:now);
  final preferences=await SharedPreferences.getInstance();
  await preferences.clear();
  await preferences.setString('better_phenikaa_snapshot_v1',data.encode());
  await tester.pumpWidget(const BetterPhenikaaScheduleApp());await wait(4);
  expect(find.text('Theo ngày'),findsOneWidget);
  unawaited(showAppThemePicker(tester.element(find.text('Theo ngày'))));await wait(1);
  final tile=find.byKey(const ValueKey('kda-firestarter-theme-tile'));
  final themeScroll=find.descendant(of:find.byType(CustomScrollView).last,matching:find.byType(Scrollable)).first;
  for(var attempt=0;attempt<18 && tile.hitTestable().evaluate().isEmpty;attempt++){
    await tester.drag(themeScroll,const Offset(0,-180));await wait(.4);
  }
  expect(tile.hitTestable(),findsOneWidget,reason:'KDA tile must be inside the actual scroll viewport');
  await tester.tap(tile.hitTestable());await wait(.4);
  expect(find.byKey(const ValueKey('kda-approved-fire-vfx')),findsOneWidget);
  final activationDeadline=DateTime.now().add(const Duration(seconds:35));
  while(tile.evaluate().isNotEmpty && DateTime.now().isBefore(activationDeadline)){await wait(.5);}
  final runtime=KdaRuntime.instance;
  debugPrint('KDA activation: theme=${AppThemeController.instance.theme}, error=${runtime.error}, native=${await state()}');
  expect(tile,findsNothing,reason:'Activation closes Theme Settings before cinematic playback');
  expect(AppThemeController.instance.theme,AppThemeId.kdaFirestarter);expect(runtime.error,isNull);await runtime.waitForFrame();expect(runtime.ready,isTrue);expect(runtime.cardsVisible,isFalse);expect(find.text('Theo ngày'),findsNothing);expect((await state())['music'],isFalse);
  // Own-player FFT uses real decoded audio after adb grants the platform permission.
  var sawSignal=false;
  void observeAudio(){if(runtime.spectrum.value.any((v)=>v>.001))sawSignal=true;}
  runtime.spectrum.addListener(observeAudio);
  await runtime.save(runtime.config.copyWith(music:true));await wait(3);
  runtime.spectrum.removeListener(observeAudio);
  debugPrint('KDA audio: permission=${runtime.permission}, signal=$sawSignal, ${runtime.captureStatus}');
  expect(runtime.permission,isTrue);expect(sawSignal,isTrue,reason:runtime.captureStatus);
  await runtime.save(runtime.config.copyWith(music:false,visualizer:false));await wait(.5);
  expect(runtime.spectrum.value.every((v)=>v==0),isTrue);
  await runtime.save(runtime.config.copyWith(visualizer:true));
  final before=((await state())['positionMs'] as num).toInt();
  await tester.tap(find.byKey(const ValueKey('kda-toggle-cards')));await wait(1);expect(find.text('Theo ngày'),findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('kda-toggle-cards')));await wait(1);expect(find.text('Theo ngày'),findsNothing);expect(((await state())['positionMs'] as num).toInt(),greaterThan(before));
  await runtime.save(runtime.config.copyWith(video:false));await wait(1);expect((await state())['playing'],isFalse);expect(find.byType(Texture),findsNothing);
  await runtime.save(runtime.config.copyWith(video:true));await wait(3);expect((await state())['playing'],isTrue);expect(runtime.error,isNull);
  final end=DateTime.now().add(const Duration(seconds:225));var held=false;
  while(DateTime.now().isBefore(end)){final s=await state();if(s['holding']==true)held=true;if((s['loops'] as num).toInt()>=1)break;await wait(.5);}
  expect(held,isTrue);expect((await state())['loops'],greaterThanOrEqualTo(1));await wait(2);expect(((await state())['positionMs'] as num).toInt(),lessThan(15000));expect((await state())['playing'],isTrue);
  final marker=File('/sdcard/Android/data/vn.edu.phenikaa.better_phenikaa_schedule.kdatest/files/kda-ready');marker.parent.createSync(recursive:true);marker.writeAsStringSync('ready');await wait(8);expect((await state())['playing'],isTrue);
  await AppThemeController.instance.select(AppThemeId.classic);await wait(1);expect(find.byKey(const ValueKey('kda-toggle-cards')),findsNothing);expect((await state())['enabled'],isFalse);
  // Leave persisted real settings for installing and opening the delivered APK.
  await AppThemeController.instance.select(AppThemeId.kdaFirestarter);await wait(2);
 },timeout:const Timeout(Duration(minutes:8)));
}
