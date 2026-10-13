import 'dart:math' as math;
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/lich_hoc/attendance_tag.dart';

class RecapSubjectCount {
  const RecapSubjectCount({
    required this.name, required this.scheduleCount,
    required this.absentSessions, required this.theorySessionCount,
  });
  final String name;
  final int scheduleCount;
  final int? absentSessions;
  final int? theorySessionCount;
}

class RecapFacts {
  const RecapFacts({
    required this.days, required this.subjects, required this.periods,
    required this.unknownPeriods, required this.morning, required this.afternoon,
    required this.early, required this.busiest, required this.busiestCount,
    required this.favorite, required this.favoriteCount, required this.lastClass,
    required this.absence, required this.mostAbsent,
    required this.clearSubjects, required this.attendanceConfirmed,
    required this.now,
    required this.displayName,
    required this.syncedAt,
    required this.preview,
    required this.subjectCounts,
    required this.mostFrequentSubjects,
    required this.mostAbsentCount,
    required this.attendanceCoveredSubjects,
  });
  final int days, subjects, periods, unknownPeriods, morning, afternoon, early;
  final DateTime? busiest;
  final int busiestCount, favoriteCount;
  final String favorite;
  final ScheduleRecord? lastClass;
  final int? absence;
  final String? mostAbsent;
  final List<String> clearSubjects;
  // True only when all lesson attendance is independently verified. The 1.7
  // summary cache alone cannot prove a semester was perfectly attended.
  final bool attendanceConfirmed;
  final DateTime now;
  final DateTime syncedAt;
  final String displayName;
  final bool preview;
  final List<RecapSubjectCount> subjectCounts;
  final List<String> mostFrequentSubjects;
  final int? mostAbsentCount;
  final int attendanceCoveredSubjects;
  bool get finished => lastClass != null && !now.isBefore(lastClass!.endAt);

  static RecapFacts calculate(ImportedScheduleData data, {
    required Map<String, AttendanceSummary> attendance,
    required DateTime now,
    int? registeredSubjects,
    bool attendanceConfirmed = false,
  }) {
    final classes = data.classes.toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final byDay = <DateTime, int>{};
    final bySubject = <String, int>{};
    final names = <String, String>{};
    final seenIds = <String>{};
    var periods = 0, unknown = 0, am = 0, pm = 0, early = 0;
    for (final record in classes) {
      final normalized = normalizeSubjectName(record.subjectName);
      final identity = record.id.isNotEmpty ? '$normalized|${record.id}'
          : '$normalized|${record.startAt.toIso8601String()}|${record.className}|${record.room}';
      // Never count the same native-verified lesson twice.
      if (!seenIds.add(identity)) continue;
      final date = DateTime(record.startAt.year, record.startAt.month, record.startAt.day);
      byDay[date] = (byDay[date] ?? 0) + 1;
      final key = normalizeSubjectName(record.subjectName);
      bySubject[key] = (bySubject[key] ?? 0) + 1;
      names[key] = subjectDisplayName(record.subjectName);
      if (record.periodStart != null && record.periodEnd != null &&
          record.periodStart! > 0 && record.periodEnd! >= record.periodStart!) {
        periods += record.periodEnd! - record.periodStart! + 1;
      } else if (record.lessonPeriods != null && record.lessonPeriods! > 0) {
        periods += record.lessonPeriods!;
      } else {
        unknown++;
      }
      if (record.startAt.hour < 12) { am++; } else { pm++; }
      if (record.startAt.hour == 6 && record.startAt.minute == 45) early++;
    }
    final busiestDays = byDay.entries.toList()
      ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
    final frequent = bySubject.entries.toList()
      ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
    final absentEntries = attendance.entries.toList()
      ..sort((a, b) => b.value.absentSessions.compareTo(a.value.absentSessions));
    final validAttendance = absentEntries
        .where((e) => bySubject.containsKey(e.key)).toList();
    final realMisses = validAttendance
        .where((e) => e.value.absentSessions > 0).toList();
    final breakdown = <RecapSubjectCount>[
      for (final entry in bySubject.entries)
        RecapSubjectCount(
          name: names[entry.key] ?? entry.key,
          scheduleCount: entry.value,
          absentSessions: attendance[entry.key]?.absentSessions,
          theorySessionCount: attendance[entry.key]?.totalTheorySessions,
        ),
    ]..sort((a, b) {
      final n = b.scheduleCount.compareTo(a.scheduleCount);
      return n != 0 ? n : a.name.compareTo(b.name);
    });
    final maxCount = frequent.isEmpty ? 0 : frequent.first.value;
    final leaders = frequent.where((e) => e.value == maxCount)
        .map((e) => names[e.key] ?? e.key).toList()..sort();
    return RecapFacts(
      days: byDay.length, subjects: registeredSubjects ?? bySubject.length,
      periods: periods, unknownPeriods: unknown, morning: am, afternoon: pm,
      early: early,
      busiest: busiestDays.isEmpty ? null : busiestDays.first.key,
      busiestCount: busiestDays.isEmpty ? 0 : busiestDays.first.value,
      favorite: frequent.isEmpty ? 'Những môn học của bạn'
          : leaders.length == 1 ? leaders.single
          : '${leaders.length} môn cùng nhiều buổi nhất',
      favoriteCount: frequent.isEmpty ? 0 : frequent.first.value,
      lastClass: classes.isEmpty ? null : (classes.toList()
        ..sort((a, b) => b.endAt.compareTo(a.endAt))).first,
      absence: validAttendance.isEmpty ? null
          : validAttendance.fold<int>(0, (sum, e) => sum + e.value.absentSessions),
      mostAbsent: realMisses.isEmpty ? null
          : names[realMisses.first.key] ?? realMisses.first.key,
      clearSubjects: validAttendance.where((e) => e.value.absentSessions == 0)
          .map((e) => names[e.key] ?? e.key).toList(),
      attendanceConfirmed: attendanceConfirmed,
      now: now,
      syncedAt: data.syncedAt,
      displayName: data.displayName,
      preview: data.source == 'recap_fixture',
      subjectCounts: breakdown,
      mostFrequentSubjects: leaders,
      mostAbsentCount: realMisses.isEmpty ? null
          : realMisses.first.value.absentSessions,
      attendanceCoveredSubjects: validAttendance.length,
    );
  }
}

enum RecapScenario {
  beforeEnd('Trước buổi học cuối'),
  afterEnd('Sau buổi học cuối'),
  perfect('Không nghỉ buổi nào · đã xác nhận'),
  someMissed('Nghỉ vài buổi'),
  manyMissed('Nghỉ nhiều buổi'),
  missingAttendance('Chưa có điểm danh'),
  empty('Chưa có lịch học');
  const RecapScenario(this.label);
  final String label;
}

abstract final class RecapFixtures {
  static RecapFacts build(RecapScenario type, DateTime now) {
    if (type == RecapScenario.empty) {
      return RecapFacts.calculate(
        ImportedScheduleData(displayName: 'Bạn', records: const [], syncedAt: now),
        attendance: const {}, now: now, registeredSubjects: 0,
      );
    }
    const names = [
      'Phân tích thiết kế hệ thống', 'Kỹ thuật phần mềm',
      'Cơ sở dữ liệu', 'Lập trình di động', 'Mạng máy tính', 'Trí tuệ nhân tạo',
    ];
    final first = type == RecapScenario.beforeEnd
        ? DateTime(now.year, now.month, now.day - 68)
        : DateTime(now.year, now.month, now.day - 110);
    final records = <ScheduleRecord>[];
    for (var week = 0; week < 13; week++) {
      for (var i = 0; i < names.length; i++) {
        final day = first.add(Duration(days: week * 7 + i % 4));
        final hour = i % 3 == 0 ? 6 : i % 3 == 1 ? 9 : 13;
        final minute = hour == 6 ? 45 : 0;
        records.add(ScheduleRecord(
          id: 'recap-fixture-$week-$i', isExam: false,
          subjectName: names[i], room: 'A', className: 'Bản thử',
          startAt: DateTime(day.year, day.month, day.day, hour, minute),
          endAt: DateTime(day.year, day.month, day.day, hour + 2, minute),
          periodStart: hour < 12 ? 1 : 7,
          periodEnd: hour < 12 ? 3 : 9,
        ));
      }
    }
    final misses = switch (type) {
      RecapScenario.perfect => 0,
      RecapScenario.manyMissed => 5,
      _ => 2,
    };
    final attendance = <String, AttendanceSummary>{
      if (type != RecapScenario.missingAttendance)
        for (var i = 0; i < names.length; i++)
          normalizeSubjectName(names[i]): AttendanceSummary(
            absentSessions: i == 0 ? misses : misses == 0 ? 0 : i % 3 == 0 ? 1 : 0,
            totalTheorySessions: 13,
          ),
    };
    return RecapFacts.calculate(
      ImportedScheduleData(
        displayName: 'Bạn', records: records, syncedAt: now, source: 'recap_fixture',
      ),
      attendance: attendance, now: now,
      registeredSubjects: names.length,
      attendanceConfirmed: type == RecapScenario.perfect,
    );
  }
}

abstract final class RecapSpin {
  // Position AND velocity are continuous at the 3-second loop seam.
  // Starts fast, decelerates smoothly to low speed, then accelerates again.
  static double angle(double progress) {
    final t = progress.clamp(0.0, 1.0);
    return 12 * math.pi * (t + 0.145 * math.sin(2 * math.pi * t));
  }
}
