import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:html/parser.dart' as html_parser;

final class QldtRegistrationParser {
  const new();

  RegisteredSemester parse({
    required String html,
    required String selectedSemesterValue,
  }) {
    final document = html_parser.parse(html);
    final dropdown = document.querySelector('#dropSearch_HocKy');
    final results = document.querySelector('#zoneKetQuaDangKy');
    if (dropdown == null || results == null) {
      throw const FormatException('TraCuu chưa tải đủ dữ liệu đăng ký.');
    }

    final semesters = <_SemesterOption>[];
    for (final option in dropdown.querySelectorAll('option')) {
      final value = option.attributes['value']?.trim() ?? '';
      final name = option.text.trim();
      final match = RegExp(r'^(\d{4})_(\d{4})_(\d+)$').firstMatch(name);
      if (value.isEmpty || match == null) {
        continue;
      }
      final startYear = int.parse(match.group(1)!);
      final endYear = int.parse(match.group(2)!);
      if (endYear != startYear + 1) {
        continue;
      }
      semesters.add(
        _SemesterOption(
          value: value,
          name: name,
          startYear: startYear,
          term: int.parse(match.group(3)!),
        ),
      );
    }
    if (semesters.isEmpty) {
      throw const FormatException('TraCuu không trả danh sách học kỳ hợp lệ.');
    }
    semesters.sort((a, b) {
      final year = b.startYear.compareTo(a.startYear);
      return year != 0 ? year : b.term.compareTo(a.term);
    });
    final latest = semesters.first;
    if (selectedSemesterValue.trim() != latest.value) {
      throw const FormatException(
        'TraCuu chưa hiển thị kết quả của học kỳ mới nhất.',
      );
    }

    final subjectItems = results.querySelectorAll('.subject-item');
    if (subjectItems.isEmpty) {
      throw const FormatException('TraCuu chưa trả danh sách môn đăng ký.');
    }
    final subjectNames = <String>[];
    for (final item in subjectItems) {
      final name = item.querySelector('h4')?.text.trim() ?? '';
      if (name.isEmpty) {
        throw const FormatException('TraCuu có môn học không có tên.');
      }
      subjectNames.add(name);
    }

    return RegisteredSemester(
      id: latest.name,
      name: latest.name,
      subjectNames: subjectNames,
    );
  }
}

final class _SemesterOption {
  const new({
    required this.value,
    required this.name,
    required this.startYear,
    required this.term,
  });

  final String value;
  final String name;
  final int startYear;
  final int term;
}
