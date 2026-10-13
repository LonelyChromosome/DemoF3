import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter/material.dart';

/// Optional, validated attendance facts; completely separate from timetable
/// identity, verification and the authoritative save transaction.
final class AttendanceSummary {
  const AttendanceSummary({
    required this.absentPeriods,
    required this.theoryPeriods,
  });

  final int absentPeriods;
  // A registered module can have fractional LT periods (e.g. 22.5).
  final double theoryPeriods;

  int get absentSessions => (absentPeriods / 3).ceil();
  int get allowanceSessions => (theoryPeriods * .20 / 3).floor();
  bool get exceeded => absentPeriods > theoryPeriods * .20;

  Map<String, Object> toJson() => <String, Object>{
    'absentPeriods': absentPeriods,
    'theoryPeriods': theoryPeriods,
  };

  static AttendanceSummary? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final absent = raw['absentPeriods'];
    final total = raw['theoryPeriods'];
    if (absent is! int || total is! num || absent < 0 ||
        !total.toDouble().isFinite || total <= 0 || absent > total) return null;
    return AttendanceSummary(
      absentPeriods: absent,
      theoryPeriods: total.toDouble(),
    );
  }

  /// Parse only an official LT allocation; do not estimate it from the number
  /// of downloaded lessons (future lessons may be missing from QLĐT).
  static double? officialTheoryPeriods(String? allocation) {
    if (allocation == null) return null;
    final matches = RegExp(
      r'\bLT\s*\(\s*(\d+(?:[.,]\d+)?)\s*\)',
      caseSensitive: false,
    ).allMatches(allocation).toList();
    if (matches.length != 1) return null;
    final value = double.tryParse(matches.single[1]!.replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0 || value > 1000) {
      return null;
    }
    return value;
  }

  /// Read optional catalogue metadata from the same source as QLĐT.
  static Map<String, double> officialAllocations(Iterable<Object?> rows) {
    final result = <String, double>{};
    final ambiguous = <String>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final subject = normalizeSubjectName(
        row['DAOTAO_HOCPHAN_TEN']?.toString() ?? '',
      );
      if (subject.isEmpty) continue;
      final total = officialTheoryPeriods(
        row['THONGTINPHANBOTIETHOC']?.toString(),
      );
      if (total == null) continue;
      if (result.containsKey(subject) && result[subject] != total) {
        ambiguous.add(subject);
      }
      result[subject] = total;
    }
    for (final subject in ambiguous) {
      result.remove(subject);
    }
    return result;
  }

  static Map<String, AttendanceSummary> fromVerifiedSchedule(
    ImportedScheduleData schedule, {
    required Map<String, double> theoryPeriodsBySubject,
  }) => _aggregate(
    schedule.classes.map(
      (record) => _AttendanceLesson(
        id: record.id,
        name: record.subjectName,
        kind: record.lessonKind,
        status: record.attendanceStatus,
        periods: record.lessonPeriods,
      ),
    ),
    theoryPeriodsBySubject,
  );

  /// Native headless QLĐT uses its own VERIFIED timetable parser, so keep a
  /// best-effort adapter for the same original envelope. Failure returns
  /// nothing, never changes the verified schedule or blocks its saving.
  static Map<String, AttendanceSummary> fromRawEnvelope(
    String envelope, {
    Map<String, double> theoryPeriodsBySubject = const {},
  }) {
    try {
      final parsed = jsonDecode(envelope);
      if (parsed is! Map) return const {};
      final response = parsed['response'];
      if (response is! Map || response['Success'] != true ||
          response['Data'] is! List) return const {};
      return _aggregate(
        (response['Data'] as List).whereType<Map>().map(
          (row) => _AttendanceLesson(
            id: row['ID']?.toString() ?? '',
            name: row['TENHOCPHAN']?.toString() ?? '',
            kind: row['PHANLOAI']?.toString().toUpperCase() == 'LICHHOC'
                ? row['THUOCTINH_TEN']?.toString()
                : null,
            status: row['THONGTINCHUYENCAN']?.toString(),
            periods: switch (row['SOTIET']) {
              final int n => n,
              final num n => n.toInt(),
              final String n => int.tryParse(n),
              _ => null,
            },
          ),
        ),
        theoryPeriodsBySubject,
      );
    } on Object {
      return const {};
    }
  }

  static Map<String, AttendanceSummary> _aggregate(
    Iterable<_AttendanceLesson> rows,
    Map<String, double> official,
  ) {
    final absent = <String, int>{};
    final confirmed = <String>{};
    final unique = <String>{};
    final conflicted = <String>{};
    for (final row in rows) {
      final kind = row.kind?.trim().toLowerCase() ?? '';
      if (kind != 'ly thuyet' && kind != 'lý thuyết' && kind != 'lt') {
        continue;
      }
      final subject = normalizeSubjectName(row.name);
      if (subject.isEmpty || !official.containsKey(subject)) continue;
      final periods = row.periods;
      if (periods == null || periods <= 0 || periods > 20) continue;
      final id = row.id.trim();
      if (id.isEmpty) continue;
      if (!unique.add('$subject|$id')) continue;
      final status = row.status?.trim().toLowerCase() ?? '';
      if (status.startsWith('có mặt')) {
        confirmed.add(subject);
      } else if (status.startsWith('vắng mặt')) {
        final match = RegExp(r'\((\d+)\)').firstMatch(status);
        final count = match == null ? periods : int.tryParse(match[1]!);
        if (count == null || count < 0 || count > periods) {
          conflicted.add(subject);
          continue;
        }
        confirmed.add(subject);
        absent[subject] = (absent[subject] ?? 0) + count;
      }
      // Null / unverified attendance is NOT considered present or absent.
    }
    return {
      for (final subject in confirmed)
        if (!conflicted.contains(subject) &&
            (official[subject] ?? 0) > 0 &&
            (absent[subject] ?? 0) <= official[subject]!)
          subject: AttendanceSummary(
            absentPeriods: absent[subject] ?? 0,
            theoryPeriods: official[subject]!,
          ),
    };
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
  const AttendanceTag({required this.summary, this.compact = false, super.key});

  final AttendanceSummary summary;
  final bool compact;

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
        child: Text(
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
    );
  }
}
