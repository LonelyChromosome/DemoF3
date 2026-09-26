import 'dart:convert';

import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/semester_data.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads the bundled timetable only for the separately built demo APK.
final class DemoDataSeed {
  const DemoDataSeed._();

  static const _legacySnapshotKey = 'better_phenikaa_snapshot_v1';
  static const _assetPath = 'assets/demo/current_semester.json';

  static Future<void> seedIfEmpty() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.containsKey(CurrentSemesterStore.storageKey) ||
        preferences.containsKey(_legacySnapshotKey)) {
      return;
    }

    final raw = await rootBundle.loadString(_assetPath);
    final semester = CurrentSemester.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>),
    );
    final snapshot = semester.toImportedScheduleData().encode();
    if (!await preferences.setString(
      CurrentSemesterStore.storageKey,
      semester.encode(),
    )) {
      throw StateError('Không thể nạp lịch demo trên thiết bị.');
    }
    if (!await preferences.setString(_legacySnapshotKey, snapshot)) {
      await preferences.remove(CurrentSemesterStore.storageKey);
      throw StateError('Không thể nạp lịch demo trên thiết bị.');
    }
  }
}
