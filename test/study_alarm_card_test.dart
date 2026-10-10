import 'package:better_phenikaa_schedule/features/lich_hoc/study_alarm_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clock action only appears for classes tomorrow', () {
    final now = DateTime(2026, 10, 10, 19, 15);
    expect(studyAlarmIsTomorrow(DateTime(2026, 10, 9, 9), now), isFalse);
    expect(studyAlarmIsTomorrow(DateTime(2026, 10, 10, 21), now), isFalse);
    expect(studyAlarmIsTomorrow(DateTime(2026, 10, 11, 9), now), isTrue);
    expect(studyAlarmIsTomorrow(DateTime(2026, 10, 12, 9), now), isFalse);
  });

  test('tomorrow rolls over month and year boundaries', () {
    expect(
      studyAlarmIsTomorrow(DateTime(2027, 1, 1, 10), DateTime(2026, 12, 31, 22)),
      isTrue,
    );
    expect(
      studyAlarmIsTomorrow(DateTime(2026, 3, 1, 10), DateTime(2026, 2, 28, 22)),
      isTrue,
    );
  });

  test('clock request never silently schedules an earlier day', () {
    final tomorrowClass = DateTime(2026, 10, 11, 9, 30);
    expect(studyAlarmValidation(tomorrowClass, DateTime(2026, 10, 10, 19), 9, 0), isNull);
    // At 07:00 today, a standard nonrepeating AlarmClock intent for 09:00
    // would create an alarm for TODAY, not tomorrow: reject it.
    expect(
      studyAlarmValidation(tomorrowClass, DateTime(2026, 10, 10, 7), 9, 0),
      contains('hôm nay'),
    );
  });

  test('only earlier-than-class hours and minutes are valid', () {
    final study = DateTime(2026, 10, 11, 9, 30);
    final now = DateTime(2026, 10, 10, 19);
    expect(studyAlarmValidation(study, now, 10, 0), contains('trước giờ học'));
    expect(studyAlarmValidation(study, now, 9, 30), contains('trước giờ học'));
    expect(studyAlarmValidation(study, now, 9, 29), isNull);
    expect(
      studyAlarmOccurrence(study, 9, 0), DateTime(2026, 10, 11, 9),
    );
  });

  test('correctly handles early tomorrow classes', () {
    final now = DateTime(2026, 10, 10, 19);
    final earlyClass = DateTime(2026, 10, 11, 0, 30);
    expect(studyAlarmValidation(earlyClass, now, 0, 0), isNull);
    expect(studyAlarmValidation(earlyClass, now, 23, 0), contains('trước giờ học'));
  });

  test('default picker is previous whole hour where possible', () {
    expect(studyAlarmDefaultHour(DateTime(2026, 10, 11, 9, 30)), 9);
    expect(studyAlarmDefaultHour(DateTime(2026, 10, 11, 13)), 12);
  });
}
