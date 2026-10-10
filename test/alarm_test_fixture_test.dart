import 'package:better_phenikaa_schedule/features/lich_hoc/alarm_test_fixture.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/study_alarm_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake classes only belong to tomorrow and follow the eligibility gate', () {
    final now = DateTime(2026, 10, 10, 21, 30);
    final data = withAlarmTestFixture(null, now);
    expect(data.classes.length, 3);
    expect(data.classes.every((c) => c.subjectName.contains('[TEST 1.6]')), isTrue);
    expect(data.classes.every((c) => studyAlarmIsTomorrow(c.startAt, now)), isTrue);
    expect(studyAlarmCanOpen(data.records[0].startAt, now), isTrue);
    expect(studyAlarmCanOpen(data.records[1].startAt, now), isTrue);
    expect(studyAlarmCanOpen(data.records[2].startAt, now), isFalse);
  });

  test('fixture advances when the day changes', () {
    final data = withAlarmTestFixture(null, DateTime(2026, 12, 31, 23));
    expect(data.records.first.startAt, DateTime(2027, 1, 1, 9, 30));
    final next = withAlarmTestFixture(null, DateTime(2027, 1, 1, 0));
    expect(next.records.first.startAt, DateTime(2027, 1, 2, 9, 30));
  });
}
