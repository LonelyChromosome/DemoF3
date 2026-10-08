import 'package:better_phenikaa_schedule/features/diem_danh/user_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attendance deadlines are only inferred from explicit server errors', () {
    expect(
      attendanceFailureMessage(StateError('Quá hạn nhập từ khóa')),
      'Quá hạn nhập mã điểm danh.',
    );
    expect(
      attendanceFailureMessage(StateError('SUBMISSION_REJECTED')),
      'Chưa lưu được mã. Hãy thử lại.',
    );
  });

  test('attendance errors are concise and explain what to do', () {
    expect(
      attendanceFailureMessage(StateError('ATTENDANCE_LIST_ID_MISSING')),
      'Chưa có thông tin điểm danh của buổi này.',
    );
    expect(
      attendanceFailureMessage(StateError('QLĐT chưa mở điểm danh')),
      'Giảng viên chưa mở điểm danh.',
    );
    expect(
      attendanceFailureMessage(StateError('HTTP 503')),
      'QLĐT đang bận. Thử lại sau.',
    );
  });

  test('refresh explains session, transport, and local persistence errors', () {
    expect(
      refreshFailureMessage(StateError('Phiên QLĐT cần đăng nhập lại.'),
        stage: 'download'),
      'Phiên QLĐT hết hạn. Hãy đăng nhập lại.',
    );
    expect(
      refreshFailureMessage(StateError('HTTP 503'), stage: 'download'),
      'QLĐT đang bận. Thử lại sau.',
    );
    expect(
      refreshFailureMessage(StateError('disk failed'), stage: 'save'),
      'Chưa lưu được lịch mới. Lịch cũ được giữ.',
    );
  });
}
