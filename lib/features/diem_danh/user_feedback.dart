/// Short user-facing QLDT error messages. Never show raw tokens, IDs or HTML.
String attendanceFailureMessage(Object error) {
  final raw = error.toString().toLowerCase();
  if (_matches(raw, <String>[
    'quá hạn', 'qua han', 'hết hạn nhập', 'het han nhap',
    'hết thời gian', 'het thoi gian', 'đã đóng', 'da dong',
  ])) {
    return 'Quá hạn nhập mã điểm danh.';
  }
  if (_matches(raw, <String>[
    'chưa mở', 'chua mo', 'chưa bắt đầu', 'chua bat dau',
    'chưa đến giờ', 'chua den gio',
  ])) {
    return 'Giảng viên chưa mở điểm danh.';
  }
  if (_matches(raw, <String>['attendance_lesson_not_found'])) {
    return 'Không tìm thấy buổi này trên QLĐT.';
  }
  if (_matches(raw, <String>['attendance_lesson_ambiguous'])) {
    return 'Không xác định được buổi điểm danh.';
  }
  if (_matches(raw, <String>[
    'attendance_list_id_missing', 'chưa có mã danh sách',
    'chưa có mã điểm danh',
  ])) {
    return 'Chưa có thông tin điểm danh của buổi này.';
  }
  if (_matches(raw, <String>[
    '401', '403', 'unauthorized', 'session_expired',
    'phiên qlđt', 'phiên qldt', 'tokenjwt', 'đăng nhập lại',
  ])) {
    return 'Phiên QLĐT hết hạn. Hãy đăng nhập lại.';
  }
  if (_matches(raw, <String>[
    'socketexception', 'failed host lookup', 'network is unreachable',
    'connection refused', 'no route to host',
  ])) {
    return 'Mất kết nối QLĐT. Kiểm tra mạng.';
  }
  if (_matches(raw, <String>[
    '503', '502', '504', 'quá tải', 'qua tai',
  ])) {
    return 'QLĐT đang bận. Thử lại sau.';
  }
  if (raw.contains('timeout')) {
    return 'QLĐT phản hồi quá lâu. Thử lại.';
  }
  if (_matches(raw, <String>['hãy nhập code', 'hay nhap code'])) {
    return 'Hãy nhập mã điểm danh.';
  }
  // QLDT can reject a request without telling us whether the code is correct.
  return 'Chưa lưu được mã. Hãy thử lại.';
}

String refreshFailureMessage(Object error, {required String stage}) {
  final raw = error.toString().toLowerCase();
  if (stage == 'save') {
    return 'Chưa lưu được lịch mới. Lịch cũ được giữ.';
  }
  if (_matches(raw, <String>['session_expired', 'phiên qlđt', 'phiên qldt',
      'đăng nhập lại', '401', '403', 'unauthorized'])) {
    return 'Phiên QLĐT hết hạn. Hãy đăng nhập lại.';
  }
  if (_matches(raw, <String>['plan_ambiguous', 'kế hoạch', 'ke hoach'])) {
    return 'Chưa xác định được học kỳ từ QLĐT.';
  }
  if (_matches(raw, <String>['no_subjects', 'chưa có lịch học kỳ'])) {
    return 'QLĐT chưa có lịch học kỳ để làm mới.';
  }
  if (_matches(raw, <String>['socketexception', 'failed host lookup',
      'network is unreachable', 'connection refused'])) {
    return 'Mất mạng khi làm mới. Lịch cũ được giữ.';
  }
  if (_matches(raw, <String>['503', '502', '504'])) {
    return 'QLĐT đang bận. Thử lại sau.';
  }
  if (raw.contains('timeout')) {
    return 'QLĐT phản hồi quá lâu. Thử lại.';
  }
  if (_matches(raw, <String>['format', 'không hợp lệ', 'xác minh'])) {
    return 'Dữ liệu QLĐT chưa hợp lệ. Giữ lịch cũ.';
  }
  return 'Chưa tải được dữ liệu QLĐT. Thử lại.';
}

bool _matches(String raw, List<String> patterns) =>
    patterns.any(raw.contains);
