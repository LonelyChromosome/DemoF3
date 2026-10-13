import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/attendance_tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> row(
    int index, {
    String subject = 'An toàn và bảo mật thông tin',
    String section = 'N05',
    String? status,
    String? attribute,
    int periods = 3,
    bool hasId = true,
  }) => <String, Object?>{
    if (hasId) 'ID': subject + '|' + section + '|' + index.toString(),
    'PHANLOAI': 'LICHHOC',
    'TENHOCPHAN': subject,
    'TENLOPHOCPHAN': section,
    if (attribute != null) 'THUOCTINH_TEN': attribute,
    'SOTIET': periods,
    'THONGTINCHUYENCAN': status,
    'NGAYHOC': (index % 28 + 1).toString() + '/09/2026',
    'GIOBATDAU': 7,
    'PHUTBATDAU': 0,
    'GIOKETTHUC': 9,
    'PHUTKETTHUC': 0,
    'PHONGHOC_TEN': 'A1',
  };

  String envelope(List<Map<String, Object?>> rows) => jsonEncode({
    'name': 'Sinh viên',
    'response': {'Success': true, 'Data': rows},
  });

  final atbm = normalizeSubjectName('An toàn và bảo mật thông tin');
  final ktpm = normalizeSubjectName('Kỹ thuật phần mềm');
  final pttk = normalizeSubjectName('Phân tích và thiết kế phần mềm');
  final web = normalizeSubjectName('Thiết kế web nâng cao');
  final mobile = normalizeSubjectName('Lập trình cho thiết bị di động');

  test('user registered-class baselines: KTPM1 PTTK4 Web3 Mobile3 ATBM2', () {
    final rows = <Map<String, Object?>>[
      for (var i = 0; i < 5; i++) row(i,
        subject: 'Môn Kỹ thuật phần mềm-1-1-26(COUR02.LT5)',
        section: 'Kỹ thuật phần mềm-1-1-26(COUR02.LT5)',
        status: i == 0 ? 'Vắng mặt(3)' : 'Có mặt(3)'),
      // Same module's online lessons NEVER count toward the LT allowance.
      for (var i = 0; i < 20; i++) row(i,
        subject: 'Môn Kỹ thuật phần mềm-1-1-26(COUR02).ELN',
        section: 'Kỹ thuật phần mềm-1-1-26(COUR02).ELN',
        status: 'Có mặt(3)'),
      for (var i = 0; i < 20; i++) row(i,
        subject: 'Phân tích và thiết kế phần mềm',
        section: 'Phân tích và thiết kế phần mềm-1-1-26(N08)',
        status: i == 0 ? 'Vắng mặt(3)' : 'Có mặt(3)'),
      for (var i = 0; i < 15; i++) row(i,
        subject: 'Thiết kế web nâng cao',
        section: 'Thiết kế web nâng cao-1-1-26(N07)',
        status: 'Có mặt(3)'),
      for (var i = 0; i < 15; i++) row(i,
        subject: 'Lập trình cho thiết bị di động',
        section: 'Lập trình cho thiết bị di động-1-1-26(N05)',
        status: 'Có mặt(3)'),
      for (var i = 0; i < 10; i++) row(i,
        section: 'An toàn và bảo mật thông tin-1-1-26(N05)',
        status: 'Có mặt(3)'),
      for (var i = 0; i < 12; i++) row(i,
        section: 'An toàn và bảo mật thông tin-1-1-26(N05.TH1)',
        status: 'Vắng mặt(3)'),
    ];
    final counts = AttendanceSummary.fromRawEnvelope(envelope(rows));
    expect(counts[ktpm]!.totalTheorySessions, 5);
    expect(counts[ktpm]!.absentSessions, 1);
    expect(counts[ktpm]!.allowanceSessions, 1);
    expect(counts[pttk]!.totalTheorySessions, 20);
    expect(counts[pttk]!.allowanceSessions, 4);
    expect(counts[web]!.totalTheorySessions, 15);
    expect(counts[web]!.allowanceSessions, 3);
    expect(counts[mobile]!.totalTheorySessions, 15);
    expect(counts[mobile]!.allowanceSessions, 3);
    expect(counts[atbm]!.totalTheorySessions, 10);
    expect(counts[atbm]!.allowanceSessions, 2);
    expect(counts[atbm]!.absentSessions, 0);
  });

  test('20 percent is rounded UP per distinct enrolled LT class session', () {
    expect(const AttendanceSummary(absentSessions: 0,
      totalTheorySessions: 4).allowanceSessions, 1);
    expect(const AttendanceSummary(absentSessions: 0,
      totalTheorySessions: 5).allowanceSessions, 1);
    expect(const AttendanceSummary(absentSessions: 0,
      totalTheorySessions: 10).allowanceSessions, 2);
    expect(const AttendanceSummary(absentSessions: 0,
      totalTheorySessions: 15).allowanceSessions, 3);
    expect(const AttendanceSummary(absentSessions: 0,
      totalTheorySessions: 20).allowanceSessions, 4);
  });

  test('different period lengths still represent one class meeting each', () {
    final result = AttendanceSummary.fromRawEnvelope(envelope([
      row(0, status: 'Vắng mặt(2)', periods: 2),
      row(1, status: 'Có mặt(4)', periods: 4),
      row(2, status: 'Có mặt(1)', periods: 1),
      row(3, status: 'Có mặt(3)', periods: 3),
    ]));
    expect(result[atbm]!.totalTheorySessions, 4);
    expect(result[atbm]!.absentSessions, 1);
    expect(result[atbm]!.allowanceSessions, 1);
  });

  test('duplicate verified row never inflates total or absence count', () {
    final original = row(0, status: 'Vắng mặt(3)');
    final result = AttendanceSummary.fromRawEnvelope(envelope([
      original, {...original}, row(1, status: 'Có mặt(3)'),
    ]));
    expect(result[atbm]!.totalTheorySessions, 2);
    expect(result[atbm]!.absentSessions, 1);
  });

  test('conflicting attendance on same row hides only its subject badge', () {
    expect(AttendanceSummary.fromRawEnvelope(envelope([
      row(0, status: 'Có mặt(3)'),
      row(0, status: 'Vắng mặt(3)'),
    ])), isEmpty);
  });

  test('unknown attendance is not assumed confirmed present or absent', () {
    expect(AttendanceSummary.fromRawEnvelope(envelope([row(0)])), isEmpty);
    final result = AttendanceSummary.fromRawEnvelope(envelope([
      row(0, status: 'Có mặt(3)'),
      row(1), row(2), row(3), row(4),
    ]));
    expect(result[atbm]!.absentSessions, 0);
    expect(result[atbm]!.totalTheorySessions, 5);
  });

  test('no ID fallback uses original class/date/time, not enrollment count', () {
    final rows = [
      row(0, status: 'Vắng mặt(3)', hasId: false),
      row(1, status: 'Có mặt(3)', hasId: false),
    ];
    expect(AttendanceSummary.fromRawEnvelope(envelope(rows))[atbm]!
      .totalTheorySessions, 2);
  });

  test('verified parser retains transient attendance without changing v1.6 format', () {
    final raw = envelope([
      row(0, status: 'Vắng mặt(3)'),
      row(1, status: 'Có mặt(3)'),
      row(2, section: 'N05.TH1', status: 'Vắng mặt(3)'),
    ]);
    final parsed = const QldtParser().parseLiveEnvelope(raw, strict: true);
    expect(parsed.classes.first.lessonKind, 'LT');
    expect(parsed.classes.first.attendanceStatus, 'Vắng mặt(3)');
    final fromParser = AttendanceSummary.fromVerifiedSchedule(parsed);
    final fromEnvelope = AttendanceSummary.fromRawEnvelope(raw);
    expect(fromParser[atbm]!.absentSessions, fromEnvelope[atbm]!.absentSessions);
    expect(fromParser[atbm]!.totalTheorySessions, 2);
    final encoded = parsed.encode();
    expect(encoded, isNot(contains('attendanceStatus')));
    expect(ImportedScheduleData.decode(encoded).classes.first.attendanceStatus, isNull);
  });

  test('bad optional attendance never invalidates schedule and old cache is rejected', () {
    expect(AttendanceSummary.fromRawEnvelope('broken'), isEmpty);
    expect(AttendanceSummary.fromRawEnvelope(
      '{"response":{"Success":false}}'), isEmpty);
    expect(AttendanceSummary.fromJson(
      {'absentPeriods': 6, 'theoryPeriods': 30}), isNull);
    expect(AttendanceSummary.fromJson(
      {'absentSessions': 1, 'totalTheorySessions': 5})!.allowanceSessions, 1);
    expect(AttendanceSummary.fromRawEnvelope(envelope([
      row(0, status: 'Vắng mặt(99)'),
    ])), isEmpty);
    expect(const QldtParser().parseLiveEnvelope(
      envelope([row(0, status: 'Vắng mặt(99)')]), strict: true
    ).classes, hasLength(1));
  });

  test('old 1.6 schedule with no attendance remains readable', () {
    final old = ImportedScheduleData(
      displayName: 'Sinh viên',
      syncedAt: DateTime(2026, 9, 1),
      records: [ScheduleRecord(
        id: 'original', isExam: false, subjectName: 'An toàn và bảo mật thông tin',
        room: 'A6', startAt: DateTime(2026, 9, 1, 7),
        endAt: DateTime(2026, 9, 1, 9),
      )],
    );
    final restored = ImportedScheduleData.decode(old.encode());
    expect(AttendanceSummary.fromVerifiedSchedule(restored), isEmpty);
  });
}
