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
