import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'attendance_submit_stub.dart'
    if (dart.library.io) 'attendance_submit_io.dart' as platform;

/// Read the exact lesson using the same live session as the working QLDT sync.
Future<ScheduleRecord> resolveAttendanceLesson(
  ScheduleRecord lesson, {
  required Map<String, String> liveSession,
}) => platform.resolveAttendanceLesson(lesson, liveSession: liveSession);

/// Only sends the code the student explicitly submitted.
Future<void> submitAttendanceCode(
  ScheduleRecord lesson,
  String code, {
  required Map<String, String> liveSession,
}) => platform.submitAttendanceCode(lesson, code, liveSession: liveSession);
