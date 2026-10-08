import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_login_result.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_native_transport.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_schedule_range.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_schedule_verifier.dart';
import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/tracuu_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<QldtLoginResult> reloadQldtInPlace(ImportedScheduleData current) async {
  const sessionKey = 'better_phenikaa_qldt_native_session_v1';
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(sessionKey);
  if (raw == null || raw.isEmpty) {
    throw StateError('Không có phiên QLĐT còn lưu. Hãy đăng nhập lại.');
  }
  final session = QldtNativeSession.fromJson(
    Map<String, dynamic>.from(jsonDecode(raw) as Map),
  );
  if (!session.isValid) {
    throw StateError('Phiên QLĐT cần đăng nhập lại.');
  }

  const transport = QldtNativeTransport();
  final registrationResponse = await transport.fetchRegistration(session);
  final registration = const TracuuApi().parse(registrationResponse.raw);
  final range = SemesterScheduleRange.fromRegistration(registration);
  if (range == null) {
    throw StateError('QLĐT chưa có lịch học kỳ để đồng bộ.');
  }

  final chunks = <({DateTime start, DateTime end})>[];
  var cursor = DateTime(range.start.year, range.start.month, range.start.day);
  while (!cursor.isAfter(range.end)) {
    var end = cursor.add(const Duration(days: 6));
    if (end.isAfter(range.end)) end = range.end;
    chunks.add((start: cursor, end: end));
    cursor = end.add(const Duration(days: 1));
  }

  // Matches the existing seven-day, concurrent QLDT personal-calendar
  // import; retain old data until every chunk has been verified.
  final allRows = <dynamic>[];
  for (var offset = 0; offset < chunks.length; offset += 8) {
    final batch = chunks.skip(offset).take(8);
    final responses = await Future.wait(batch.map((chunk) =>
        transport.fetchScheduleEnvelope(
          session: session, start: chunk.start, end: chunk.end,
        )));
    for (final rawResponse in responses) {
      final envelope = jsonDecode(rawResponse) as Map<String, dynamic>;
      final response = Map<String, dynamic>.from(envelope['response'] as Map);
      if (response['Success'] != true || response['Data'] is! List) {
        throw StateError('QLĐT trả lịch cá nhân chưa hợp lệ.');
      }
      allRows.addAll(response['Data'] as List);
    }
  }

  final resultEnvelope = jsonEncode(<String, dynamic>{
    'name': current.displayName,
    'response': <String, dynamic>{
      'Success': true, 'Data': allRows, 'Message': '',
    },
  });
  final schedule = const QldtParser().parseLiveEnvelope(
    resultEnvelope, strict: true,
  );
  final verified = const SemesterScheduleVerifier().verify(
    registration: registration, schedule: schedule,
  );
  final semester = const SemesterDataBuilder().build(
    registration: registration,
    studySchedules: verified.studySchedules,
    examSchedules: verified.examSchedules,
    displayName: current.displayName,
    syncedAt: schedule.syncedAt,
  );
  return QldtLoginResult(
    schedule: semester.toImportedScheduleData(),
    semester: semester,
    registrationRoute: const TracuuApi().routeForVerifiedResult(
      registrationResponse.raw,
    ),
    termStartedAt: range.start,
  );
}
