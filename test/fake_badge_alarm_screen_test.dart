import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/attendance_tag.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/study_alarm_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('original BPA day card shows badge and alarm without overlap',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const BpaFakeAttendanceAlarmApp());
    await tester.pumpAndSettle();

    expect(find.text('Lịch học'), findsOneWidget);
    expect(find.text('Theo ngày'), findsOneWidget);
    expect(find.text('Thiết kế web nâng cao'), findsOneWidget);
    expect(find.text('Đã nghỉ 0/3'), findsOneWidget);
    expect(find.byType(StudyAlarmCard), findsOneWidget);
    expect(find.byIcon(Icons.alarm_outlined), findsOneWidget);

    final badge = tester.getRect(find.byType(AttendanceTag));
    final alarmIcon = tester.getRect(find.byIcon(Icons.alarm_outlined));
    expect(badge.right, lessThan(alarmIcon.left),
        reason: 'The attendance badge must never overlap the alarm icon');
  });
}
