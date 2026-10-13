/// Classify QLĐT attendance lessons BEFORE subject/class display names lose
/// component codes during normalization. This is deliberately NOT used by
/// timetable matching or identity generation.
abstract final class AttendanceLessonClassifier {
  // A component code such as (COUR02.TH5), .TH1, -TH or "(TH)" means practice.
  // Never match the TH inside words like "Thiết", "thông" or "theory".
  static final RegExp _practiceCode = RegExp(
    r'(?:^|[\s.\-_/()])TH[0-9]*(?=$|[\s.\-_/()])',
    caseSensitive: false,
  );

  static final RegExp _onlineCode = RegExp(
    r'(?:^|[\s.\-_/()])(?:ELN|ELEARNING|E-LEARNING)[0-9]*(?=$|[\s.\-_/()])',
    caseSensitive: false,
  );

  static String classify({
    required String rawSubjectName,
    required String rawClassName,
    String? attribute,
    String? room,
  }) {
    final attr = (attribute ?? '').trim().toLowerCase();
    final rawRoom = (room ?? '').toLowerCase();
    // E-learning is a separate mode and is never counted as an LT absence.
    if (_isOnline(attr) || _isOnline(rawRoom) ||
        _onlineCode.hasMatch(rawSubjectName) ||
        _onlineCode.hasMatch(rawClassName) ||
        _isOnline(rawSubjectName.toLowerCase()) ||
        _isOnline(rawClassName.toLowerCase())) return 'ELEARNING';

    if (_practiceCode.hasMatch(rawSubjectName) ||
        _practiceCode.hasMatch(rawClassName) ||
        _isPractice(attr)) {
      return 'TH';
    }
    // No TH component in the ORIGINAL source means theory, including modules
    // that have no practical class and therefore no explicit LT label.
    return 'LT';
  }

  static bool _isPractice(String value) =>
      value == 'th' ||
      value.contains('thực hành') ||
      value.contains('thuc hanh');

  static bool _isOnline(String value) =>
      value.contains('elearning') ||
      value.contains('e-learning') ||
      value.contains('e learning');
}
