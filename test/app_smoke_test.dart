import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/week_timetable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots into the official QLDT login flow', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const BetterPhenikaaScheduleApp());

    expect(find.text('Better Phenikaa App'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng bạn!'), findsOneWidget);
    expect(find.textContaining('Đăng nhập QLĐT'), findsOneWidget);
    expect(find.textContaining('demo'), findsNothing);
    expect(find.textContaining('mockup'), findsNothing);
  });

  testWidgets(
    'stored schedule opens day and week views without changing navigation',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final today = DateTime.now();
      final snapshot = ImportedScheduleData(
        displayName: 'Sinh viên',
        records: <ScheduleRecord>[
          ScheduleRecord(
            id: 'one',
            isExam: false,
            subjectName: 'Thiết kế web nâng cao',
            room: 'A1',
            startAt: DateTime(today.year, today.month, today.day, 7),
            endAt: DateTime(today.year, today.month, today.day, 9),
          ),
        ],
        syncedAt: today,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'better_phenikaa_snapshot_v1': snapshot.encode(),
      });
      await tester.pumpWidget(const BetterPhenikaaScheduleApp());
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('Theo ngày'), findsOneWidget);
      expect(find.text('Theo tuần'), findsOneWidget);
      await tester.tap(find.text('Theo tuần'));
      await tester.pumpAndSettle();
      // The seven-day list builds only visible days; Friday can start below
      // the test viewport even though the record belongs to this week.
      await tester.scrollUntilVisible(
        find.text('Thiết kế web nâng cao'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Thiết kế web nâng cao'), findsOneWidget);
      await tester.tap(find.byTooltip('Tuần sau'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final fades = tester.widgetList<FadeTransition>(
        find.descendant(
          of: find.byType(WeekTimetable),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(
        fades.any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1),
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(WeekTimetable),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(find.text('Thiết kế web nâng cao'), findsNothing);
      await tester.tap(find.text('Theo ngày'));
      await tester.pumpAndSettle();
      expect(find.text('Thiết kế web nâng cao'), findsOneWidget);
      expect(find.byTooltip('Tuần sau'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('restores subject database through the legacy view adapter', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final today = DateTime.now();
    final semester = const SemesterDataBuilder().build(
      registration: const RegisteredSemester(
        id: '2026_2027_1',
        name: '2026_2027_1',
        subjectNames: <String>['Thiết kế web nâng cao'],
      ),
      studySchedules: <ScheduleRecord>[
        ScheduleRecord(
          id: 'class',
          isExam: false,
          subjectName: 'Thiết kế web nâng cao',
          room: 'A1',
          startAt: DateTime(today.year, today.month, today.day, 7),
          endAt: DateTime(today.year, today.month, today.day, 9),
        ),
      ],
      examSchedules: const <ScheduleRecord>[],
      displayName: 'Sinh viên',
      syncedAt: today,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'better_phenikaa_current_semester_v1': semester.encode(),
    });
    await tester.pumpWidget(const BetterPhenikaaScheduleApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Theo ngày'), findsOneWidget);
    expect(find.text('Thiết kế web nâng cao'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
