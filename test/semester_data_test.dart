import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  ScheduleRecord row(String name, {bool isExam = false, String room = 'A1'}) =>
      ScheduleRecord(
        id: '$name|$room',
        isExam: isExam,
        subjectName: name,
        room: room,
        startAt: DateTime(2026, 9, 24, 7),
        endAt: DateTime(2026, 9, 24, 9),
      );

  const registration = RegisteredSemester(
    id: 'semester-2026-1',
    name: 'Học kỳ 1',
    subjectNames: <String>['Lập trình C++', 'Toán cao cấp'],
  );
  const builder = SemesterDataBuilder();

  test(
    'matches Vietnamese composed and decomposed names without losing accents',
    () {
      expect(
        normalizeSubjectName('  LẬP  TRÌNH  C++ '),
      normalizeSubjectName('La\u0302\u0323p tri\u0300nh c++'),
      );
      expect(normalizeSubjectName('Ma'), isNot(normalizeSubjectName('Má')));
    },
  );

  test('keeps subject ID when a room changes, and adapts both schedules', () {
    final first = builder.build(
      registration: registration,
      studySchedules: <ScheduleRecord>[row('Lập trình C++')],
      examSchedules: <ScheduleRecord>[row('Toán cao cấp', isExam: true)],
      displayName: 'Sinh viên',
      syncedAt: DateTime(2026, 9, 23),
    );
    final next = builder.build(
      registration: registration,
      studySchedules: <ScheduleRecord>[row('Lập trình C++', room: 'B2')],
      examSchedules: <ScheduleRecord>[row('Toán cao cấp', isExam: true)],
      displayName: 'Sinh viên',
      syncedAt: DateTime(2026, 9, 24),
      previous: first,
    );

    expect(next.subjects.first.id, first.subjects.first.id);
    expect(next.subjects.first.studySchedules.single.room, 'B2');
    expect(next.toImportedScheduleData().classes.single.room, 'B2');
    expect(
      next.toImportedScheduleData().exams.single.subjectName,
      'Toán cao cấp',
    );
    expect(
      next.toImportedScheduleData().records.map((item) => item.id).toSet(),
      hasLength(2),
    );
  });

  test(
    'rejects an unmatched schedule before building a replacement snapshot',
    () {
      expect(
        () => builder.build(
          registration: registration,
          studySchedules: <ScheduleRecord>[row('Môn ngoài danh sách')],
          examSchedules: const <ScheduleRecord>[],
          displayName: 'Sinh viên',
          syncedAt: DateTime(2026, 9, 23),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'restores the semester with its subject identity after restarting',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = CurrentSemesterStore();
      final semester = builder.build(
        registration: registration,
        studySchedules: <ScheduleRecord>[row('Lập trình C++')],
        examSchedules: const <ScheduleRecord>[],
        displayName: 'Sinh viên',
        syncedAt: DateTime(2026, 9, 23),
      );
      await store.save(semester);
      final restored = await CurrentSemesterStore().read();
      expect(restored?.semesterId, registration.id);
      expect(restored?.subjects.first.id, semester.subjects.first.id);
      expect(restored?.subjects.first.studySchedules.single.room, 'A1');
    },
  );
}
