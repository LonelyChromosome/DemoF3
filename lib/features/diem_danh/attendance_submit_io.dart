import 'dart:convert';
import 'dart:io';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_native_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sessionKey = 'better_phenikaa_qldt_native_session_v1';
/// Read the selected day's existing QLDT record, never the whole semester.
Future<ScheduleRecord> resolveAttendanceLesson(ScheduleRecord lesson) async {
  if (lesson.isExam) throw StateError('ATTENDANCE_LESSON_NOT_FOUND');
  final session = await _readAttendanceSession();
  final raw = await const QldtNativeTransport().fetchScheduleEnvelope(
    session: session,
    start: DateTime(lesson.startAt.year, lesson.startAt.month, lesson.startAt.day),
    end: DateTime(lesson.startAt.year, lesson.startAt.month, lesson.startAt.day),
  );
  final snapshot = const QldtParser().parseLiveEnvelope(raw);
  // Match course, date, session time, and room/class before taking the ID.
  final matches = snapshot.classes.where((row) =>
      row.subjectName == lesson.subjectName &&
      row.startAt == lesson.startAt &&
      row.endAt == lesson.endAt &&
      (lesson.room.isEmpty || row.room == lesson.room) &&
      (lesson.className.isEmpty || row.className == lesson.className)
  ).toList(growable: false);
  if (matches.isEmpty) throw StateError('ATTENDANCE_LESSON_NOT_FOUND');
  if (matches.length != 1) throw StateError('ATTENDANCE_LESSON_AMBIGUOUS');
  final chosen = matches.single;
  if (chosen.attendanceListId.trim().isEmpty) {
    throw StateError('ATTENDANCE_LIST_ID_MISSING');
  }
  // This context is local to this code sheet; do not alter the stored
  // timetable, login state, widgets, or semester-difference calculation.
  return ScheduleRecord(
    id: lesson.id,
    isExam: lesson.isExam,
    subjectName: lesson.subjectName,
    room: lesson.room,
    startAt: lesson.startAt,
    endAt: lesson.endAt,
    className: lesson.className,
    examForm: lesson.examForm,
    periodStart: lesson.periodStart,
    periodEnd: lesson.periodEnd,
    attendanceListId: chosen.attendanceListId,
    attendanceReview: chosen.attendanceReview,
  );
}

Future<QldtNativeSession> _readAttendanceSession() async {
  final prefs = await SharedPreferences.getInstance();
  final rawSession = prefs.getString(_sessionKey);
  if (rawSession == null || rawSession.isEmpty) {
    throw StateError('SESSION_EXPIRED');
  }
  final session = QldtNativeSession.fromJson(
    Map<String, dynamic>.from(jsonDecode(rawSession) as Map),
  );
  if (!session.isValid) throw StateError('SESSION_EXPIRED');
  return session;
}

const _endpoint = 'https://qldtbeta.phenikaa-uni.edu.vn/chuyencanapi/api/'
    'CC_ThongTin/Them_QLSV_NguoiHoc_TuGhiNhan';

Future<void> submitAttendanceCode(ScheduleRecord lesson, String code) async {
  final listId = lesson.attendanceListId.trim();
  if (listId.isEmpty) {
    throw StateError('ATTENDANCE_LIST_ID_MISSING');
  }
  if (code.trim().isEmpty) {
    throw const FormatException('Hãy nhập code điểm danh.');
  }

  final session = await _readAttendanceSession();
  // Submission timestamp reflects the student's actual button press,
  // not the scheduled start of the class.
  final started = DateTime.now();
  final form = <String, String>{
    'action': 'CC_ThongTin/Them_QLSV_NguoiHoc_TuGhiNhan',
    'type': 'POST',
    'strChucNang_Id': session.functionId,
    'strDaoTao_LopQuanLy_Id': '',
    'strDiem_DanhSach_Id': listId,
    'strNgayGhiNhan':
        '${started.day.toString().padLeft(2, '0')}/'
        '${started.month.toString().padLeft(2, '0')}/${started.year}',
    'strGio': '${started.hour}',
    'strPhut': '${started.minute}',
    'strGiay': '0',
    // QLDT must determine the connecting client IP; never spoof a log IP.
    'strIp': '',
    'strNoiDungTuGhiNhan': code.trim(),
    'strNguoiThucHien_Id': session.userId,
    'strQLSV_NguoiHoc_Id': session.userId,
    'strDaoTao_ChuongTrinh_Id': '',
    'strQLSV_TrangThaiNguoiHoc_Id': '',
    'strVaiTroDangNhap_Id': session.appId,
    'strChucNangHeThong_Id': session.functionId,
  };

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client
        .postUrl(Uri.parse(_endpoint))
        .timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.authorizationHeader,
        'Bearer ${session.tokenJwt}');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded; charset=UTF-8');
    if (session.cookie.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, session.cookie);
    }
    request.write(Uri(queryParameters: form).query);
    final response = await request.close().timeout(const Duration(seconds: 8));
    final content = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('QLĐT trả HTTP ${response.statusCode}');
    }
    final result = jsonDecode(content) as Map<String, dynamic>;
    if (result['Success'] != true) {
      final message = (result['Message'] ?? '').toString().trim();
      throw StateError(message.isNotEmpty ? message : 'SUBMISSION_REJECTED');
    }
    // Success means submitted, NOT present/absent, and Id may be blank.
  } finally {
    client.close(force: true);
  }
}
