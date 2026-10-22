import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/attendance_lesson_classifier.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String type(String subject, String section, {String? attr, String? room}) =>
      AttendanceLessonClassifier.classify(
        rawSubjectName: subject,
        rawClassName: section,
        attribute: attr,
        room: room,
      );

  test('TH suffix of original subject is detected before normalization', () {
    expect(type('Môn Kỹ thuật phần mềm-1-1-26(COUR02.TH5)', ''), 'TH');
    expect(type('Môn Kỹ thuật phần mềm-1-1-26(COUR02.LT5)', ''), 'LT');
    expect(type('Thiết kế web nâng cao', 'WEB-2026-TH'), 'TH');
    expect(type('Thiết kế web nâng cao', 'WEB-2026-LT'), 'LT');
  });

  test('modules without TH are LT even when QLDT has no lesson type', () {
    expect(type('Lịch sử Đảng cộng sản Việt Nam', 'HIS-01'), 'LT');
    expect(type('An toàn và bảo mật thông tin', 'ATBM-N02'), 'LT');
    expect(type('THIẾT KẾ THÔNG TIN', 'NC-THEORY'), 'LT');
    expect(type('Toán đại cương', 'N02', attr: 'Thực hành'), 'TH');
    expect(type('Thiết kế web', 'WEB-26.TH03'), 'TH');
    expect(type('Thiết kế web', 'WEB-26', attr: 'thuc hanh'), 'TH');
  });

  test('e-learning and exams are not accidentally counted as LT', () {
    expect(type('Học phần trực tuyến', 'ONLINE-01', attr: 'Elearning'),
        'ELEARNING');
    expect(type('Học phần trực tuyến', 'ONLINE-01', room: 'ONLINE- Elearning'),
        'ELEARNING');
    expect(type('Lịch sử Đảng-1-1-26(N02).ELN', 'N02.ELN'),
        'ELEARNING');
    expect(type('Kỹ thuật phần mềm-1-1-26(COUR02)', 'COUR02.ELN'),
        'ELEARNING');
  });

  test('QLDT HTML status and period range remain separate from clean class identity', () {
    final item = <String, Object?>{
      'PHANLOAI': 'LICHHOC',
      'TENHOCPHAN': 'Môn Kỹ thuật phần mềm-1-1-26(COUR02)',
      'TENLOPHOCPHAN': 'Kỹ thuật phần mềm-1-1-26(COUR02)<br>Vắng mặt<br>',
      'NGAYHOC': '23/09/2026',
      'GIOBATDAU': 7,
      'PHUTBATDAU': 0,
      'GIOKETTHUC': 9,
      'PHUTKETTHUC': 0,
      'TIETBATDAU': 1,
      'TIETKETTHUC': 3,
      'PHONGHOC_TEN': 'A1',
    };
    final parsed = const QldtParser().parseApiResponse({
      'Success': true,
      'Data': [item],
    }, displayName: 'Sinh viên', strict: true).classes.single;
    expect(parsed.subjectName, 'Kỹ thuật phần mềm');
    expect(parsed.className, 'Kỹ thuật phần mềm-1-1-26(COUR02)');
    expect(parsed.lessonKind, 'LT');
    expect(parsed.attendanceStatus, 'Vắng mặt');
    expect(parsed.lessonPeriods, 3);
    expect(parsed.toJson().containsKey('attendanceStatus'), false);
  });

  test('normal timetable identity stays byte-identical despite TH marker', () {
    Map<String, Object?> course(String rawName) => {
      'PHANLOAI': 'LICHHOC',
      'TENHOCPHAN': rawName,
      'TENLOPHOCPHAN': 'COUR02.LT5',
      'NGAYHOC': '23/09/2026',
      'GIOBATDAU': 7,
      'PHUTBATDAU': 0,
      'GIOKETTHUC': 9,
      'PHUTKETTHUC': 0,
      'PHONGHOC_TEN': 'A1',
      'THONGTINCHUYENCAN': 'Vắng mặt(3)',
      'SOTIET': 3,
    };
    final withSuffix = const QldtParser().parseApiResponse({
      'Success': true,
      'Data': [course('Môn Kỹ thuật phần mềm-1-1-26(COUR02.LT5)')],
    }, displayName: 'Sinh viên').records.single;
    final withoutSuffix = const QldtParser().parseApiResponse({
      'Success': true,
      'Data': [course('Kỹ thuật phần mềm')],
    }, displayName: 'Sinh viên').records.single;
    expect(withSuffix.id, withoutSuffix.id);
    expect(withSuffix.subjectName, withoutSuffix.subjectName);
    expect(withSuffix.lessonKind, 'LT');
    expect(withoutSuffix.lessonKind, 'LT');
    // Non-personal session mode survives cold start for Find Bike eLearning exclusion.
    expect(withSuffix.toJson()['lessonKind'], 'LT');
    expect(ScheduleRecord.fromJson(withSuffix.toJson()).lessonKind, 'LT');
    expect(withSuffix.toJson().containsKey('attendanceStatus'), false);
  });
}
