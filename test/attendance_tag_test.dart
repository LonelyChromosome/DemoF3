import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
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
    'NGAYHOC': '${(index % 28 + 1).toString().padLeft(2, '0')}/09/2026',
    'GIOBATDAU': 7,
    'PHUTBATDAU': 0,
    'GIOKETTHUC': 9,
    'PHUTKETTHUC': 0,
    'TENLOPHOCPHAN': 'N05',
  };

  String envelope(List<Map<String, Object?>> rows) => jsonEncode({
    'name': 'Sinh viên',
    'response': {'Success': true, 'Data': rows},
  });

  final it = normalizeSubjectName('An toàn và bảo mật thông tin');
  final theory30 = <String, double>{it: 30.0};

  test('official allocations parse LT only, including fraction and order', () {
    expect(AttendanceSummary.officialTheoryPeriods('LT(22.5),TH(15)'), 22.5);
    expect(AttendanceSummary.officialTheoryPeriods('TH(30),LT(15)'), 15);
    expect(AttendanceSummary.officialTheoryPeriods('LT(30),TH(30)'), 30);
    expect(AttendanceSummary.officialTheoryPeriods('TH(60),LT(0)'), isNull);
    expect(AttendanceSummary.officialTheoryPeriods('TH(60)'), isNull);
    expect(AttendanceSummary.officialTheoryPeriods('LT(15),LT(30)'), isNull);
    expect(AttendanceSummary.officialAllocations([
      {
        'DAOTAO_HOCPHAN_TEN': 'Kỹ thuật phần mềm',
        'THONGTINPHANBOTIETHOC': 'LT(22.5),TH(15)',
      },
    ])[normalizeSubjectName('Kỹ thuật phần mềm')], 22.5);
  });

  test('no official LT total never fabricates an allowance', () {
    final rows = [
      for (var i = 0; i < 10; i++) row(i, status: 'Vắng mặt(3)'),
    ];
    expect(AttendanceSummary.fromRawEnvelope(envelope(rows)), isEmpty);
  });

  test('only confirmed theory absences count, not practice or e-learning', () {
    final rows = [
      for (var i = 0; i < 10; i++)
        row(i, status: i < 2 ? 'Vắng mặt(3)' : 'Có mặt(3)'),
      row(11, type: 'Thuc hanh', status: 'Vắng mặt(3)'),
      row(12, type: 'Elearning', status: 'Vắng mặt(3)'),
    ];
    final result = AttendanceSummary.fromRawEnvelope(envelope(rows),
        theoryPeriodsBySubject: theory30);
    final summary = result[it]!;
    expect(summary.theoryPeriods, 30);
    expect(summary.absentPeriods, 6);
    expect(summary.absentSessions, 2);
    expect(summary.allowanceSessions, 2);
    expect(summary.exceeded, false);
  });

  test('parser extracts attendance only in memory, not in the 1.6 snapshot', () {
    final raw = envelope([
      row(0, status: 'Vắng mặt(3)'),
      row(1, status: 'Có mặt(3)'),
      row(2, type: 'Thuc hanh', status: 'Vắng mặt(3)'),
    ]);
    final parsed = const QldtParser().parseLiveEnvelope(raw, strict: true);
    expect(parsed.classes.first.lessonKind, 'LT');
    expect(parsed.classes.first.attendanceStatus, 'Vắng mặt(3)');
    expect(parsed.classes.first.lessonPeriods, 3);
    final fromParser = AttendanceSummary.fromVerifiedSchedule(
      parsed, theoryPeriodsBySubject: theory30);
    final fromNative = AttendanceSummary.fromRawEnvelope(
      raw, theoryPeriodsBySubject: theory30);
    expect(fromParser[it]!.absentPeriods, fromNative[it]!.absentPeriods);
    expect(fromParser[it]!.allowanceSessions, 2);
    final saved = parsed.encode();
    expect(saved, isNot(contains('Vắng mặt(3)')));
    expect(saved, isNot(contains('attendanceStatus')));
    final restored = ImportedScheduleData.decode(saved);
    expect(restored.classes.first.attendanceStatus, isNull);
    expect(restored.classes.first.subjectName, parsed.classes.first.subjectName);
  });

  test('same lesson ID does not count twice', () {
    final rows = [
      for (var i = 0; i < 5; i++) row(i, status: 'Vắng mặt(3)'),
      row(0, status: 'Vắng mặt(3)'),
    ];
    final result = AttendanceSummary.fromRawEnvelope(
      envelope(rows), theoryPeriodsBySubject: {it: 15.0});
    expect(result[it]!.absentSessions, 5);
    expect(result[it]!.allowanceSessions, 1);
    expect(result[it]!.exceeded, true);
  });

  test('conflicting duplicate lesson statuses do not produce a badge', () {
    final rows = [
      row(0, status: 'Có mặt(3)'),
      row(0, status: 'Vắng mặt(3)'),
    ];
    expect(AttendanceSummary.fromRawEnvelope(
      envelope(rows), theoryPeriodsBySubject: theory30), isEmpty);
  });

  test('22.5 LT periods permit one full 3-period session', () {
    final subject = normalizeSubjectName('Kỹ thuật phần mềm');
    final result = AttendanceSummary.fromRawEnvelope(
      envelope([row(0, subject: 'Kỹ thuật phần mềm', status: 'Vắng mặt(3)')]),
      theoryPeriodsBySubject: {subject: 22.5},
    );
    expect(result[subject]!.allowanceSessions, 1);
    expect(result[subject]!.absentSessions, 1);
    expect(result[subject]!.exceeded, false);
  });

  test('missing attendance is unknown, not zero; confirmed presence is zero', () {
    final missing = AttendanceSummary.fromRawEnvelope(
      envelope([row(0)]), theoryPeriodsBySubject: theory30);
    expect(missing, isEmpty);
    final present = AttendanceSummary.fromRawEnvelope(
      envelope([row(0, status: 'Có mặt(3)')]),
      theoryPeriodsBySubject: theory30);
    expect(present[it]!.absentSessions, 0);
  });

  test('raw class TH marker is removed from absentee LT totals before matching', () {
    final rows = [
      row(0,
        subject: 'Môn Kỹ thuật phần mềm-1-1-26(COUR02.LT5)',
        status: 'Vắng mặt(3)',
      )..['TENLOPHOCPHAN'] = 'Kỹ thuật phần mềm-1-1-26(COUR02.LT5)',
      row(1,
        subject: 'Môn Kỹ thuật phần mềm-1-1-26(COUR02.TH5)',
        status: 'Vắng mặt(3)',
      )..['TENLOPHOCPHAN'] = 'Kỹ thuật phần mềm-1-1-26(COUR02.TH5)',
    ];
    final subject = normalizeSubjectName('Kỹ thuật phần mềm');
    final summary = AttendanceSummary.fromRawEnvelope(
      envelope(rows),
      theoryPeriodsBySubject: {subject: 22.5},
    )[subject]!;
    expect(summary.absentSessions, 1);
    expect(summary.allowanceSessions, 1);
  });

  test('LT without a type label still counts and TH without one does not', () {
    final rows = [
      row(0, status: 'Vắng mặt(3)', type: '')..['THUOCTINH_TEN'] = null,
      row(1, status: 'Vắng mặt(3)', type: '')
        ..['THUOCTINH_TEN'] = null
        ..['TENLOPHOCPHAN'] = 'CLASS.TH2',
    ];
    final result = AttendanceSummary.fromRawEnvelope(
      envelope(rows),
      theoryPeriodsBySubject: theory30,
    );
    expect(result[it]!.absentSessions, 1);
  });

  test('missing QLDT row ID does not silently drop verified attendance', () {
    final source = row(0, status: 'Vắng mặt(3)');
    source.remove('ID');
    expect(AttendanceSummary.fromRawEnvelope(
      envelope([source]), theoryPeriodsBySubject: theory30,
    )[it]!.absentSessions, 1);
  });

  test('pure e-learning does not create an absence tag', () {
    final subject = normalizeSubjectName('Lịch sử Đảng');
    final summaries = AttendanceSummary.fromRawEnvelope(
      envelope([
        for (var i = 0; i < 10; i++)
          row(i, subject: 'Lịch sử Đảng', type: 'Elearning',
              status: 'Vắng mặt(3)'),
      ]),
      theoryPeriodsBySubject: {subject: 30.0},
    );
    expect(summaries, isEmpty);
  });

  test('bad attendance metadata cannot break a verified timetable', () {
    expect(AttendanceSummary.fromRawEnvelope('broken'), isEmpty);
    expect(AttendanceSummary.fromRawEnvelope(
        '{"response":{"Success":false}}'), isEmpty);
    expect(AttendanceSummary.fromJson(
        {'absentPeriods': -1, 'theoryPeriods': 30}), isNull);
    final raw = envelope([row(0, status: 'Vắng mặt(99)')]);
    final result = AttendanceSummary.fromRawEnvelope(
      raw, theoryPeriodsBySubject: theory30);
    expect(result, isEmpty);
    final parsed = const QldtParser().parseLiveEnvelope(raw, strict: true);
    expect(parsed.classes, hasLength(1));
  });

  test('1.6 snapshots without optional metadata remain readable', () {
    final old = ImportedScheduleData(
      displayName: 'Sinh viên',
      syncedAt: DateTime(2026, 9, 1),
      records: [ScheduleRecord(
        id: 'original',
        isExam: false,
        subjectName: 'An toàn và bảo mật thông tin',
        room: 'A6',
        startAt: DateTime(2026, 9, 1, 7),
        endAt: DateTime(2026, 9, 1, 9),
      )],
    );
    final restored = ImportedScheduleData.decode(old.encode());
    expect(restored.classes.single.lessonKind, isNull);
    expect(AttendanceSummary.fromVerifiedSchedule(
      restored, theoryPeriodsBySubject: theory30), isEmpty);
  });
}
