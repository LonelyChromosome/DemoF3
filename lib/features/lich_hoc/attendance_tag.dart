import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter/material.dart';

/// The attendance tag is a per-subject total, never a per-card attendance mark.
/// Only QLĐT's explicitly tagged theory lessons contribute to either side.
final class AttendanceSummary {
  const AttendanceSummary({required this.absentPeriods, required this.theoryPeriods});

  final int absentPeriods;
  final int theoryPeriods;

  int get absentSessions => absentPeriods ~/ 3;
  int get allowanceSessions => (theoryPeriods * .20 / 3).floor();
  bool get exceeded => absentPeriods > theoryPeriods * .20;

  static Map<String, AttendanceSummary> fromSchedule(ImportedScheduleData data) {
    final allPeriods = <String, int>{};
    final absentPeriods = <String, int>{};
    final seen = <String>{};
    for (final lesson in data.classes) {
      // E-learning and practice do not contribute to the LT tag at all.
      final type = lesson.lessonType.trim().toLowerCase();
      if (type != 'ly thuyet' && type != 'lý thuyết' && type != 'lt') continue;
      if (!seen.add(lesson.id)) continue;
      final name = normalizeSubjectName(lesson.subjectName);
      if (name.isEmpty) continue;
      final periods = lesson.periodCount ??
          (lesson.periodStart != null && lesson.periodEnd != null
              ? lesson.periodEnd! - lesson.periodStart! + 1
              : 0);
      if (periods <= 0) continue;
      allPeriods[name] = (allPeriods[name] ?? 0) + periods;
      if (lesson.attendanceStatus.trim().toLowerCase().startsWith('vắng mặt')) {
        absentPeriods[name] = (absentPeriods[name] ?? 0) + periods;
      }
    }
    return {
      for (final entry in allPeriods.entries)
        if (entry.value >= 3)
          entry.key: AttendanceSummary(
            absentPeriods: absentPeriods[entry.key] ?? 0,
            theoryPeriods: entry.value,
          ),
    };
  }
}

class AttendanceTag extends StatelessWidget {
  const AttendanceTag({required this.summary, this.compact = false, super.key});

  final AttendanceSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final allowance = summary.allowanceSessions;
    if (allowance <= 0) return const SizedBox.shrink();
    final used = summary.absentPeriods / (summary.theoryPeriods * .20);
    final color = summary.exceeded
        ? const Color(0xFFEF4444)
        : used >= 1
            ? const Color(0xFFF59E0B)
            : used > .35
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
          'Đã nghỉ ${summary.absentSessions}/$allowance',
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
