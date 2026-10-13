import 'dart:math' as math;

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/attendance_tag.dart';
import 'package:better_phenikaa_schedule/features/recap/recap_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('spinner never jumps, reverses or changes axis at cycle boundary', () {
    expect(RecapSpin.angle(0), closeTo(0, 0.000001));
    expect(RecapSpin.angle(1), closeTo(12 * math.pi, 0.000001));
    var angle = RecapSpin.angle(0);
    for (var i = 1; i <= 1000; i++) {
      final current = RecapSpin.angle(i / 1000);
      expect(current, greaterThan(angle));
      angle = current;
    }
    // The actual speed at midpoint is much lower than at the start/end.
    final fast = RecapSpin.angle(.01) - RecapSpin.angle(0);
    final slow = RecapSpin.angle(.51) - RecapSpin.angle(.5);
    expect(fast, greaterThan(slow * 10));
  });

  test('fixtures test both sides of last scheduled lesson', () {
    final now = DateTime(2026, 10, 13, 17);
    expect(RecapFixtures.build(RecapScenario.beforeEnd, now).finished, isFalse);
    expect(RecapFixtures.build(RecapScenario.afterEnd, now).finished, isTrue);
    expect(RecapFixtures.build(RecapScenario.empty, now).days, 0);
    expect(RecapFixtures.build(RecapScenario.afterEnd, now).subjects, 6);
  });

  test('attendance unknown cannot imply perfect attendance', () {
    final now = DateTime(2026, 10, 13);
    final unknown = RecapFixtures.build(RecapScenario.missingAttendance, now);
    expect(unknown.absence, isNull);
    expect(unknown.attendanceConfirmed, isFalse);
    final liveZero = RecapFacts.calculate(
      ImportedScheduleData(
        displayName: 'Test', syncedAt: now,
        records: [ScheduleRecord(
          id: 'session-1', isExam: false, subjectName: 'Cơ sở dữ liệu',
          room: 'A', startAt: now, endAt: now.add(const Duration(hours: 2)),
        )],
      ),
      attendance: const {
        'cơ sở dữ liệu': AttendanceSummary(absentSessions: 0, totalTheorySessions: 1),
      },
      now: now,
    );
    expect(liveZero.absence, 0);
    expect(liveZero.attendanceConfirmed, isFalse);
    expect(liveZero.unknownPeriods, 1);
  });

  test('ATBM and PTTKPM remain separate; attendance never attributed cross-course', () {
    final now = DateTime(2026, 10, 13);
    ScheduleRecord record(String id, String course, int hour) =>
        ScheduleRecord(id: id, isExam: false, subjectName: course,
          room: 'A', startAt: DateTime(2026, 10, 2, hour),
          endAt: DateTime(2026, 10, 2, hour + 1));
    final data = ImportedScheduleData(
      displayName: 'Sinh viên', syncedAt: now,
      records: [
        record('a', 'An toàn bảo mật thông tin', 7),
        record('a', 'An toàn bảo mật thông tin', 7), // duplicate
        record('p1', 'Phân tích và thiết kế phần mềm', 7),
        record('p2', 'Phân tích và thiết kế phần mềm', 9),
        record('p3', 'Phân tích và thiết kế phần mềm', 13),
      ],
    );
    const absences = {
      'an toàn bảo mật thông tin':
          AttendanceSummary(absentSessions: 1, totalTheorySessions: 3),
      'phân tích và thiết kế phần mềm':
          AttendanceSummary(absentSessions: 2, totalTheorySessions: 4),
    };
    final result = RecapFacts.calculate(data, attendance: absences, now: now);
    expect(result.subjectCounts, hasLength(2));
    expect(result.subjectCounts.map((r) => r.scheduleCount), [3, 1]);
    expect(result.subjectCounts.first.name, 'Phân tích và thiết kế phần mềm');
    expect(result.subjectCounts.first.absentSessions, 2);
    expect(result.subjectCounts.last.absentSessions, 1);
    expect(result.absence, 3); // total across subjects, not PTTKPM's absences
    expect(result.mostAbsentCount, 2); // displayed as subject-specific
    expect(result.morning, 3);
    expect(result.afternoon, 1);
    expect(result.mostFrequentSubjects, ['Phân tích và thiết kế phần mềm']);
  });

  test('two courses with same verified count result in explicit tie', () {
    final now = DateTime(2026, 10, 13);
    final result = RecapFacts.calculate(
      ImportedScheduleData(displayName: 'Sinh viên', syncedAt: now, records: [
        ScheduleRecord(id: 'a', isExam: false, subjectName: 'ATBM',
          room: 'A', startAt: now, endAt: now.add(const Duration(hours: 1))),
        ScheduleRecord(id: 'b', isExam: false, subjectName: 'PTTKPM',
          room: 'A', startAt: now, endAt: now.add(const Duration(hours: 1))),
      ]), attendance: const {}, now: now,
    );
    expect(result.mostFrequentSubjects, ['ATBM', 'PTTKPM']);
    expect(result.favorite, contains('2 môn'));
    expect(result.absence, isNull);
  });

  test('confirmed perfect, a few absences, many absences remain distinct', () {
    final now = DateTime(2026, 10, 13);
    final perfect = RecapFixtures.build(RecapScenario.perfect, now);
    final some = RecapFixtures.build(RecapScenario.someMissed, now);
    final many = RecapFixtures.build(RecapScenario.manyMissed, now);
    expect(perfect.absence, 0);
    expect(perfect.attendanceConfirmed, isTrue);
    expect(some.absence, greaterThan(0));
    expect(many.absence, greaterThan(some.absence!));
    expect(perfect.early, greaterThan(0));
    expect(perfect.periods, greaterThan(0));
  });
}
