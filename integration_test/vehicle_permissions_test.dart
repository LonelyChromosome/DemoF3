import 'dart:async';
import 'package:better_phenikaa_schedule/features/phuong_tien/vehicle_native.dart';
import 'package:better_phenikaa_schedule/features/phuong_tien/vehicle_page.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/kda_firestarter/kda_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Find Bike first entry completes actual Android permission setup without timetable', (tester) async {
    Future<void> tick() => tester.pump(const Duration(milliseconds:250));
    Future<void> until(Future<bool> Function() predicate) async {
      final end=DateTime.now().add(const Duration(seconds:100));
      while(!await predicate() && DateTime.now().isBefore(end)) { await tick(); }
      expect(await predicate(),isTrue);
    }
    var state=await VehicleNative.state();
    expect(state['enabled'],isFalse);expect(state['location'],isFalse);
    expect(state['motion'],isFalse);expect(state['background'],isFalse);
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:VehiclePage(windows:[],active:true))));
    await until(() async => find.byKey(const ValueKey('findbike-permission-next')).evaluate().isNotEmpty);
    await tick();
    final next=find.byKey(const ValueKey('findbike-permission-next'));
    await tester.ensureVisible(next);await tick();
    debugPrint('FB_SETUP runtime start');
    await tester.tap(next);
    await until(() async {
      state=await VehicleNative.state();
      return state['enabled']==true && state['location']==true &&
          state['motion']==true && state['notifications']==true;
    });
    await until(() async => find.text('Cho phép vị trí nền').evaluate().isNotEmpty);
    expect(state['background'],isFalse);
    expect(state['notificationAccess'],isFalse);
    debugPrint('FB_SETUP runtime PASS; background start');
    await tester.tap(next);
    await until(() async => (await VehicleNative.state())['background']==true);
    await until(() async => find.text('Cho phép đọc thông báo').evaluate().isNotEmpty);
    debugPrint('FB_SETUP background PASS; listener start');
    await tester.tap(next);
    await until(() async => (await VehicleNative.state())['notificationAccess']==true);
    await until(() async => find.text('Hoàn tất').evaluate().isNotEmpty);
    await tester.tap(next);await tick();
    expect(find.byKey(const ValueKey('findbike-permission-setup')),findsNothing);
    state=await VehicleNative.state();expect(state['setupSeen'],isTrue);
    expect(state['tracking'],isFalse,reason:'No timetable means no tracking even after opt-in');
    // Existing KDA still requests its own microphone permission after Find Bike.
    debugPrint('FB_SETUP listener PASS; KDA microphone start');
    var microphone=false;
    unawaited(KdaRuntime.channel.invokeMethod<bool>('permission').then((value) {microphone=value==true;}));
    await until(() async => microphone);
    debugPrint('FB_SETUP COMPLETE: location, motion, notifications, background, listener, KDA microphone PASS');
    await tester.pumpWidget(const SizedBox());
  },timeout:const Timeout(Duration(minutes:7)));
}
