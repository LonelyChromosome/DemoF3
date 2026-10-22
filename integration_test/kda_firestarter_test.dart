import 'dart:async';
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
 testWidgets('native cinematic video, approved fire, schedule visibility, image mode and end-of-stream loop',(tester) async {
  Future<void> wait(double seconds) async {final end=DateTime.now().add(Duration(milliseconds:(seconds*1000).round()));var frames=0;final minimum=seconds>=.5?3:1;while(frames<minimum||DateTime.now().isBefore(end)){await tester.pump(const Duration(milliseconds:200));frames++;}}
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
  await tester.tap(tile.hitTestable());
  final fireDeadline=DateTime.now().add(const Duration(seconds:60));
  while(find.byKey(const ValueKey('kda-approved-fire-vfx')).evaluate().isEmpty && DateTime.now().isBefore(fireDeadline)){await wait(.1);}
  expect(find.byKey(const ValueKey('kda-approved-fire-vfx')),findsOneWidget);
  final activationDeadline=DateTime.now().add(const Duration(seconds:35));
  while(tile.evaluate().isNotEmpty && DateTime.now().isBefore(activationDeadline)){await wait(.5);}
  final runtime=KdaRuntime.instance;
  debugPrint('KDA activation: theme=${AppThemeController.instance.theme}, error=${runtime.error}, native=${await state()}');
  expect(tile,findsNothing,reason:'Activation closes Theme Settings before cinematic playback');
  expect(AppThemeController.instance.theme,AppThemeId.kdaFirestarter);expect(runtime.error,isNull);await runtime.waitForFrame();expect(runtime.ready,isTrue);expect(runtime.cardsVisible,isFalse);expect(find.text('Theo ngày'),findsNothing);expect((await state())['music'],isTrue);expect(runtime.permission,isTrue);
  final before=((await state())['positionMs'] as num).toInt();
  await tester.tap(find.byKey(const ValueKey('kda-toggle-cards')));await wait(1);expect(find.text('Theo ngày'),findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('kda-toggle-cards')));expect(runtime.cardsVisible,isFalse);
  final hideDeadline=DateTime.now().add(const Duration(seconds:5));
  while(find.text('Theo ngày').evaluate().isNotEmpty&&DateTime.now().isBefore(hideDeadline)){await wait(.25);}
  expect(find.text('Theo ngày'),findsNothing);expect(((await state())['positionMs'] as num).toInt(),greaterThan(before));
  await runtime.save(runtime.config.copyWith(music:false));
  await runtime.save(runtime.config.copyWith(video:false));await wait(1);expect((await state())['playing'],isFalse);expect(find.byType(Texture),findsNothing);
  await runtime.save(runtime.config.copyWith(video:true));await wait(3);debugPrint('KDA video restarted: ${await state()}');expect((await state())['playing'],isTrue);expect(runtime.error,isNull);
  expect(((await state())['durationMs'] as num).toInt(),closeTo(207000,1500));
  // Exercise real end-of-stream + 3s hold without benchmarking the CI software
  // decoder for the entire MV. The shipped 207s file is hash-verified separately.
  await KdaRuntime.channel.invokeMethod<Object?>('seek',{'positionMs':198000});
  final end=DateTime.now().add(const Duration(seconds:40));var held=false;var nextProbe=DateTime.now();
  while(DateTime.now().isBefore(end)){final s=await state();if(DateTime.now().isAfter(nextProbe)){debugPrint('KDA loop checkpoint: $s');nextProbe=DateTime.now().add(const Duration(seconds:30));}if(s['holding']==true)held=true;if((s['loops'] as num).toInt()>=1)break;await wait(.5);}
  debugPrint('KDA loop ended wait: held=$held, ${await state()}');
  expect(held,isTrue);expect((await state())['loops'],greaterThanOrEqualTo(1));await wait(2);expect(((await state())['positionMs'] as num).toInt(),lessThan(15000));expect((await state())['playing'],isTrue);
  debugPrint('KDA full loop passed: ${await state()}');
  // Own-player FFT uses real decoded audio after adb grants the platform permission.
  var sawSignal=false;
  void observeAudio(){if(runtime.spectrum.value.any((v)=>v>.001))sawSignal=true;}
  await runtime.save(runtime.config.copyWith(music:true));
  debugPrint('KDA FFT started');
  runtime.spectrum.addListener(observeAudio);
  final signalDeadline=DateTime.now().add(const Duration(seconds:12));
  while(!sawSignal && DateTime.now().isBefore(signalDeadline)){await wait(.2);}
  runtime.spectrum.removeListener(observeAudio);
  debugPrint('KDA audio: permission=${runtime.permission}, signal=$sawSignal, ${runtime.captureStatus}, native=${await state()}');
  expect(runtime.permission,isTrue);expect(sawSignal,isTrue,reason:runtime.captureStatus);
  await tester.tap(find.byKey(const ValueKey('kda-toggle-cards')));await wait(.5);
  unawaited(showAppThemePicker(tester.element(find.text('Theo ngày'))));await wait(1);
  final customize=find.byKey(const ValueKey('kda-customize-theme'));
  final settingsDeadline=DateTime.now().add(const Duration(seconds:15));
  while(customize.hitTestable().evaluate().isEmpty&&DateTime.now().isBefore(settingsDeadline)){await wait(.5);}
  expect(customize.hitTestable(),findsOneWidget);
  expect(find.byKey(const ValueKey('kda-theme-settings')),findsNothing);
  await tester.tap(customize);await wait(.5);
  expect(find.byKey(const ValueKey('kda-theme-settings')),findsOneWidget);
  expect(find.text('Nhạc'),findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('kda-setting-music')));await wait(.5);
  expect(runtime.config.music,isFalse);expect((await state())['music'],isFalse);
  await tester.tap(find.byKey(const ValueKey('kda-settings-close')));await wait(.5);
  Navigator.of(tester.element(customize)).pop();await wait(.5);
  await tester.tap(find.byKey(const ValueKey('kda-toggle-cards')));await wait(.5);
  await runtime.save(runtime.config.copyWith(music:false,visualizer:false));await wait(.5);
  expect(runtime.spectrum.value.every((v)=>v==0),isTrue);
  await runtime.save(runtime.config.copyWith(visualizer:true));
  await AppThemeController.instance.select(AppThemeId.classic);await wait(1);expect(find.byKey(const ValueKey('kda-toggle-cards')),findsNothing);expect((await state())['enabled'],isFalse);
  await AppThemeController.instance.select(AppThemeId.kdaFirestarter);await wait(2);expect(runtime.config.music,isFalse);expect((await state())['music'],isFalse);expect(runtime.cardsVisible,isFalse);
  await runtime.toggleCards();await wait(.5);expect(runtime.cardsVisible,isTrue);
  await AppThemeController.instance.select(AppThemeId.classic);await wait(.5);
  await AppThemeController.instance.select(AppThemeId.kdaFirestarter);await wait(2);
  expect(runtime.cardsVisible,isTrue);expect(find.text('Theo ngày'),findsOneWidget);
  // Cold-start of the exact delivered APK must restore the last visible state.
  await runtime.cardsWrites;debugPrint('KDA persisted cards visible: ${runtime.cardsVisible}');
 },timeout:const Timeout(Duration(minutes:8)));
}
