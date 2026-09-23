import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('day, week and exam views use the restored schedule', (
    tester,
  ) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 7);
    final exam = now.add(const Duration(days: 10));
    final data = ImportedScheduleData(
      displayName: 'Sinh viên mô phỏng',
      records: <ScheduleRecord>[
        ScheduleRecord(
          id: 'study',
          isExam: false,
          subjectName: 'Thiết kế web nâng cao',
          room: 'A1',
          startAt: start,
          endAt: start.add(const Duration(hours: 2)),
        ),
        ScheduleRecord(
          id: 'exam',
          isExam: true,
          subjectName: 'Thiết kế web nâng cao',
          room: 'C3',
          startAt: DateTime(exam.year, exam.month, exam.day, 8),
          endAt: DateTime(exam.year, exam.month, exam.day, 10),
        ),
      ],
      syncedAt: now,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'better_phenikaa_snapshot_v1': data.encode(),
    });
    await tester.pumpWidget(const BetterPhenikaaScheduleApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Theo ngày'), findsOneWidget);
    expect(find.text('Thiết kế web nâng cao'), findsWidgets);

    await tester.tap(find.text('Theo tuần'));
    await tester.pumpAndSettle();
    expect(find.text('Thiết kế web nâng cao'), findsWidgets);
    await tester.tap(find.byTooltip('Tuần sau'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tuần trước'));
    await tester.pumpAndSettle();
    expect(find.text('Thiết kế web nâng cao'), findsWidgets);

    await tester.tap(find.text('Theo ngày'));
    await tester.pumpAndSettle();
    expect(find.text('Thiết kế web nâng cao'), findsWidgets);
    await tester.tap(find.text('Lịch thi').last);
    await tester.pumpAndSettle();
    expect(find.text('Thiết kế web nâng cao'), findsWidgets);
  });
}
