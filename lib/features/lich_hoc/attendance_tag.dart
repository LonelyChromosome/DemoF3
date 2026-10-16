import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/attendance_lesson_classifier.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter/material.dart';

/// Optional, validated attendance facts; completely separate from timetable
/// identity, verification and the authoritative save transaction.
final class AttendanceSummary {
  const AttendanceSummary({
    required this.absentSessions,
    required this.totalTheorySessions,
  });

  // Student's actual enrolled LT timetable: one unique class meeting is
  // one session, regardless of credit-hour or per-meeting period count.
  final int absentSessions;
  final int totalTheorySessions;

  // BPA attendance allowance rounds 20% of scheduled LT sessions UP.
  // 4/5 -> 1, 10 -> 2, 15 -> 3, 20 -> 4.
  int get allowanceSessions => (totalTheorySessions / 5).ceil();
  bool get exceeded => absentSessions > allowanceSessions;

  Map<String, Object> toJson() => <String, Object>{
    'absentSessions': absentSessions,
    'totalTheorySessions': totalTheorySessions,
  };

  static AttendanceSummary? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final absent = raw['absentSessions'];
    final total = raw['totalTheorySessions'];
    if (absent is! int || total is! int || total < 1 ||
        absent < 0 || absent > total) return null;
    return AttendanceSummary(
      absentSessions: absent,
      totalTheorySessions: total,
    );
  }

  /// During login the verified parser retains optional LT markers in memory
  /// without writing individual attendance into the legacy 1.6 snapshot.
  static Map<String, AttendanceSummary> fromVerifiedSchedule(
    ImportedScheduleData schedule,
  ) => _aggregate(
    schedule.classes.map(
      (record) => _AttendanceLesson(
        id: record.id,
        name: record.subjectName,
        kind: record.lessonKind,
        status: record.attendanceStatus,
        periods: record.lessonPeriods,
      ),
    ),
  );

  /// Native headless QLĐT uses its own VERIFIED timetable parser, so keep a
  /// best-effort adapter for the same original envelope. Failure returns
  /// nothing, never changes the verified schedule or blocks its saving.
  static Map<String, AttendanceSummary> fromRawEnvelope(
    String envelope,
  ) {
    try {
      final parsed = jsonDecode(envelope);
      if (parsed is! Map) return const {};
      final response = parsed['response'];
      if (response is! Map || response['Success'] != true ||
          response['Data'] is! List) return const {};
      return _aggregate(
        (response['Data'] as List).whereType<Map>().map((row) {
          final rawSubject = row['TENHOCPHAN']?.toString() ?? '';
          final rawClass = row['TENLOPHOCPHAN']?.toString() ?? '';
          final room = (row['PHONGHOC_TEN'] ?? row['TENPHONGHOC'])
              ?.toString() ?? '';
          return _AttendanceLesson(
            id: _attendanceRowId(row),
            name: rawSubject,
            // Read TH from the ORIGINAL component identifiers; QLĐT does
            // not always provide an explicit "Lý thuyết" field.
            kind: row['PHANLOAI']?.toString().toUpperCase() == 'LICHHOC'
                ? AttendanceLessonClassifier.classify(
                    rawSubjectName: rawSubject,
                    rawClassName: rawClass,
                    attribute: row['THUOCTINH_TEN']?.toString(),
                    room: room,
                  )
                : 'EXAM',
            status: _attendanceStatus(row),
            periods: _lessonPeriodCount(row),
          );
        }),
      );
    } on Object {
      return const {};
    }
  }

  static Map<String, AttendanceSummary> _aggregate(
    Iterable<_AttendanceLesson> rows,
  ) {
    final total = <String, int>{};
    final absent = <String, int>{};
    final seen = <String, String>{};
    final conflicted = <String>{};

    for (final row in rows) {
      final kind = row.kind?.trim().toLowerCase() ?? '';
      // The raw QLĐT TH/ELN component is filtered BEFORE normalization.
      if (kind != 'lt' && kind != 'ly thuyet' && kind != 'lý thuyết') {
        continue;
      }
      final subject = normalizeSubjectName(row.name);
      if (subject.isEmpty || row.id.trim().isEmpty) continue;
      final status = row.status?.trim().toLowerCase() ?? '';
      final identity = '$subject|'+row.id.trim();
      final fingerprint = '$kind|'+(row.periods?.toString() ?? '')+'|$status';
      final previous = seen[identity];
      if (previous != null) {
        if (previous != fingerprint) conflicted.add(subject);
        continue;
      }
      seen[identity] = fingerprint;
      // All verified LT meetings count toward allowance, including upcoming
      // ones with UNKNOWN attendance status.
      total[subject] = (total[subject] ?? 0) + 1;
      if (status.startsWith('vắng mặt')) {
        final match = RegExp(r'\((\d+)\)').firstMatch(status);
        final count = match == null ? null : int.tryParse(match[1]!);
        if (count != null && (count <= 0 || count > 20 ||
            (row.periods != null && count > row.periods!))) {
          conflicted.add(subject);
          continue;
        }
        // Count absences per verified class MEETING, not period count / 3.
        absent[subject] = (absent[subject] ?? 0) + 1;
      }
      // Empty/unverified status is not counted as a recorded absence;
      // this is a count of reported absences, not proof of attendance.
    }
    return {
      // A verified LT schedule with no recorded absence still displays 0/N.
      // Keep conflicted or invalid evidence hidden rather than fabricating totals.
      for (final subject in total.keys)
        if (!conflicted.contains(subject) &&
            (total[subject] ?? 0) > 0 &&
            (absent[subject] ?? 0) <= total[subject]!)
          subject: AttendanceSummary(
            absentSessions: absent[subject] ?? 0,
            totalTheorySessions: total[subject]!,
          ),
    };
  }
}

// Prefer the native verifier's exact accepted class ID. If QLĐT omits ID
// during a normal login, reconstruct the stable key from the *unmodified*
// identifying fields, not a per-course counter or list position.
String _attendanceRowId(Map row) {
  final verifiedId = row['ID']?.toString().trim();
  if (verifiedId != null && verifiedId.isNotEmpty) return verifiedId;
  final subject = row['TENHOCPHAN']?.toString().trim() ?? '';
  final section = (row['TENLOPHOCPHAN']?.toString() ?? '')
      .split(RegExp(r'<br\s*/?>', caseSensitive: false)).first.trim();
  final date = row['NGAYHOC']?.toString().trim() ?? '';
  final hour = int.tryParse(row['GIOBATDAU']?.toString() ?? '');
  final minute = int.tryParse(row['PHUTBATDAU']?.toString() ?? '');
  final room = (row['PHONGHOC_TEN'] ?? row['TENPHONGHOC'])
      ?.toString().trim() ?? '';
  if (subject.isEmpty || section.isEmpty || date.isEmpty ||
      hour == null || minute == null || hour < 0 || hour > 23 ||
      minute < 0 || minute > 59) return '';
  return '$subject|$section|$date|$hour:$minute|$room';
}

int? _lessonPeriodCount(Map row) {
  final raw = row['SOTIET'];
  final reported = raw is num ? raw.toInt()
      : int.tryParse(raw?.toString() ?? '');
  if (reported != null && reported > 0 && reported <= 20) {
    return reported;
  }
  final first = int.tryParse(row['TIETBATDAU']?.toString() ?? '');
  final last = int.tryParse(row['TIETKETTHUC']?.toString() ?? '');
  if (first != null && last != null && last >= first &&
      last - first < 20) return last - first + 1;
  // An explicit number inside a verified attendance status is a last-resort
  // source, not the count of rows downloaded from the timetable.
  final text = _attendanceStatus(row);
  final match = text == null ? null : RegExp(r'\((\d+)\)').firstMatch(text);
  final periods = match == null ? null : int.tryParse(match[1]!);
  if (periods == null || periods <= 0 || periods > 20) return null;
  return periods;
}

String? _attendanceStatus(Map row) {
  final direct = row['THONGTINCHUYENCAN']?.toString().trim();
  if (direct != null && direct.isNotEmpty && direct != 'null') return direct;
  final raw = row['TENLOPHOCPHAN']?.toString() ?? '';
  final tag = RegExp(
    r'<br\s*/?>\s*(Có mặt|Vắng mặt)\s*(?:<br\s*/?>|$)',
    caseSensitive: false,
  ).firstMatch(raw);
  return tag?[1];
}

/// The summary is per SUBJECT, but the badge must appear only on its
/// actual LT CLASS card. A subject with LT + ELN must never show this badge on
/// ELN cards; an ELN-only subject never receives a tag.
AttendanceSummary? attendanceForStudyCard(
  ScheduleRecord record,
  Map<String, AttendanceSummary> bySubject,
) {
  if (record.isExam) return null;
  final kind = AttendanceLessonClassifier.classify(
    rawSubjectName: record.subjectName,
    rawClassName: record.className,
    attribute: record.lessonKind,
    room: record.room,
  );
  if (kind != 'LT') return null;
  return bySubject[normalizeSubjectName(record.subjectName)];
}


Set<String> practiceCardIdsFromVerifiedSchedule(ImportedScheduleData schedule) =>
    schedule.classes
        .where((record) => isPracticeStudyCard(record, const <String>{}))
        .map((record) => record.id)
        .toSet();

/// Use only the native-verified rows sent through the isolated pull channel.
/// Their IDs match the unchanged 1.6 schedule-card identifiers exactly.
Set<String> practiceCardIdsFromVerifiedEnvelope(String envelope) {
  try {
    final parsed = jsonDecode(envelope);
    if (parsed is! Map || parsed['response'] is! Map) return const <String>{};
    final response = parsed['response'] as Map;
    if (response['Success'] != true || response['Data'] is! List) {
      return const <String>{};
    }
    final ids = <String>{};
    for (final raw in response['Data'] as List) {
      if (raw is! Map ||
          raw['PHANLOAI']?.toString().toUpperCase() != 'LICHHOC') {
        continue;
      }
      final id = raw['ID']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (AttendanceLessonClassifier.classify(
        rawSubjectName: raw['TENHOCPHAN']?.toString() ?? '',
        rawClassName: raw['TENLOPHOCPHAN']?.toString() ?? '',
        attribute: raw['THUOCTINH_TEN']?.toString(),
        room: raw['PHONGHOC_TEN']?.toString() ??
            raw['TENPHONGHOC']?.toString() ?? '',
      ) == 'TH') {
        ids.add(id);
      }
    }
    return ids;
  } on Object {
    return const <String>{};
  }
}

/// TH is a lesson type, never a subject-wide absence counter.
/// ELN takes precedence even when a class record contains other markers.
bool isPracticeStudyCard(ScheduleRecord record, Set<String> practiceIds) {
  if (record.isExam) return false;
  final kind = AttendanceLessonClassifier.classify(
    rawSubjectName: record.subjectName,
    rawClassName: record.className,
    attribute: record.lessonKind,
    room: record.room,
  );
  if (kind == 'ELEARNING') return false;
  return kind == 'TH' || practiceIds.contains(record.id);
}

/// A small non-interactive tag in the same visual family as AttendanceTag.
class PracticeTag extends StatelessWidget {
  const PracticeTag({this.compact = false, this.maxLabelWidth, super.key});

  final bool compact;
  final double? maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF3B82F6);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .12),
        border: Border.all(color: accent.withValues(alpha: .45), width: .8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 7,
          vertical: compact ? 2 : 3,
        ),
        child: _fitTagLabel(
          maxLabelWidth,
          Text(
            'Thực Hành',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: compact ? 9 : 11,
              height: 1.1,
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

final class _AttendanceLesson {
  const _AttendanceLesson({
    required this.id,
    required this.name,
    required this.kind,
    required this.status,
    required this.periods,
  });
  final String id;
  final String name;
  final String? kind;
  final String? status;
  final int? periods;
}

class AttendanceTag extends StatelessWidget {
  const AttendanceTag({
    required this.summary,
    this.compact = false,
    this.maxLabelWidth,
    super.key,
  });

  final AttendanceSummary summary;
  final bool compact;
  final double? maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    final max = summary.allowanceSessions;
    if (max < 1) return const SizedBox.shrink();
    // The badge is measured in allowed 3-period SESSIONS, not raw periods.
    // LT(22.5) permits one full absence: 1/1 must be orange.
    final used = summary.absentSessions / max;
    final color = summary.exceeded
        ? const Color(0xFFEF4444)
        : used >= 1
        ? const Color(0xFFF59E0B)
        : used >= .5
        ? const Color(0xFF3B82F6)
        : const Color(0xFF22C55E);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .45), width: .8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 7,
          vertical: compact ? 2 : 3,
        ),
        child: _fitTagLabel(
          maxLabelWidth,
          Text(
            'Đã nghỉ ${summary.absentSessions}/$max',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: compact ? 9 : 11,
              height: 1.1,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

// Only the selected font's glyphs shrink when a caller supplies a label bound.
// The tag's padding, border and original row remain in place.
Widget _fitTagLabel(double? maxWidth, Widget text) => maxWidth == null
    ? text
    : ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: FittedBox(fit: BoxFit.scaleDown, child: text),
      );
