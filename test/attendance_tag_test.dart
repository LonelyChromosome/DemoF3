import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/attendance_tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> row(
    int index, {
    String subject = 'An toàn và bảo mật thông tin',
    String type = 'Ly thuyet',
    String? status,
    int periods = 3,
  }) => {
    'ID': '$subject-$type-$index',
    'PHANLOAI': 'LICHHOC',
    'TENHOCPHAN': subject,
    'THUOCTINH_TEN': type,
    'SOTIET': periods,
    'THONGTINCHUYENCAN': status,
  };

  String envelope(List<Map<String, Object?>> rows) => jsonEncode({
    'response': {'Success': true, 'Data': rows},
  });

  test('only actual LT absences count; practice and e-learning never count', () {
    final rows = [
      for (var i = 0; i < 10; i++)
        row(i, status: i < 2 ? 'Vắng mặt(3)' : 'Có mặt(3)'),
      row(11, type: 'Thuc hanh', status: 'Vắng mặt(3)'),
      row(12, type: 'Elearning', status: 'Vắng mặt(3)'),
    ];
    final totals = AttendanceSummary.fromRawEnvelope(envelope(rows));
    final summary = totals[normalizeSubjectName('An toàn và bảo mật thông tin')]!;
    expect(summary.theoryPeriods, 30);
    expect(summary.absentPeriods, 6);
    expect(summary.absentSessions, 2);
    expect(summary.allowanceSessions, 2);
    expect(summary.exceeded, false);
  });

  test('duplicate rows are not double counted', () {
    final rows = [
      for (var i = 0; i < 5; i++) row(i, status: 'Vắng mặt(3)'),
      row(0, status: 'Vắng mặt(3)'),
    ];
    final summary = AttendanceSummary.fromRawEnvelope(envelope(rows)).values.single;
    expect(summary.theoryPeriods, 15);
    expect(summary.absentSessions, 5);
    expect(summary.allowanceSessions, 1);
    expect(summary.exceeded, true);
  });

  test('pure e-learning does not show a tag', () {
    final summaries = AttendanceSummary.fromRawEnvelope(envelope([
      for (var i = 0; i < 10; i++)
        row(i, subject: 'Lịch sử Đảng', type: 'Elearning'),
    ]));
    expect(summaries, isEmpty);
  });

  test('invalid data never throws or invents a zero', () {
    expect(AttendanceSummary.fromRawEnvelope('broken'), isEmpty);
    expect(AttendanceSummary.fromRawEnvelope('{"response":{"Success":false}}'), isEmpty);
    expect(AttendanceSummary.fromJson({'absentPeriods': -1, 'theoryPeriods': 30}), isNull);
  });
}
