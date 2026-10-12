import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter/material.dart';

/// A separate, best-effort view of QLĐT's raw personal schedule.
/// This class is not used by the authoritative schedule parser/verifier.
final class AttendanceSummary {
  const AttendanceSummary({
    required this.absentPeriods,
    required this.theoryPeriods,
  });

  final int absentPeriods;
  final int theoryPeriods;

  int get absentSessions => (absentPeriods / 3).ceil();
  int get allowanceSessions => (theoryPeriods * .20 / 3).floor();
  bool get exceeded => absentPeriods > theoryPeriods * .20;

  Map<String, int> toJson() => <String, int>{
    'absentPeriods': absentPeriods,
    'theoryPeriods': theoryPeriods,
  };

  static AttendanceSummary? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final absent = raw['absentPeriods'];
    final total = raw['theoryPeriods'];
    if (absent is! int || total is! int || absent < 0 || total <= 0 ||
        absent > total) return null;
    return AttendanceSummary(absentPeriods: absent, theoryPeriods: total);
  }

  /// A parse failure must never fail or alter a successful timetable sync.
  /// Rows without reliable LT/TH identity are deliberately not guessed.
  static Map<String, AttendanceSummary> fromRawEnvelope(String envelope) {
    try {
      final parsed = jsonDecode(envelope);
      if (parsed is! Map) return const {};
      final response = parsed['response'];
      if (response is! Map || response['Success'] != true ||
          response['Data'] is! List) return const {};
      final rows = response['Data'] as List;
      final totals = <String, int>{};
      final absences = <String, int>{};
      final confirmed = <String>{};
      final seen = <String>{};
      for (final value in rows) {
        if (value is! Map) continue;
        if (value['PHANLOAI']?.toString().toUpperCase() != 'LICHHOC') continue;
        final kind = value['THUOCTINH_TEN']?.toString().trim().toLowerCase();
        if (kind != 'ly thuyet' && kind != 'lý thuyết') continue;
        final subject = normalizeSubjectName(value['TENHOCPHAN']?.toString() ?? '');
        if (subject.isEmpty) continue;
        final periodsValue = value['SOTIET'];
        final periods = periodsValue is num ? periodsValue.toInt() :
            int.tryParse(periodsValue?.toString() ?? '');
        if (periods == null || periods <= 0) continue;
        final key = value['ID']?.toString().trim();
        if (key == null || key.isEmpty || !seen.add(key)) continue;
        totals[subject] = (totals[subject] ?? 0) + periods;
        final status = value['THONGTINCHUYENCAN']?.toString().trim().toLowerCase() ?? '';
        if (status.startsWith('có mặt') || status.startsWith('vắng mặt')) {
          confirmed.add(subject);
        }
        if (status.startsWith('vắng mặt')) {
          final match = RegExp(r'\((\d+)\)').firstMatch(status);
          final absent = match == null ? periods : int.tryParse(match[1]!) ?? periods;
          if (absent <= periods) {
            absences[subject] = (absences[subject] ?? 0) + absent;
          }
        }
      }
      return {
        for (final entry in totals.entries)
          if (entry.value >= 15 && confirmed.contains(entry.key))
            entry.key: AttendanceSummary(
              absentPeriods: absences[entry.key] ?? 0,
              theoryPeriods: entry.value,
            ),
      };
    } on Object {
      return const {};
    }
  }
}

class AttendanceTag extends StatelessWidget {
  const AttendanceTag({required this.summary, this.compact = false, super.key});
  final AttendanceSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final max = summary.allowanceSessions;
    if (max < 1) return const SizedBox.shrink();
    final used = summary.absentPeriods / (summary.theoryPeriods * .20);
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
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 7,
            vertical: compact ? 2 : 3),
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
