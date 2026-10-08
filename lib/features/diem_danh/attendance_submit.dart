import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'attendance_submit_stub.dart'
    if (dart.library.io) 'attendance_submit_io.dart' as platform;

/// Lookup happens ONLY when a user opens the attendance code sheet, never in
/// the initial login, background widget sync, or timetable verification.
Future<ScheduleRecord> resolveAttendanceLesson(ScheduleRecord lesson) =>
    platform.resolveAttendanceLesson(lesson);

/// Only submits a code. Approval is performed separately by QLDT/lecturers.
Future<void> submitAttendanceCode(ScheduleRecord lesson, String code) =>
    platform.submitAttendanceCode(lesson, code);
