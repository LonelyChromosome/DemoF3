import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';

/// UI-only fixtures for the side-by-side 1.6 APK.
/// Do not persist these to QLDT, sync snapshots, notifications or widgets.
ImportedScheduleData withAlarmTestFixture(
  ImportedScheduleData? original,
  DateTime now,
) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);

  ScheduleRecord mock(String key, int hour, int minute, int duration) {
    final starts = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
    return ScheduleRecord(
      id: 'bpa16-fixture-$key-${tomorrow.year}-${tomorrow.month}-${tomorrow.day}',
      subjectName: '[TEST 1.6] Báo thức ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      room: 'Lịch giả • không thuộc QLĐT',
      startAt: starts,
      endAt: starts.add(Duration(minutes: duration)),
      isExam: false,
    );
  }

  return ImportedScheduleData(
    displayName: original?.displayName.isNotEmpty == true
        ? original!.displayName
        : 'BPA 1.6 - Alarm Test',
    records: <ScheduleRecord>[
      ...?original?.records,
      mock('morning', 9, 30, 90),
      mock('afternoon', 13, 30, 90),
      mock('late', 23, 30, 25),
    ]..sort((a, b) => a.startAt.compareTo(b.startAt)),
    syncedAt: original?.syncedAt ?? now,
    source: original?.source ?? 'alarm_test_ui_only',
  );
}
