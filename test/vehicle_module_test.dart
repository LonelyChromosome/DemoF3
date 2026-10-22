import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/phuong_tien/vehicle_native.dart';
import 'package:better_phenikaa_schedule/features/phuong_tien/vehicle_page.dart';
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
}
