import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'attendance_submit_stub.dart'
    if (dart.library.io) 'attendance_submit_io.dart' as platform;

/// Only submits a code. Approval is performed separately by QLDT/lecturers.
Future<void> submitAttendanceCode(ScheduleRecord lesson, String code) =>
    platform.submitAttendanceCode(lesson, code);
