import 'package:better_phenikaa_schedule/features/lich_hoc/study_alarm_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default alarm picks previous whole hour', () {
    expect(studyAlarmDefaultHour(DateTime(2026, 10, 10, 9, 30)), 9);
    expect(studyAlarmDefaultHour(DateTime(2026, 10, 10, 13)), 12);
    expect(studyAlarmDefaultHour(DateTime(2026, 10, 10, 0)), 23);
    expect(studyAlarmDefaultHour(DateTime(2026, 10, 10, 23, 59)), 23);
  });
}
