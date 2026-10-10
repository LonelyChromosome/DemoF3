import 'package:better_phenikaa_schedule/features/lich_hoc/study_alarm_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alarm never silently uses tomorrow for a later class', () {
    final now = DateTime(2026, 10, 10, 19);
    final study = DateTime(2026, 10, 12, 9, 30);
    expect(studyAlarmValidation(study, now, 9, 0), contains('đúng ngày'));
  });

  test('rejects past classes and past selected alarm hours', () {
    final now = DateTime(2026, 10, 10, 9, 15);
    expect(studyAlarmValidation(DateTime(2026, 10, 9, 9), now, 8, 0), 'Môn đã qua');
    expect(studyAlarmValidation(DateTime(2026, 10, 10, 10), now, 9, 0), 'Giờ báo thức đã qua');
  });

  test('allows time that Android Clock can schedule for the correct day', () {
    final now = DateTime(2026, 10, 10, 18);
    final study = DateTime(2026, 10, 11, 9, 30);
    expect(studyAlarmValidation(study, now, 9, 0), isNull);
    expect(studyAlarmOccurrence(study, 9, 0), DateTime(2026, 10, 11, 9));
  });

  test('night-before alarms for early classes resolve to previous day', () {
    final study = DateTime(2026, 10, 11, 0, 30);
    expect(studyAlarmOccurrence(study, 23, 0), DateTime(2026, 10, 10, 23));
  });

  test('default alarm picks previous whole hour', () {
    expect(studyAlarmDefaultHour(DateTime(2026, 10, 10, 9, 30)), 9);
    expect(studyAlarmDefaultHour(DateTime(2026, 10, 10, 13)), 12);
    expect(studyAlarmDefaultHour(DateTime(2026, 10, 10, 0)), 23);
    expect(studyAlarmDefaultHour(DateTime(2026, 10, 10, 23, 59)), 23);
  });
}
