import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('notification bell shows 1.8 Water Cooling release notes', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final now = DateTime.now();
    final data = ImportedScheduleData(
      displayName: 'Sinh viên',
      syncedAt: now,
      records: [
        ScheduleRecord(
          id: 'study-1',
          isExam: false,
          subjectName: 'Thiết kế web nâng cao',
          room: 'A1',
          startAt: DateTime(now.year, now.month, now.day, 7),
          endAt: DateTime(now.year, now.month, now.day, 9),
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'better_phenikaa_snapshot_v1': data.encode(),
    });

    await tester.pumpWidget(const BetterPhenikaaScheduleApp());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thông báo thay đổi lịch'));
    await tester.pumpAndSettle();
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Update log'), findsOneWidget);
    expect(find.text('cooc.1.8'), findsOneWidget);
    expect(find.text('Theme Premium 2: Water Cooling'), findsOneWidget);
    expect(find.text('cooc1.6'), findsNothing);
    expect(find.text('Bổ sung VFX'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
