import '../dang_nhap_qldt/qldt_models.dart';

List<Map<String, dynamic>> vehicleScheduleWindows(Iterable<ScheduleRecord> classes) =>
    classes.where((r) => !r.isExam && r.lessonKind?.toUpperCase() != 'ELEARNING')
        .map((r) => <String, dynamic>{
          'name': r.subjectName, 'kind': r.lessonKind ?? '', 'room': r.room,
          'className': r.className, 'start': r.startAt.millisecondsSinceEpoch,
          'end': r.endAt.millisecondsSinceEpoch,
        }).toList(growable: false);
