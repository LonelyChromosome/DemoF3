import 'dart:convert';

import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/week_timetable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('restored verified attendance is shown on study cards', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final now = DateTime.now();
      final schedule = ImportedScheduleData(
        displayName: 'Sinh viên',
        records: <ScheduleRecord>[
          ScheduleRecord(
            id: 'today-practice',
            isExam: false,
            subjectName: 'Lập trình cho thiết bị di động',
            room: 'A6-203 (PC)',
            startAt: DateTime(now.year, now.month, now.day, 9, 30),
            endAt: DateTime(now.year, now.month, now.day, 12, 10),
          ),
        ],
        syncedAt: now,
      );
      const accountRoute = 'verified-test-student-route';
      SharedPreferences.setMockInitialValues(<String, Object>{
        'better_phenikaa_snapshot_v1': schedule.encode(),
        'better_phenikaa_qldt_registration_route_v1': accountRoute,
        'better_phenikaa_attendance_v17': jsonEncode({
          'schema': 2,
          'route': accountRoute,
          'programId': null,
          'allocations': {
            normalizeSubjectName('Lập trình cho thiết bị di động'): 15.0,
          },
          'counts': {
            normalizeSubjectName('Lập trình cho thiết bị di động'): {
              'absentPeriods': 6,
              'theoryPeriods': 15,
            },
          },
        }),
      });
      await tester.pumpWidget(const BetterPhenikaaScheduleApp());
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('Đã nghỉ 2/1'), findsWidgets);
      await tester.tap(find.text('Theo tuần'));
      await tester.pumpAndSettle();
      final week = find.byType(WeekTimetable);
      expect(week, findsOneWidget);
      final weeklyTag = find.descendant(
        of: week,
        matching: find.text('Đã nghỉ 2/1'),
      );
      await tester.scrollUntilVisible(
        weeklyTag,
        100,
        scrollable: find.descendant(
          of: week,
          matching: find.byType(Scrollable),
        ).first,
      );
      expect(weeklyTag, findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('unrelated account attendance never appears on a card', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'better_phenikaa_snapshot_v1': ImportedScheduleData(
          displayName: 'Sinh viên',
          records: <ScheduleRecord>[
            ScheduleRecord(
              id: 'class-today',
              isExam: false,
              subjectName: 'Lập trình cho thiết bị di động',
              room: 'A6',
              startAt: DateTime(now.year, now.month, now.day, 10),
              endAt: DateTime(now.year, now.month, now.day, 11),
            ),
          ],
          syncedAt: now,
        ).encode(),
        'better_phenikaa_qldt_registration_route_v1': 'current-account',
        'better_phenikaa_attendance_v17': jsonEncode({
          'schema': 2,
          'route': 'other-account',
          'allocations': {
            normalizeSubjectName('Lập trình cho thiết bị di động'): 15.0,
          },
          'counts': {
            normalizeSubjectName('Lập trình cho thiết bị di động'): {
              'absentPeriods': 6,
              'theoryPeriods': 15,
            },
          },
        }),
      });
      await tester.pumpWidget(const BetterPhenikaaScheduleApp());
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('Đã nghỉ 2/1'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
