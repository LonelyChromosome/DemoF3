import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';

final class ScheduleDifference {
  const new({
    required this.added,
    required this.removed,
    required this.modified,
  });

  final int added;
  final int removed;
  final int modified;

  bool get hasChanges => added + removed + modified > 0;
}

final class SemesterDifference {
  const new({
    required this.initial,
    required this.addedSubjects,
    required this.removedSubjects,
    required this.study,
    required this.exams,
  });

  final bool initial;
  final List<String> addedSubjects;
  final List<String> removedSubjects;
  final ScheduleDifference study;
  final ScheduleDifference exams;

  bool get hasChanges =>
      !initial &&
      (addedSubjects.isNotEmpty ||
          removedSubjects.isNotEmpty ||
          study.hasChanges ||
          exams.hasChanges);
}

final class SemesterChangeDetector {
  const new();

  SemesterDifference compare(CurrentSemester? previous, CurrentSemester next) {
    if (previous == null) {
      return const SemesterDifference(
        initial: true,
        addedSubjects: <String>[],
        removedSubjects: <String>[],
        study: ScheduleDifference(added: 0, removed: 0, modified: 0),
        exams: ScheduleDifference(added: 0, removed: 0, modified: 0),
      );
    }

    final oldSubjects = {
      for (final item in previous.subjects) item.subjectId: item,
    };
    final newSubjects = {
      for (final item in next.subjects) item.subjectId: item,
    };
    final sharedIds = oldSubjects.keys.toSet().intersection(
      newSubjects.keys.toSet(),
    );
    final oldStudy = <ScheduleRecord>[];
    final newStudy = <ScheduleRecord>[];
    final oldExams = <ScheduleRecord>[];
    final newExams = <ScheduleRecord>[];
    for (final id in sharedIds) {
      oldStudy.addAll(oldSubjects[id]!.studySchedules);
      newStudy.addAll(newSubjects[id]!.studySchedules);
      oldExams.addAll(oldSubjects[id]!.examSchedules);
      newExams.addAll(newSubjects[id]!.examSchedules);
    }
    final study = _compareRows(oldStudy, newStudy);
    final exams = _compareRows(oldExams, newExams);
    return SemesterDifference(
      initial: false,
      addedSubjects: next.subjects
          .where((item) => !oldSubjects.containsKey(item.subjectId))
          .map((item) => item.name)
          .toList(),
      removedSubjects: previous.subjects
          .where((item) => !newSubjects.containsKey(item.subjectId))
          .map((item) => item.name)
          .toList(),
      study: ScheduleDifference(
        added:
            study.added +
            next.subjects
                .where((item) => !oldSubjects.containsKey(item.subjectId))
                .fold<int>(0, (sum, item) => sum + item.studySchedules.length),
        removed:
            study.removed +
            previous.subjects
                .where((item) => !newSubjects.containsKey(item.subjectId))
                .fold<int>(0, (sum, item) => sum + item.studySchedules.length),
        modified: study.modified,
      ),
      exams: ScheduleDifference(
        added:
            exams.added +
            next.subjects
                .where((item) => !oldSubjects.containsKey(item.subjectId))
                .fold<int>(0, (sum, item) => sum + item.examSchedules.length),
        removed:
            exams.removed +
            previous.subjects
                .where((item) => !newSubjects.containsKey(item.subjectId))
                .fold<int>(0, (sum, item) => sum + item.examSchedules.length),
        modified: exams.modified,
      ),
    );
  }

  ScheduleDifference _compareRows(
    List<ScheduleRecord> old,
    List<ScheduleRecord> next,
  ) {
    final remaining = [...next];
    final unmatched = <ScheduleRecord>[];
    for (final row in old) {
      final match = remaining.indexWhere((item) => _sameContent(row, item));
      if (match < 0) {
        unmatched.add(row);
      } else {
        remaining.removeAt(match);
      }
    }
    var modified = 0;
    for (final row in unmatched.toList()) {
      final sameDay = remaining.indexWhere(
        (item) =>
            _name(item.subjectName) == _name(row.subjectName) &&
            _day(item.startAt) == _day(row.startAt),
      );
      final match = sameDay >= 0
          ? sameDay
          : remaining.length == 1 &&
                unmatched.length == 1 &&
                _name(remaining.first.subjectName) == _name(row.subjectName)
          ? 0
          : -1;
      if (match >= 0) {
        modified++;
        remaining.removeAt(match);
        unmatched.remove(row);
      }
    }
    return ScheduleDifference(
      added: remaining.length,
      removed: unmatched.length,
      modified: modified,
    );
  }

  bool _sameContent(ScheduleRecord a, ScheduleRecord b) =>
      _name(a.subjectName) == _name(b.subjectName) &&
      _name(a.className) == _name(b.className) &&
      _name(a.room) == _name(b.room) &&
      _name(a.examForm) == _name(b.examForm) &&
      a.startAt == b.startAt &&
      a.endAt == b.endAt &&
      a.periodStart == b.periodStart &&
      a.periodEnd == b.periodEnd;

  String _name(String value) => normalizeSubjectName(value);

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}
