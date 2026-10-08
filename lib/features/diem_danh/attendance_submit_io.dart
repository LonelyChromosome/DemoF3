import 'dart:convert';
import 'dart:io';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_native_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sessionKey = 'better_phenikaa_qldt_native_session_v1';
const _endpoint = 'https://qldtbeta.phenikaa-uni.edu.vn/chuyencanapi/api/'
    'CC_ThongTin/Them_QLSV_NguoiHoc_TuGhiNhan';

Future<void> submitAttendanceCode(ScheduleRecord lesson, String code) async {
  final listId = lesson.attendanceListId.trim();
  if (listId.isEmpty) {
    throw StateError(
      'Chưa có mã danh sách điểm danh của buổi học từ QLĐT. '
      'Không thể gửi code cho sai môn.',
    );
  }
  if (code.trim().isEmpty) {
    throw const FormatException('Hãy nhập code điểm danh.');
  }

  final prefs = await SharedPreferences.getInstance();
  final rawSession = prefs.getString(_sessionKey);
  if (rawSession == null || rawSession.isEmpty) {
    throw StateError('Phiên QLĐT không còn khả dụng. Cần đăng nhập lại.');
  }
  final session = QldtNativeSession.fromJson(
    Map<String, dynamic>.from(jsonDecode(rawSession) as Map),
  );
  if (!session.isValid) {
    throw StateError('Phiên QLĐT đã thiếu thông tin xác thực.');
  }

  final started = lesson.startAt;
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
      throw StateError(
        (result['Message'] ?? 'QLĐT chưa tiếp nhận code').toString(),
      );
    }
    // Success means submitted, NOT present/absent, and Id may be blank.
  } finally {
    client.close(force: true);
  }
}
