import 'package:better_phenikaa_schedule/features/qldt_intake/qldt_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = QldtParser();

  test('extracts the display name from the QLĐT account element', () {
    const html = '''
      <div class="nav-account">
        <span id="lblHoTenNguoiDangNhap">Nguyễn Minh Đạo</span>
      </div>
    ''';

    expect(parser.parseDisplayName(html), 'Nguyễn Minh Đạo');
  });

  test('separates study schedule and exam schedule using PHANLOAI', () {
    final parsed = parser.parseApiResponse(<String, dynamic>{
      'Success': true,
      'Data': <Map<String, dynamic>>[
        <String, dynamic>{
          'PHANLOAI': 'LICHHOC',
          'NGAYHOC': '26/08/2026',
          'TENHOCPHAN': 'Thiết kế web nâng cao',
          'PHONGHOC_TEN': 'A6-101',
          'GIOBATDAU': 6,
          'PHUTBATDAU': 45,
          'GIOKETTHUC': 9,
          'PHUTKETTHUC': 25,
        },
        <String, dynamic>{
          'PHANLOAI': 'LICHTHI',
          'NGAYHOC': '26/08/2026',
          'TENHOCPHAN': 'Lập trình C++',
          'PHONGTHI': 'A6-201',
          'GIOBATDAU': 7,
          'PHUTBATDAU': 30,
          'GIOKETTHUC': 9,
          'PHUTKETTHUC': 0,
        },
      ],
    }, displayName: 'Nguyễn Minh Đạo');

    expect(parsed.displayName, 'Nguyễn Minh Đạo');
    expect(parsed.classes, hasLength(1));
    expect(parsed.exams, hasLength(1));
    expect(parsed.classes.single.subjectName, 'Thiết kế web nâng cao');
    expect(parsed.exams.single.room, 'A6-201');
  });

  test('local snapshot JSON round-trip preserves records', () {
    final original = ImportedScheduleData(
      displayName: 'Nguyễn Minh Đạo',
      syncedAt: DateTime(2026, 9, 9, 14),
      records: <ScheduleRecord>[
        ScheduleRecord(
          id: 'one',
          isExam: false,
          subjectName: 'Lập trình mobile',
          room: 'A6-205',
          startAt: DateTime(2026, 8, 26, 9, 30),
          endAt: DateTime(2026, 8, 26, 12, 10),
        ),
      ],
    );

    final restored = ImportedScheduleData.decode(original.encode());
    expect(restored.displayName, original.displayName);
    expect(restored.records.single.room, 'A6-205');
    expect(restored.records.single.startAt, DateTime(2026, 8, 26, 9, 30));
  });
}
