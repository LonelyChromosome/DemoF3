import 'package:flutter/foundation.dart';
import 'vehicle_native.dart';
import '../dang_nhap_qldt/qldt_models.dart';

List<Map<String, dynamic>> vehicleScheduleWindows(Iterable<ScheduleRecord> classes) =>
    classes.where((r) => !r.isExam && r.lessonKind?.toUpperCase() != 'ELEARNING')
        .map((r) => <String, dynamic>{
          'name': r.subjectName, 'kind': r.lessonKind ?? '', 'room': r.room,
          'className': r.className, 'start': r.startAt.millisecondsSinceEpoch,
          'end': r.endAt.millisecondsSinceEpoch,
        }).toList(growable: false);

// An optional local sidecar: failures never block the authoritative timetable.
Future<void> publishVehicleSchedule(ImportedScheduleData? data) async {
  if(kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try { await VehicleNative.schedule(data == null ? [] : vehicleScheduleWindows(data.classes)); }
  catch (_) { /* Repairs from the next cache restore or successful sync. */ }
}
