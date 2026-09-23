import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/registration_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = QldtRegistrationParser();
  const html = '''
    <select id="dropSearch_HocKy">
      <option value="">Chọn học kỳ</option>
      <option value="previous">2025_2026_3</option>
      <option value="latest">2026_2027_1</option>
    </select>
    <div id="zoneKetQuaDangKy">
      <div class="subject-item">
        <div><h4>Lập trình C++</h4></div>
        <div class="classroom-section-item">
          <a class="btnChiTietLopHocPhan">C++-LT</a>
          <div class="classroom-day">17/08/2026 - 01/11/2026</div>
        </div>
        <div class="classroom-section-item">
          <a class="btnChiTietLopHocPhan">C++-TH</a>
          <div class="classroom-day">24/08/2026 - 25/10/2026</div>
        </div>
      </div>
      <div class="subject-item"><div><h4>Toán cao cấp</h4></div></div>
    </div>
  ''';

  test('uses semester chronology and groups class components by subject', () {
    final semester = parser.parse(html: html, selectedSemesterValue: 'latest');
    expect(semester.id, '2026_2027_1');
    expect(semester.subjectNames, <String>['Lập trình C++', 'Toán cao cấp']);
    expect(semester.classSections['Lập trình C++'], hasLength(2));
    expect(semester.classSections['Lập trình C++']!.first.name, 'C++-LT');
    expect(
      semester.classSections['Lập trình C++']!.first.startsOn,
      DateTime(2026, 8, 17),
    );
    expect(semester.classSections['Toán cao cấp'], isEmpty);
  });

  test('rejects DOM results that still belong to another semester', () {
    expect(
      () => parser.parse(html: html, selectedSemesterValue: 'previous'),
      throwsFormatException,
    );
  });

  test('rejects an unloaded registration result', () {
    expect(
      () => parser.parse(
        html: html.replaceAll('class="subject-item"', 'class="pending"'),
        selectedSemesterValue: 'latest',
      ),
      throwsFormatException,
    );
  });
}
