import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';

final class VerifiedSemesterSchedules {
  const new({required this.studySchedules, required this.examSchedules});

  final List<ScheduleRecord> studySchedules;
  final List<ScheduleRecord> examSchedules;
}

final class SemesterScheduleVerifier {
  const new();

  VerifiedSemesterSchedules verify({
    required RegisteredSemester registration,
    required ImportedScheduleData schedule,
  }) {
    final classes = <String, Map<String, RegisteredClassSection>>{};
    for (final name in registration.subjectNames) {
      final normalized = normalizeSubjectName(name);
      final sections =
          registration.classSections[name] ?? const <RegisteredClassSection>[];
      if (classes.containsKey(normalized)) {
        throw FormatException('Trùng môn đăng ký: $name');
      }
      classes[normalized] = {
        for (final section in sections)
          normalizeSubjectName(section.name): section,
      };
    }
    if (classes.isEmpty &&
        (!registration.confirmedEmpty || schedule.records.isNotEmpty)) {
      throw const FormatException(
        'Chưa xác minh được môn của học kỳ mới nhất.',
      );
    }

    final study = <ScheduleRecord>[];
    final exams = <ScheduleRecord>[];
    for (final row in schedule.records) {
      final subject = classes[normalizeSubjectName(row.subjectName)];
      if (subject == null) continue;
      final className = normalizeSubjectName(row.className);
      if (className.isEmpty || !subject.containsKey(className)) {
        throw FormatException(
          'Không xác minh được lớp của lịch: ${row.subjectName}',
        );
      }
      if (row.isExam) {
        exams.add(row);
        continue;
      }
      final section = subject[className]!;
      final date = DateTime(
        row.startAt.year,
        row.startAt.month,
        row.startAt.day,
      );
      if (date.isBefore(section.startsOn) || date.isAfter(section.endsOn)) {
        throw FormatException(
          'Buổi học ngoài khoảng ngày lớp: ${row.subjectName}',
        );
      }
      study.add(row);
    }
    return VerifiedSemesterSchedules(
      studySchedules: study,
      examSchedules: exams,
    );
  }
}
