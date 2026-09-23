import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum QldtSyncPhase {
  session,
  schedule,
  navigation,
  semesterPlan,
  subjects,
  verification,
  sessionCache,
  save,
}

final class QldtSyncDiagnostics {
  new({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const storageKey = 'qldt_sync_diagnostics';
  final DateTime Function() _clock;
  final List<Map<String, String>> _events = [];
  Map<String, String>? _active;
  Future<void> _write = Future<void>.value();
  Future<void> get flushed => _write;

  static Future<void> appendSave(DateTime startedAt, String code) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    final previous = raw == null
        ? <dynamic>[]
        : jsonDecode(raw) as List<dynamic>;
    previous.add(<String, String>{
      'phase': QldtSyncPhase.save.name,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': DateTime.now().toUtc().toIso8601String(),
      'code': code,
    });
    await prefs.setString(storageKey, jsonEncode(previous));
  }

  List<Map<String, String>> get events =>
      _events.map(Map<String, String>.from).toList();

  void start(QldtSyncPhase phase) {
    finish('OK');
    final event = <String, String>{
      'phase': phase.name,
      'startedAt': _clock().toUtc().toIso8601String(),
    };
    _events.add(event);
    _active = event;
    _persist();
  }

  void finish(String code) {
    final event = _active;
    if (event == null) return;
    event['endedAt'] = _clock().toUtc().toIso8601String();
    event['code'] = code;
    _active = null;
    _persist();
  }

  void _persist() {
    final snapshot = jsonEncode(_events);
    _write = _write
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(storageKey, snapshot);
        })
        .catchError((Object _) {});
  }
}
