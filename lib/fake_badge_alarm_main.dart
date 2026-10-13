import 'package:better_phenikaa_schedule/app/app.dart';
import 'package:flutter/material.dart';

/// One static timetable screen. No login, QLDT, alarm, sync or navigation.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BpaFakeAttendanceAlarmApp());
}
