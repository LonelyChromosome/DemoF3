import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/phuong_tien/vehicle_native.dart';
import 'package:better_phenikaa_schedule/features/phuong_tien/vehicle_page.dart';
import 'package:better_phenikaa_schedule/features/phuong_tien/vehicle_permissions.dart';
import 'package:better_phenikaa_schedule/features/phuong_tien/vehicle_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('vehicle windows are a read-only timetable projection, exclude exams and eLearning', () {
    final at=DateTime(2026,10,23,9);
    ScheduleRecord row(String id,{bool exam=false,String? kind}) => ScheduleRecord(
      id:id,isExam:exam,subjectName:id,room:'A1',startAt:at,endAt:at.add(const Duration(hours:2)),lessonKind:kind);
    final original=[row('LT',kind:'LT'),row('TH',kind:'TH'),row('online',kind:'ELEARNING'),row('exam',exam:true)];
    final before=original.map((r)=>r.toJson()).toList();
    final windows=vehicleScheduleWindows(original);
    expect(windows.map((r)=>r['name']),['LT','TH']);
    windows.first['name']='isolated copy';
    expect(original.map((r)=>r.toJson()).toList(),before);
  });
  testWidgets('hidden module does not enable GPS and recovery requires confirmation', (tester) async {
    final calls=<String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VehicleNative.channel,(call) async {
      calls.add(call.method);
      if(call.method=='state')return <String,dynamic>{'enabled':false,'waitingSubjects':<dynamic>[]};
      return null;
    });
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:VehiclePage(windows:[],active:false))));
    await tester.pump();
    expect(calls,contains('schedule'));expect(calls,isNot(contains('enable')));
    await tester.tap(find.byTooltip('Làm mới trạng thái xe'));
    await tester.pumpAndSettle();
    expect(find.text('Làm mới trạng thái xe?'),findsOneWidget);
    expect(calls,isNot(contains('manualReset')));
    await tester.tap(find.text('Hủy'));await tester.pumpAndSettle();
    expect(calls,isNot(contains('manualReset')));
    await tester.pumpWidget(const SizedBox());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VehicleNative.channel,null);
  });
  testWidgets('first visible entry offers setup; enabling works with no timetable', (tester) async {
    final calls=<String>[];
    final state=<String,dynamic>{'enabled':false, 'setupSeen':false,
      'location':false, 'background':false, 'motion':false, 'notifications':false,
      'notificationAccess':false, 'waitingSubjects':<dynamic>[]};
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VehicleNative.channel,(call) async {
      calls.add(call.method);
      if(call.method=='setupSeen')state['setupSeen']=true;
      if(call.method=='enable') {
        state['enabled']=true;state['location']=true;state['notifications']=true;
        // Simulate a user denying physical activity while granting location.
      }
      if(call.method=='permissions')state['motion']=true;
      return Map<String,dynamic>.from(state);
    });
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:VehiclePage(windows:[],active:true))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('findbike-permission-setup')),findsOneWidget);
    expect(calls,isNot(contains('enable')),reason:'Showing setup is not an opt-in');
    final next=find.byKey(const ValueKey('findbike-permission-next'));
    await tester.ensureVisible(next);await tester.tap(next);await tester.pumpAndSettle();
    expect(calls,contains('enable'));expect(state['enabled'],isTrue);
    expect(find.text('Cấp quyền còn thiếu'),findsOneWidget);
    await tester.tap(next);await tester.pumpAndSettle();
    expect(calls,contains('permissions'));expect(find.text('Cho phép vị trí nền'),findsOneWidget);
    await tester.tap(next);await tester.pumpAndSettle();
    expect(calls,contains('backgroundPermission'));
    state['background']=true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Cho phép đọc thông báo'),findsOneWidget);
    await tester.tap(next);await tester.pumpAndSettle();
    expect(calls,contains('requestNotificationAccess'));
    state['notificationAccess']=true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Hoàn tất'),findsOneWidget);
    await tester.tap(next);await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('findbike-permission-setup')),findsNothing);
    expect(find.text('Đã cấp đủ quyền'),findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VehicleNative.channel,null);
  });
  testWidgets('setup dismissal is remembered and permanently denied permissions have recovery', (tester) async {
    final calls=<String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VehicleNative.channel,(call) async {
      calls.add(call.method);
      return <String,dynamic>{'enabled':true,'setupSeen':true,'location':false,
        'motion':true,'notifications':true,'background':false,'notificationAccess':false,
        'blockedPermissions':['android.permission.ACCESS_FINE_LOCATION']};
    });
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:VehiclePage(windows:[],active:true))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('findbike-permission-setup')),findsNothing);
    await tester.tap(find.text('Thiết lập Find Bike'));await tester.pumpAndSettle();
    expect(find.text('Mở cài đặt quyền'),findsOneWidget);
    final next=find.byKey(const ValueKey('findbike-permission-next'));
    await tester.ensureVisible(next);await tester.tap(next);await tester.pumpAndSettle();
    expect(calls,contains('permissionSettings'));expect(calls,isNot(contains('permissions')));
    await tester.pumpWidget(const SizedBox());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VehicleNative.channel,null);
  });
  test('permission readiness includes motion and listener access independently', () {
    final state=<String,dynamic>{for(final key in ['location','motion','notifications','background','notificationAccess'])key:true};
    expect(vehiclePermissionsReady(state),isTrue);
    state['motion']=false;expect(vehiclePermissionsReady(state),isFalse);
    state['motion']=true;state['notificationAccess']=false;
    expect(vehiclePermissionsReady(state),isFalse);
  });

}
