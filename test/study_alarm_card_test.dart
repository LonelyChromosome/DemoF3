import 'package:better_phenikaa_schedule/features/lich_hoc/study_alarm_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only tomorrow classes can show alarm button from today class time', () {
    final classStart = DateTime(2026, 10, 11, 9, 30);
    expect(studyAlarmCanOpen(classStart, DateTime(2026, 10, 10, 7)), isFalse);
    expect(studyAlarmCanOpen(classStart, DateTime(2026, 10, 10, 9, 29)), isFalse);
    expect(studyAlarmCanOpen(classStart, DateTime(2026, 10, 10, 9, 30)), isTrue);
    expect(studyAlarmCanOpen(classStart, DateTime(2026, 10, 10, 22)), isTrue);
    expect(studyAlarmCanOpen(classStart, DateTime(2026, 10, 11, 9, 30)), isFalse);
    expect(studyAlarmCanOpen(DateTime(2026, 10, 12, 9, 30), DateTime(2026, 10, 10, 22)), isFalse);
  });

  test('picker starts exactly at class time and requires scrolling back', () {
    final s = DateTime(2026, 10, 11, 9, 30);
    expect(studyAlarmDefaultHour(s), 9);
    expect(studyAlarmDefaultMinute(s), 30);
    final now = DateTime(2026, 10, 10, 19);
    expect(studyAlarmValidation(s, now, 9, 30), contains('trước giờ học'));
    expect(studyAlarmValidation(s, now, 9, 29), isNull);
    expect(studyAlarmValidation(s, now, 8, 59), isNull);
    expect(studyAlarmValidation(s, now, 10, 0), contains('trước giờ học'));
    expect(studyAlarmOccurrence(s, 9, 29), DateTime(2026, 10, 11, 9, 29));
  });

  test('date rules work across year/month boundaries', () {
    final s = DateTime(2027, 1, 1, 9, 30);
    expect(studyAlarmCanOpen(s, DateTime(2026, 12, 31, 10)), isTrue);
    expect(studyAlarmValidation(s, DateTime(2026, 12, 31, 10), 9, 29), isNull);
  });

  test('midnight class cannot be alarmed strictly before start on same day', () {
    final s = DateTime(2026, 10, 11, 0, 0);
    expect(studyAlarmCanOpen(s, DateTime(2026, 10, 10, 18)), isFalse);
  });
}
