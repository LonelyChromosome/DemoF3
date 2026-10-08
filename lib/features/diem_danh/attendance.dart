import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AttendanceStatus { pending, present, absent }

final class AttendanceEntry {
  const AttendanceEntry({
    required this.code,
    required this.status,
    required this.sentAt,
    this.attendanceListId = '',
  });

  final String code;
  final AttendanceStatus status;
  final DateTime sentAt;
  /// Captured for this exact lesson at code-submission time.
  /// Never used to validate the timetable/semester database.
  final String attendanceListId;

  factory AttendanceEntry.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? '').toString();
    return AttendanceEntry(
      code: (json['code'] ?? '').toString(),
      status: AttendanceStatus.values.firstWhere(
        (value) => value.name == rawStatus,
        orElse: () => AttendanceStatus.pending,
      ),
      sentAt: DateTime.tryParse((json['sentAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      attendanceListId: (json['attendanceListId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'status': status.name,
    'sentAt': sentAt.toIso8601String(),
    'attendanceListId': attendanceListId,
  };

  AttendanceEntry withStatus(AttendanceStatus next) => AttendanceEntry(
    code: code,
    status: next,
    sentAt: sentAt,
    attendanceListId: attendanceListId,
  );
}

final class AttendanceStore {
  static const key = 'better_phenikaa_attendance_v13';

  Future<Map<String, AttendanceEntry>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    if (value == null || value.isEmpty) return <String, AttendanceEntry>{};
    try {
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(
        k,
        AttendanceEntry.fromJson(Map<String, dynamic>.from(v as Map)),
      ));
    } on Object {
      return <String, AttendanceEntry>{};
    }
  }

  Future<Map<String, AttendanceEntry>> save(
    Map<String, AttendanceEntry> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(entries.map((k, v) => MapEntry(k, v.toJson()))),
    );
    return entries;
  }

  Future<Map<String, AttendanceEntry>> recordSent(
    Map<String, AttendanceEntry> previous,
    ScheduleRecord lesson,
    String code,
  ) => save(<String, AttendanceEntry>{
    ...previous,
    lesson.id: AttendanceEntry(
      code: code,
      status: AttendanceStatus.pending,
      sentAt: DateTime.now(),
      attendanceListId: lesson.attendanceListId,
    ),
  });

  // Do not infer success from the submission response. Only explicit text
  // returned in a subsequent QLDT schedule snapshot changes review status.
  Future<Map<String, AttendanceEntry>> reconcile(
    Map<String, AttendanceEntry> previous,
    Iterable<ScheduleRecord> lessons,
  ) async {
    final updated = <String, AttendanceEntry>{...previous};
    for (final lesson in lessons) {
      final existing = updated[lesson.id];
      if (existing == null) continue;
      // Keep QLDT status scoped to the exact course/session that submitted
      // the code. Never take a review from another attendance-list ID.
      if (existing.attendanceListId.isNotEmpty &&
          lesson.attendanceListId.isNotEmpty &&
          existing.attendanceListId != lesson.attendanceListId) {
        continue;
      }
      final status = switch (lesson.attendanceReview) {
        'present' => AttendanceStatus.present,
        'absent' => AttendanceStatus.absent,
        _ => null,
      };
      if (status != null) updated[lesson.id] = existing.withStatus(status);
    }
    return save(updated);
  }
}
